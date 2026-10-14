import CoreImage
import SwiftUI

struct PhotoEditorView: View {
  let url: URL
  let completion: (Data?) -> Void
  @State private var image: UIImage?
  @State private var original: UIImage?
  @State private var crop = false
  @State private var enhanced = false

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      VStack(spacing: 0) {
        ClassicNavigation(
          title: L10n.text("Edit Photo"), leading: "Cancel", action: { completion(nil) },
          trailing: AnyView(
            Button(L10n.text("Save")) { save() }
              .buttonStyle(ChromeButtonStyle(dark: true, capsule: false)).frame(minHeight: 44)))
        if let image {
          Image(uiImage: displayImage(image)).resizable().scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity).accessibilityIdentifier(
              "editor-image")
        } else {
          Spacer()
        }
        Text(L10n.text("Edits are saved as a new photo.")).font(CameraTheme.font(12))
          .foregroundStyle(.white.opacity(0.7)).padding(8)
        HStack {
          editButton("rotate.left", "Rotate") { rotate() }
          Spacer()
          editButton("wand.and.stars", "Auto-enhance") { enhance() }
          Spacer()
          editButton("crop", "Crop 4:3") { crop.toggle() }
          Spacer()
          editButton("arrow.uturn.backward", "Revert") {
            image = original
            crop = false
            enhanced = false
          }
        }.padding(.horizontal, 12).frame(height: 52).background(CameraTheme.blue)
      }
    }.preferredColorScheme(.dark)
      .onAppear {
        image = UIImage(contentsOfFile: url.path)
        original = image
      }
  }

  private func editButton(_ symbol: String, _ label: String, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      VStack(spacing: 2) {
        Image(systemName: symbol).font(.system(size: 21))
        Text(L10n.text(label)).font(CameraTheme.font(10))
      }.frame(minWidth: 44, minHeight: 44)
    }.buttonStyle(.plain).foregroundStyle(.white).accessibilityLabel(L10n.text(label))
      .accessibilityIdentifier("editor-" + label.lowercased())
  }

  private func displayImage(_ input: UIImage) -> UIImage {
    guard crop, let cgImage = ImageProcessing.upright(input, maxDimension: 4096).cgImage else {
      return input
    }
    let width = CGFloat(cgImage.width)
    let height = CGFloat(cgImage.height)
    let ratio: CGFloat = width > height ? 4 / 3 : 3 / 4
    let target = CGSize(width: min(width, height * ratio), height: min(height, width / ratio))
    let rect = CGRect(
      x: (width - target.width) / 2, y: (height - target.height) / 2,
      width: target.width, height: target.height)
    return cgImage.cropping(to: rect).map(UIImage.init(cgImage:)) ?? input
  }

  private func rotate() {
    guard let image else { return }
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    self.image = UIGraphicsImageRenderer(
      size: CGSize(width: image.size.height, height: image.size.width), format: format
    ).image { ctx in
      ctx.cgContext.translateBy(x: image.size.height / 2, y: image.size.width / 2)
      ctx.cgContext.rotate(by: -.pi / 2)
      image.draw(
        in: CGRect(
          x: -image.size.width / 2, y: -image.size.height / 2,
          width: image.size.width, height: image.size.height))
    }
  }

  private func enhance() {
    guard let image, let input = CIImage(image: image) else { return }
    var result = input
    for filter in input.autoAdjustmentFilters() {
      filter.setValue(result, forKey: kCIInputImageKey)
      if let output = filter.outputImage { result = output }
    }
    if let output = ImageProcessing.context.createCGImage(result, from: result.extent) {
      self.image = UIImage(cgImage: output)
    }
    enhanced = true
  }

  private func save() {
    guard let image else {
      completion(nil)
      return
    }
    completion(displayImage(image).jpegData(compressionQuality: 0.95))
  }
}
