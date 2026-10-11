import SwiftUI

extension Color {
  init(hex: UInt32) {
    self.init(
      .sRGB, red: Double((hex >> 16) & 255) / 255,
      green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
  }
}

enum ClockTheme {
  static let ink = Color(hex: 0x101010)
  static let value = Color(hex: 0x3B5275)
  static func font(_ size: CGFloat, bold: Bool = false) -> Font {
    .custom(bold ? "HelveticaNeue-Bold" : "HelveticaNeue", size: size, relativeTo: .body)
  }
  static let row = LinearGradient(
    colors: [Color(hex: 0xE0E0E2), Color(hex: 0xB5B5BC)], startPoint: .top, endPoint: .bottom)
}

struct PinstripeBackground: View {
  var dark = false
  var body: some View {
    (dark ? Color(hex: 0x52667F) : Color(hex: 0xD1D6DE)).overlay {
      Canvas { context, size in
        for x in stride(from: 0.0, through: size.width, by: 6) {
          context.fill(
            Path(CGRect(x: x, y: 0, width: 2, height: size.height)),
            with: .color(dark ? .white.opacity(0.025) : .black.opacity(0.025)))
        }
      }
    }.ignoresSafeArea().accessibilityHidden(true)
  }
}

struct ClockNavigationBar: View {
  var title: String
  var left = ""
  var right = ""
  var rightBlue = false
  var onLeft: () -> Void = {}
  var onRight: () -> Void = {}
  var body: some View {
    ZStack {
      LinearGradient(
        stops: [
          .init(color: Color(hex: 0xC8D3E3), location: 0),
          .init(color: Color(hex: 0x8D9FB8), location: 0.49),
          .init(color: Color(hex: 0x7C90AD), location: 0.5),
          .init(color: Color(hex: 0x536A8B), location: 1),
        ], startPoint: .top, endPoint: .bottom)
      Text(L10n.text(title)).font(ClockTheme.font(20, bold: true)).foregroundStyle(.white)
        .shadow(color: .black.opacity(0.5), radius: 0, y: -1)
        .lineLimit(1).minimumScaleFactor(0.75).padding(.horizontal, 88)
      HStack {
        if !left.isEmpty {
          Button(L10n.text(left), action: onLeft).buttonStyle(NavigationButtonStyle())
            .accessibilityIdentifier("nav-left")
        }
        Spacer()
        if !right.isEmpty {
          Button(L10n.text(right), action: onRight).buttonStyle(
            NavigationButtonStyle(blue: rightBlue)
          )
          .accessibilityLabel(L10n.text(right == "+" ? "Add" : right))
          .accessibilityIdentifier("nav-right")
        }
      }.padding(.horizontal, 6)
    }.frame(height: 44).dynamicTypeSize(.small ... .xxxLarge)
      .overlay(alignment: .top) { Color.white.opacity(0.5).frame(height: 1) }
      .overlay(alignment: .bottom) { Color(hex: 0x304561).frame(height: 1) }
  }
}

struct NavigationButtonStyle: ButtonStyle {
  var blue = false
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(ClockTheme.font(13, bold: true)).foregroundStyle(.white)
      .padding(.horizontal, 10).frame(minWidth: 33, minHeight: 29)
      .background {
        RoundedRectangle(cornerRadius: 5).fill(
          LinearGradient(
            colors: blue
              ? [Color(hex: 0x82ADF2), Color(hex: 0x376BC2), Color(hex: 0x2855A3)]
              : [Color(hex: 0x93A8C3), Color(hex: 0x5B7599), Color(hex: 0x455F85)],
            startPoint: .top, endPoint: .bottom)
        )
        .overlay { RoundedRectangle(cornerRadius: 5).stroke(Color(hex: 0x3B5274), lineWidth: 1) }
        .shadow(color: .white.opacity(0.5), radius: 0, y: 1)
      }.shadow(color: .black.opacity(0.5), radius: 0, y: -1)
      .brightness(configuration.isPressed ? -0.18 : 0)
      .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
  }
}

struct GlossyButtonStyle: ButtonStyle {
  enum Tint { case green, red, gray }
  var tint: Tint = .gray
  @Environment(\.isEnabled) private var enabled
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(ClockTheme.font(25, bold: true)).lineLimit(1).minimumScaleFactor(0.6)
      .dynamicTypeSize(.small ... .xxxLarge)
      .foregroundStyle(enabled ? .white : .white.opacity(0.4))
      .shadow(color: .black.opacity(0.35), radius: 0, y: -1)
      .frame(maxWidth: .infinity).frame(height: 50)
      .background {
        RoundedRectangle(cornerRadius: 10).fill(
          LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
        )
        .overlay {
          RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.45), lineWidth: 1).padding(1)
        }
        .overlay {
          RoundedRectangle(cornerRadius: 12).stroke(.black.opacity(0.7), lineWidth: 3).padding(-3)
        }
        .shadow(color: .white.opacity(0.3), radius: 0, y: 1)
      }.brightness(configuration.isPressed ? -0.2 : 0).contentShape(Rectangle())
  }
  private var stops: [Gradient.Stop] {
    let colors: [Color] =
      switch tint {
      case .green:
        [Color(hex: 0xA4CC9D), Color(hex: 0x60AA4F), Color(hex: 0x4E9E36), Color(hex: 0x3D852B)]
      case .red:
        [Color(hex: 0xEFA1A1), Color(hex: 0xCE4A47), Color(hex: 0xBC2926), Color(hex: 0x99211D)]
      case .gray:
        [Color(hex: 0xBFC0C4), Color(hex: 0x94969B), Color(hex: 0x83858B), Color(hex: 0xABADB1)]
      }
    return zip(colors, [0.0, 0.49, 0.5, 1.0]).map { .init(color: $0, location: $1) }
  }
}

struct ClassicGroup<Content: View>: View {
  @ViewBuilder var content: () -> Content
  var body: some View {
    VStack(spacing: 0, content: content).background(Color(hex: 0xF8F8F8))
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .overlay { RoundedRectangle(cornerRadius: 10).stroke(Color(hex: 0xA5AAB3), lineWidth: 1) }
      .padding(.horizontal, 10)
  }
}

struct SettingsRow: View {
  var title: String
  var value = ""
  var disclosure = true
  var action: () -> Void
  var body: some View {
    Button(action: action) {
      HStack {
        Text(L10n.text(title)).font(ClockTheme.font(17, bold: true)).foregroundStyle(ClockTheme.ink)
        Spacer(minLength: 8)
        Text(value).font(ClockTheme.font(17)).foregroundStyle(ClockTheme.value).lineLimit(1)
        if disclosure {
          Image(systemName: "chevron.right").font(.system(size: 15, weight: .bold)).foregroundStyle(
            .gray)
        }
      }.padding(.horizontal, 13).frame(minHeight: 48).contentShape(Rectangle())
    }.buttonStyle(.plain)
  }
}

struct SilverSeparator: View {
  var body: some View {
    VStack(spacing: 0) {
      Color.black.opacity(0.15).frame(height: 0.5)
      Color.white.opacity(0.8).frame(height: 0.5)
    }
    .accessibilityHidden(true)
  }
}
