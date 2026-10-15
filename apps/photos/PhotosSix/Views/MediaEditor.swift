import AVKit
import SwiftUI

struct MediaEditor: View {
  let library: PhotoLibrary
  let item: PhotoItem
  let dismiss: () -> Void
  @State private var image: UIImage?
  @State private var original: UIImage?
  @State private var asset: AVAsset?
  @State private var player: AVPlayer?
  @State private var start = 0.0
  @State private var end = 1.0
  @State private var duration = 1.0
  @State private var cropRatio = 0.0
  @State private var cropCenter = CGPoint(x: 0.5, y: 0.5)
  @State private var redEye = false
  @State private var saving = false
  @State private var error: String?
  @State private var loaded = false

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      VStack(spacing: 0) {
        PhotoNavigation(title: L10n.text(item.isVideo ? "Trim Video" : "Edit Photo"), dark: true) {
          Button(L10n.text("Cancel"), action: dismiss).buttonStyle(PhotoButtonStyle()).disabled(
            saving)
        } trailing: {
          Button(L10n.text("Save")) { save() }.buttonStyle(PhotoButtonStyle(primary: true))
            .disabled(saving || !loaded)
            .accessibilityIdentifier("save-edit")
        }
        if item.isVideo { videoEditor } else { photoEditor }
        Text(L10n.text("Edits are saved as a new copy. The original is kept."))
          .font(PhotosTheme.font(12)).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(
            .center
          ).padding(10)
        if !item.isVideo { tools }
      }.allowsHitTesting(!saving).accessibilityHidden(saving)
      if saving {
        Color.black.opacity(0.5).ignoresSafeArea()
        ProgressView(L10n.text("Saving…")).foregroundStyle(.white).tint(.white)
      }
      if let error { ClassicPhotoAlert(title: "Photos", text: error) { self.error = nil } }
    }.preferredColorScheme(.dark).task { await load() }
      .onDisappear { player?.pause() }
  }

  private var photoEditor: some View {
    VStack(spacing: 6) {
      GeometryReader { geometry in
        if let image {
          let displayed =
            cropRatio > 0 ? PhotoEditing.crop(image, ratio: cropRatio, center: cropCenter) : image
          let factor = min(
            geometry.size.width / displayed.size.width, geometry.size.height / displayed.size.height
          )
          let size = CGSize(
            width: displayed.size.width * factor, height: displayed.size.height * factor)
          ZStack {
            Image(uiImage: displayed).resizable().scaledToFit()
              .frame(width: size.width, height: size.height)
              .overlay {
                if cropRatio > 0 {
                  CropRules().stroke(.white.opacity(0.7), lineWidth: 1).allowsHitTesting(false)
                }
              }
              .gesture(
                SpatialTapGesture().onEnded { value in
                  guard redEye, cropRatio == 0 else { return }
                  self.image = PhotoEditing.redEye(
                    image,
                    at: CGPoint(x: value.location.x / size.width, y: value.location.y / size.height)
                  )
                }
              )
              .gesture(
                DragGesture(minimumDistance: 8).onEnded { value in
                  guard cropRatio > 0 else { return }
                  cropCenter.x = max(
                    0, min(1, cropCenter.x - value.translation.width / max(1, size.width)))
                  cropCenter.y = max(
                    0, min(1, cropCenter.y - value.translation.height / max(1, size.height)))
                })
          }.frame(maxWidth: .infinity, maxHeight: .infinity).accessibilityIdentifier("editor-image")
        } else {
          ProgressView().tint(.white).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      if redEye {
        Text(L10n.text("Tap each red eye in the photo.")).font(PhotosTheme.font(14))
          .foregroundStyle(.white).padding(8)
      }
      if cropRatio > 0 {
        Text(L10n.text("Drag to reposition the crop.")).font(PhotosTheme.font(12)).foregroundStyle(
          .gray)
        HStack {
          ratioButton("Square", value: 1)
          ratioButton("4:3", value: 4.0 / 3)
          ratioButton("3:4", value: 3.0 / 4)
          ratioButton("16:9", value: 16.0 / 9)
        }.padding(.horizontal, 8)
      }
    }
  }
  private func ratioButton(_ title: String, value: Double) -> some View {
    Button(L10n.text(title)) { cropRatio = value }.buttonStyle(
      PhotoButtonStyle(primary: abs(cropRatio - value) < 0.01)
    )
    .frame(maxWidth: .infinity, minHeight: 44)
  }
  private var tools: some View {
    HStack(spacing: 0) {
      editTool("rotate.left", "Rotate") { if let image { self.image = PhotoEditing.rotate(image) } }
      editTool("wand.and.stars", "Enhance") {
        if let image { self.image = PhotoEditing.enhance(image) }
      }
      editTool("eye", "Red-eye", active: redEye) {
        redEye.toggle()
        cropRatio = 0
      }
      editTool("crop", "Crop", active: cropRatio > 0) {
        cropRatio = cropRatio > 0 ? 0 : 1
        redEye = false
      }
      editTool("arrow.uturn.backward", "Revert") {
        image = original
        cropRatio = 0
        redEye = false
        cropCenter = CGPoint(x: 0.5, y: 0.5)
      }
    }.frame(height: 55).background(PhotosTheme.black, ignoresSafeAreaEdges: [])
  }
  private func editTool(
    _ symbol: String, _ text: String, active: Bool = false, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      VStack(spacing: 3) {
        Image(systemName: symbol).font(.system(size: 22))
        Text(L10n.text(text)).font(PhotosTheme.font(10))
      }.foregroundStyle(active ? .yellow : .white).frame(maxWidth: .infinity, minHeight: 50)
    }.buttonStyle(.plain).disabled(!loaded).accessibilityLabel(L10n.text(text))
      .accessibilityIdentifier("editor-" + text)
  }
  private var videoEditor: some View {
    VStack(spacing: 12) {
      if let player {
        VideoPlayer(player: player)
      } else {
        Spacer()
        ProgressView().tint(.white)
        Spacer()
      }
      VStack(spacing: 6) {
        HStack {
          Text(L10n.text("Start"))
          Spacer()
          Text(PhotoTime.duration(start))
        }
        Slider(value: $start, in: 0...max(0.01, duration - 0.25)) { _ in
          if start > end - 0.25 { end = min(duration, start + 0.25) }
          player?.seek(to: CMTime(seconds: start, preferredTimescale: 600))
        }.tint(.yellow).accessibilityIdentifier("trim-start")
        HStack {
          Text(L10n.text("End"))
          Spacer()
          Text(PhotoTime.duration(end))
        }
        Slider(value: $end, in: min(0.25, duration)...max(0.26, duration)) { _ in
          if end < start + 0.25 { start = max(0, end - 0.25) }
          player?.currentItem?.forwardPlaybackEndTime = CMTime(
            seconds: end, preferredTimescale: 600)
        }.tint(.yellow).accessibilityIdentifier("trim-end")
        HStack {
          Button(L10n.text("Preview")) {
            player?.seek(to: CMTime(seconds: start, preferredTimescale: 600))
            player?.currentItem?.forwardPlaybackEndTime = CMTime(
              seconds: end, preferredTimescale: 600)
            player?.play()
          }.buttonStyle(PhotoButtonStyle())
          Spacer()
          Text(PhotoTime.duration(max(0, end - start))).font(PhotosTheme.font(14, bold: true))
        }
      }.font(PhotosTheme.font(14)).foregroundStyle(.white).padding(14).background(
        Color(white: 0.12))
    }
  }
  private func load() async {
    do {
      if item.isVideo {
        let asset = try await library.videoAsset(item)
        self.asset = asset
        duration = try await asset.load(.duration).seconds
        end = duration
        player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
      } else {
        let result = try await library.image(item, size: CGSize(width: 4096, height: 4096))
        image = PhotoEditing.upright(result)
        original = image
      }
      loaded = true
    } catch { self.error = error.localizedDescription }
  }
  private func save() {
    saving = true
    player?.pause()
    Task {
      defer { saving = false }
      do {
        if item.isVideo, let asset {
          let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString + ".mov")
          defer { try? FileManager.default.removeItem(at: url) }
          try await PhotoEditing.trim(asset, start: start, end: end, output: url)
          try await library.saveVideo(url)
        } else if let image {
          let output =
            cropRatio > 0 ? PhotoEditing.crop(image, ratio: cropRatio, center: cropCenter) : image
          guard let data = output.jpegData(compressionQuality: 0.96) else {
            throw PhotoFailure.save
          }
          try await library.savePhoto(data)
        }
        dismiss()
      } catch { self.error = error.localizedDescription }
    }
  }
}

private struct CropRules: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path(rect)
    for index in 1...2 {
      let fraction = CGFloat(index) / 3
      path.move(to: CGPoint(x: rect.width * fraction, y: 0))
      path.addLine(to: CGPoint(x: rect.width * fraction, y: rect.height))
      path.move(to: CGPoint(x: 0, y: rect.height * fraction))
      path.addLine(to: CGPoint(x: rect.width, y: rect.height * fraction))
    }
    return path
  }
}
