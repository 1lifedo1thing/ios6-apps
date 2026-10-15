import AVKit
import Photos
import SwiftUI

struct PhotoViewer: View {
  let library: PhotoLibrary
  let albumID: String
  let initialID: String
  let back: (String?) -> Void
  @Environment(\.scenePhase) private var scenePhase
  @State private var currentID: String?
  @State private var image: UIImage?
  @State private var player: AVPlayer?
  @State private var controls = true
  @State private var loading = false
  @State private var loadToken = UUID()
  @State private var failed = false
  @State private var editing = false
  @State private var sharing = false
  @State private var deleting = false
  @State private var slideshowOptions = false
  @State private var slideshow = false
  @State private var slideSeconds = 3.0
  @State private var shuffle = false
  @State private var repeats = true
  @State private var sheet: SharePayload?
  @State private var showInfo = false
  @State private var zoomed = false
  private var album: PhotoAlbum? { library.albums.first { $0.id == albumID } }
  private var items: [PhotoItem] { album?.items ?? [] }
  private var index: Int { items.firstIndex { $0.id == (currentID ?? initialID) } ?? 0 }
  private var item: PhotoItem? { items.first { $0.id == (currentID ?? initialID) } }

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      VStack(spacing: 0) {
        if controls {
          PhotoNavigation(
            title: L10n.format("%d / %d", index + 1, items.count), dark: true,
            accessibilityTitle: L10n.format("%d of %d", index + 1, items.count),
            titleIdentifier: "viewer-counter"
          ) {
            Button {
              back(item?.id)
            } label: {
              HStack(spacing: 3) {
                Image(systemName: "chevron.left")
                Text(album?.displayTitle ?? L10n.text("Albums"))
              }.lineLimit(1)
            }.buttonStyle(PhotoButtonStyle()).frame(maxWidth: 112).accessibilityIdentifier(
              "viewer-back")
          } trailing: {
            Button(L10n.text("Edit")) { editing = true }.buttonStyle(PhotoButtonStyle()).disabled(
              item == nil || loading
            )
            .accessibilityIdentifier("edit-photo")
          }
        }
        ZStack {
          if let player {
            VideoPlayer(player: player).accessibilityIdentifier("video-player")
          } else if let image {
            ZoomablePhoto(image: image, zoomed: $zoomed, tap: { controls.toggle() })
              .accessibilityLabel(L10n.text("Photo")).accessibilityIdentifier("photo-detail")
              .simultaneousGesture(
                DragGesture(minimumDistance: 40).onEnded { value in
                  guard !zoomed, abs(value.translation.width) > abs(value.translation.height) else {
                    return
                  }
                  navigate(value.translation.width < 0 ? 1 : -1)
                })
          }
          if loading { ProgressView(L10n.text("Loading…")).tint(.white).foregroundStyle(.white) }
          if failed {
            VStack(spacing: 18) {
              Text(
                L10n.text("This item could not be downloaded. Check your connection and try again.")
              ).multilineTextAlignment(.center)
              Button(L10n.text("Try Again")) { Task { await load() } }.buttonStyle(
                PhotoButtonStyle())
            }.foregroundStyle(.white).padding(24)
          }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
        if controls, let item {
          VStack(spacing: 2) {
            Text(AppLanguage.current.timestamp(item.date)).font(PhotosTheme.font(12))
            if showInfo {
              Text(
                "\(item.width) × \(item.height)"
                  + (item.isVideo ? " • " + PhotoTime.duration(item.duration) : "")
              )
              .font(PhotosTheme.font(12)).foregroundStyle(.gray)
            }
          }.foregroundStyle(.white.opacity(0.7)).padding(5)
          toolbar
        }
      }.accessibilityHidden(sharing || deleting || slideshowOptions).allowsHitTesting(
        !sharing && !deleting && !slideshowOptions)
      if sharing, let item {
        ClassicSharePanel(items: [item], library: library, dismiss: { sharing = false }) { urls in
          sharing = false
          sheet = urls
        }
      }
      if deleting, let item {
        ClassicPhotoAlert(
          title: "Delete from Photo Library?",
          text: "This item will be deleted from the system photo library on all synced devices.",
          confirm: "Delete", cancel: "Cancel"
        ) {
          deleting = false
          library.busy = true
          let neighbor =
            items.indices.contains(index + 1)
            ? items[index + 1].id : (index > 0 ? items[index - 1].id : nil)
          Task {
            defer { library.busy = false }
            do {
              try await library.delete([item])
              back(neighbor)
            } catch { library.message = error.localizedDescription }
          }
        } dismiss: {
          deleting = false
        }
      }
      if slideshowOptions { slideshowPanel }
    }
    .task(id: currentID ?? initialID) { await load() }
    .onDisappear { player?.pause() }
    .onChange(of: scenePhase) { if scenePhase != .active { player?.pause() } }
    .sheet(item: $sheet) { payload in ActivitySheet(payload: payload) }
    .fullScreenCover(isPresented: $editing) {
      if let item { MediaEditor(library: library, item: item) { editing = false } }
    }
    .fullScreenCover(isPresented: $slideshow) {
      PhotoSlideshow(
        library: library, items: items, initialIndex: index, interval: slideSeconds,
        shuffle: shuffle, repeats: repeats
      ) { slideshow = false }
    }
    .accessibilityAction(named: L10n.text("Next")) { navigate(1) }
    .accessibilityAction(named: L10n.text("Previous")) { navigate(-1) }
    .accessibilityAction(.escape) { back(item?.id) }
  }

  private var toolbar: some View {
    HStack(spacing: 0) {
      PhotoTool(symbol: "square.and.arrow.up", label: "Share", identifier: "share-photo") {
        sharing = true
      }
      Spacer(minLength: 0)
      PhotoTool(
        symbol: "chevron.left", label: "Previous", identifier: "previous-photo",
        disabled: index == 0
      ) { navigate(-1) }
      PhotoTool(symbol: "play.fill", label: "Slideshow", identifier: "slideshow") {
        slideshowOptions = true
      }
      PhotoTool(
        symbol: "chevron.right", label: "Next", identifier: "next-photo",
        disabled: index >= items.count - 1
      ) { navigate(1) }
      Spacer(minLength: 0)
      PhotoTool(symbol: "info.circle", label: "Photo Information") { showInfo.toggle() }
      PhotoTool(
        symbol: "trash", label: "Delete", identifier: "delete-photo",
        disabled: album?.shared == true
      ) { deleting = true }
    }.padding(.horizontal, 4).frame(height: 48).background(
      PhotosTheme.chrome, ignoresSafeAreaEdges: [])
  }

  private var slideshowPanel: some View {
    ZStack(alignment: .bottom) {
      Color.black.opacity(0.5).ignoresSafeArea()
      VStack(spacing: 14) {
        Text(L10n.text("Slideshow Options")).font(PhotosTheme.font(20, bold: true)).foregroundStyle(
          .white)
        HStack {
          Text(L10n.text("Show Each Photo For"))
          Spacer()
        }
        HStack(spacing: 8) {
          ForEach([2.0, 3, 5, 10], id: \.self) { value in
            Button(L10n.format("%d s", Int(value))) { slideSeconds = value }
              .accessibilityLabel(L10n.format("%d seconds", Int(value)))
              .buttonStyle(PhotoButtonStyle(primary: slideSeconds == value)).frame(
                maxWidth: .infinity, minHeight: 44)
          }
        }
        ClassicPhotoSwitch(title: "Shuffle", value: $shuffle)
        ClassicPhotoSwitch(title: "Repeat", value: $repeats)
        Button(L10n.text("Start Slideshow")) {
          player?.pause()
          slideshowOptions = false
          slideshow = true
        }
        .buttonStyle(PhotoButtonStyle(primary: true)).frame(maxWidth: .infinity, minHeight: 44)
        .accessibilityIdentifier("start-slideshow")
        Button(L10n.text("Cancel")) { slideshowOptions = false }.buttonStyle(PhotoButtonStyle())
          .frame(minHeight: 44)
      }.font(PhotosTheme.font(16)).foregroundStyle(.white).padding(20).background(PhotosTheme.black)
    }.accessibilityAddTraits(.isModal)
  }

  private func navigate(_ delta: Int) {
    let next = index + delta
    guard items.indices.contains(next) else { return }
    player?.pause()
    player = nil
    image = nil
    zoomed = false
    currentID = items[next].id
  }
  private func load() async {
    guard let item else { return }
    player?.pause()
    player = nil
    image = nil
    failed = false
    loading = true
    let token = UUID()
    loadToken = token
    defer { if loadToken == token { loading = false } }
    do {
      if item.isVideo {
        let asset = try await library.videoAsset(item)
        if !Task.isCancelled { player = AVPlayer(playerItem: AVPlayerItem(asset: asset)) }
      } else {
        let result = try await library.image(item, size: CGSize(width: 2560, height: 2560))
        if !Task.isCancelled { image = result }
      }
    } catch { if !Task.isCancelled { failed = true } }
  }
}

