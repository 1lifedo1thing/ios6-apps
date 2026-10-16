import SwiftUI

enum MapTheme {
  static let ink = Color(red: 0.19, green: 0.23, blue: 0.29)
  static let blue = Color(red: 0.16, green: 0.35, blue: 0.64)
  static let silver = LinearGradient(
    colors: [Color(white: 0.98), Color(white: 0.83), Color(white: 0.73)], startPoint: .top,
    endPoint: .bottom)
  static let graphite = LinearGradient(
    colors: [Color(white: 0.35), Color(white: 0.18)], startPoint: .top, endPoint: .bottom)
  static func font(_ size: CGFloat, bold: Bool = false) -> Font {
    .custom(bold ? "HelveticaNeue-Bold" : "HelveticaNeue", size: size, relativeTo: .body)
  }
}

struct MetalButton: ButtonStyle {
  var blue = false
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(MapTheme.font(14, bold: true))
      .foregroundStyle(blue ? .white : MapTheme.ink)
      .shadow(color: blue ? .black.opacity(0.5) : .white, radius: 0, y: blue ? -1 : 1)
      .padding(.horizontal, 11).frame(minHeight: 30)
      .background {
        RoundedRectangle(cornerRadius: 5)
          .fill(
            blue
              ? LinearGradient(
                colors: [Color(red: 0.42, green: 0.61, blue: 0.86), MapTheme.blue],
                startPoint: .top, endPoint: .bottom) : MapTheme.silver
          )
          .overlay(RoundedRectangle(cornerRadius: 5).stroke(.black.opacity(0.4), lineWidth: 0.7))
          .overlay(
            RoundedRectangle(cornerRadius: 4).stroke(.white.opacity(0.45), lineWidth: 0.6).padding(
              1)
          )
          .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
      }
      .brightness(configuration.isPressed ? -0.13 : 0)
      .frame(minWidth: 44, minHeight: 44)
      .contentShape(Rectangle())
  }
}

struct ChromePanel<Content: View>: View {
  @ViewBuilder var content: Content
  var body: some View {
    content.background(MapTheme.silver, ignoresSafeAreaEdges: [])
      .overlay(alignment: .top) {
        Color.white.opacity(0.8).frame(height: 1).allowsHitTesting(false)
      }
      .overlay(alignment: .bottom) {
        Color.black.opacity(0.35).frame(height: 0.7).allowsHitTesting(false)
      }
  }
}

struct MapLinen: View {
  var body: some View {
    Image("MapLinen").resizable(resizingMode: .tile)
      .accessibilityHidden(true).allowsHitTesting(false)
  }
}

struct Pinstripe: View {
  var body: some View {
    Canvas { context, size in
      context.fill(
        Path(CGRect(origin: .zero, size: size)),
        with: .color(Color(red: 0.83, green: 0.85, blue: 0.88)))
      for x in stride(from: 0.0, to: size.width, by: 6) {
        context.fill(
          Path(CGRect(x: x, y: 0, width: 1, height: size.height)), with: .color(.white.opacity(0.2))
        )
      }
    }.accessibilityHidden(true).allowsHitTesting(false)
  }
}
