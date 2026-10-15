import SwiftUI

// Original chrome is drawn locally; the system owns only permissions and service controllers.
enum PhotosTheme {
  static let ink = Color(red: 0.18, green: 0.22, blue: 0.29)
  static let chrome = ClassicPhotoChrome.chrome
  static let black = ClassicPhotoChrome.black
  static func font(_ size: CGFloat, bold: Bool = false) -> Font {
    ClassicPhotoChrome.font(size, bold: bold)
  }
}

typealias PhotoButtonStyle = ClassicPhotoButtonStyle
typealias PhotoNavigation<Leading: View, Trailing: View> = ClassicPhotoNavigation<Leading, Trailing>

struct PhotoStripes: View {
  var body: some View {
    Canvas { context, size in
      context.fill(
        Path(CGRect(origin: .zero, size: size)),
        with: .color(Color(white: 0.90)))
      for x in stride(from: 0.0, through: size.width, by: 6) {
        context.fill(
          Path(CGRect(x: x, y: 0, width: 1, height: size.height)),
          with: .color(.white.opacity(0.24)))
        context.fill(
          Path(CGRect(x: x + 1, y: 0, width: 1, height: size.height)),
          with: .color(.black.opacity(0.025)))
      }
    }.accessibilityHidden(true).allowsHitTesting(false)
  }
}

struct PhotoTool: View {
  let symbol: String
  let label: String
  var identifier: String = ""
  var disabled = false
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      Image(systemName: symbol).font(.system(size: 22, weight: .medium))
        .shadow(color: .black.opacity(0.6), radius: 0, y: -1).frame(minWidth: 44, minHeight: 44)
    }.buttonStyle(.plain).foregroundStyle(.white).disabled(disabled).opacity(disabled ? 0.35 : 1)
      .accessibilityLabel(L10n.text(label)).accessibilityIdentifier(identifier)
  }
}

struct ClassicPhotoAlert: View {
  let title: String
  let text: String
  var confirm = "OK"
  var cancel: String? = nil
  let action: () -> Void
  var dismiss: (() -> Void)? = nil
  var body: some View {
    ZStack {
      Color.black.opacity(0.55).ignoresSafeArea()
      VStack(spacing: 16) {
        Text(L10n.text(title)).font(PhotosTheme.font(19, bold: true))
        Text(L10n.text(text)).font(PhotosTheme.font(15)).multilineTextAlignment(.center)
        HStack {
          if let cancel {
            Button(L10n.text(cancel)) { dismiss?() }.buttonStyle(PhotoButtonStyle()).frame(
              maxWidth: .infinity, minHeight: 44)
          }
          Button(L10n.text(confirm), action: action).buttonStyle(
            PhotoButtonStyle(primary: true, destructive: confirm == "Delete")
          ).frame(maxWidth: .infinity, minHeight: 44)
            .accessibilityIdentifier("photo-alert-confirm")
        }
      }.foregroundStyle(.white).padding(18).frame(maxWidth: 320)
        .background(
          LinearGradient(
            colors: [
              Color(red: 0.30, green: 0.39, blue: 0.54), Color(red: 0.13, green: 0.21, blue: 0.36),
            ], startPoint: .top, endPoint: .bottom)
        )
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.7), lineWidth: 2))
        .clipShape(RoundedRectangle(cornerRadius: 12)).shadow(radius: 18)
    }.accessibilityAddTraits(.isModal)
  }
}

struct PhotoThumbnail: View {
  let item: PhotoItem
  let library: PhotoLibrary
  var size: CGFloat = 90
  @Environment(\.displayScale) private var displayScale
  @State private var image: UIImage?
  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      Color(white: 0.79)
      if let image {
        Image(uiImage: image).resizable().scaledToFill().frame(width: size, height: size).clipped()
      }
      if item.isVideo {
        HStack(spacing: 3) {
          Image(systemName: "video.fill")
          Text(PhotoTime.duration(item.duration))
        }
        .font(PhotosTheme.font(11, bold: true)).foregroundStyle(.white).padding(3).background(
          .black.opacity(0.65))
      }
    }.frame(width: size, height: size).clipped()
      .task(id: item.id) {
        image = nil
        let result = try? await library.image(
          item, size: CGSize(width: size * displayScale, height: size * displayScale))
        if !Task.isCancelled { image = result }
      }.accessibilityHidden(true)
  }
}

enum PhotoTime {
  static func duration(_ seconds: Double) -> String {
    let seconds = max(0, Int(seconds.isFinite ? seconds : 0))
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
  }
}

struct ClassicPhotoSwitch: View {
  let title: String
  @Binding var value: Bool
  var body: some View {
    HStack {
      Text(L10n.text(title)).font(PhotosTheme.font(16, bold: true))
      Spacer()
      Button {
        value.toggle()
      } label: {
        ZStack(alignment: value ? .trailing : .leading) {
          RoundedRectangle(cornerRadius: 5).fill(
            value ? Color(red: 0.12, green: 0.42, blue: 0.83) : Color(white: 0.7))
          Text(L10n.text(value ? "ON" : "OFF")).font(PhotosTheme.font(13, bold: true))
            .foregroundStyle(value ? .white : Color(white: 0.35))
            .offset(x: value ? -15 : 15).frame(width: 82, height: 28)
          RoundedRectangle(cornerRadius: 4).fill(
            LinearGradient(
              colors: [.white, Color(white: 0.77)], startPoint: .top, endPoint: .bottom)
          )
          .frame(width: 31, height: 27).overlay(
            RoundedRectangle(cornerRadius: 4).strokeBorder(.black.opacity(0.3), lineWidth: 1))
        }.frame(width: 82, height: 29).overlay(
          RoundedRectangle(cornerRadius: 5).strokeBorder(.black.opacity(0.7), lineWidth: 1)
        ).frame(height: 44)
      }.buttonStyle(.plain).accessibilityLabel(L10n.text(title)).accessibilityValue(
        L10n.text(value ? "ON" : "OFF"))
    }
  }
}