struct ZoomablePhoto: UIViewRepresentable {
  let image: UIImage
  @Binding var zoomed: Bool
  let tap: () -> Void
  func makeCoordinator() -> Coordinator { Coordinator(self) }
  func makeUIView(context: Context) -> UIScrollView {
    let scroll = PhotoScrollView()
    scroll.delegate = context.coordinator
    scroll.minimumZoomScale = 1
    scroll.maximumZoomScale = 5
    scroll.showsHorizontalScrollIndicator = false
    scroll.showsVerticalScrollIndicator = false
    scroll.backgroundColor = .black
    scroll.contentInsetAdjustmentBehavior = .never
    let view = context.coordinator.imageView
    view.contentMode = .scaleAspectFit
    view.isUserInteractionEnabled = true
    scroll.addSubview(view)
    let double = UITapGestureRecognizer(
      target: context.coordinator, action: #selector(Coordinator.doubleTap(_:)))
    double.numberOfTapsRequired = 2
    let single = UITapGestureRecognizer(
      target: context.coordinator, action: #selector(Coordinator.singleTap))
    single.require(toFail: double)
    scroll.addGestureRecognizer(double)
    scroll.addGestureRecognizer(single)
    return scroll
  }
  func updateUIView(_ scroll: UIScrollView, context: Context) {
    context.coordinator.parent = self
    if context.coordinator.imageView.image !== image {
      scroll.setZoomScale(1, animated: false)
      context.coordinator.imageView.image = image
    }
    if scroll.zoomScale == 1 {
      context.coordinator.imageView.frame = CGRect(origin: .zero, size: scroll.bounds.size)
      scroll.contentSize = scroll.bounds.size
    }
  }
  final class Coordinator: NSObject, UIScrollViewDelegate {
    var parent: ZoomablePhoto
    let imageView = UIImageView()
    init(_ parent: ZoomablePhoto) { self.parent = parent }
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
      let zoomed = scrollView.zoomScale > 1.05
      if parent.zoomed != zoomed { DispatchQueue.main.async { self.parent.zoomed = zoomed } }
    }
    @objc func singleTap() { parent.tap() }
    @objc func doubleTap(_ recognizer: UITapGestureRecognizer) {
      guard let scroll = recognizer.view as? UIScrollView else { return }
      if scroll.zoomScale > 1 {
        scroll.setZoomScale(1, animated: !UIAccessibility.isReduceMotionEnabled)
      } else {
        let point = recognizer.location(in: imageView)
        scroll.zoom(
          to: CGRect(
            x: point.x - scroll.bounds.width / 5, y: point.y - scroll.bounds.height / 5,
            width: scroll.bounds.width / 2.5, height: scroll.bounds.height / 2.5),
          animated: !UIAccessibility.isReduceMotionEnabled)
      }
    }
  }
}

struct PhotoSlideshow: View {
  let library: PhotoLibrary
  let items: [PhotoItem]
  let initialIndex: Int
  let interval: Double
  let shuffle: Bool
  let repeats: Bool
  let dismiss: () -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase
  @State private var image: UIImage?
  @State private var frameID = ""
  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      if let image {
        Image(uiImage: image).resizable().scaledToFit().id(frameID).transition(.opacity)
      }
      VStack {
        Spacer()
        Button(L10n.text("Stop Slideshow"), action: dismiss).buttonStyle(PhotoButtonStyle())
          .padding(16)
      }
    }.contentShape(Rectangle()).onTapGesture(perform: dismiss).preferredColorScheme(.dark)
      .task {
        var slides = Array(items.dropFirst(initialIndex)) + Array(items.prefix(initialIndex))
        slides.removeAll(where: \.isVideo)
        if shuffle { slides.shuffle() }
        guard !slides.isEmpty else {
          dismiss()
          return
        }
        repeat {
          for item in slides {
            guard !Task.isCancelled else { return }
            if let result = try? await library.image(item) {
              withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.7)) {
                image = result
                frameID = item.id
              }
            }
            do { try await Task.sleep(for: .seconds(interval)) } catch { return }
          }
        } while repeats && !Task.isCancelled
        dismiss()
      }
      .onChange(of: scenePhase) { if scenePhase != .active { dismiss() } }
      .accessibilityIdentifier("slideshow-playing")
  }
}

private final class PhotoScrollView: UIScrollView {
  private var previousSize = CGSize.zero
  override func layoutSubviews() {
    super.layoutSubviews()
    guard bounds.size != previousSize, let imageView = subviews.first(where: { $0 is UIImageView })
    else { return }
    previousSize = bounds.size
    setZoomScale(1, animated: false)
    imageView.frame = CGRect(origin: .zero, size: bounds.size)
    contentSize = bounds.size
  }
}
