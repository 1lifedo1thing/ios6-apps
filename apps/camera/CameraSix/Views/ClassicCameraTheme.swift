import SwiftUI

enum CameraTheme {
  static let silver = LinearGradient(
    colors: [Color(white: 0.96), Color(white: 0.77), Color(white: 0.57)],
    startPoint: .top, endPoint: .bottom)
  static let dark = LinearGradient(
    stops: [
      .init(color: Color(white: 0.30), location: 0),
      .init(color: Color(white: 0.12), location: 0.48),
      .init(color: Color(white: 0.03), location: 0.51),
      .init(color: Color(white: 0.13), location: 1),
    ], startPoint: .top, endPoint: .bottom)
  static let blue = LinearGradient(
    colors: [
      Color(red: 0.60, green: 0.69, blue: 0.80),
      Color(red: 0.31, green: 0.42, blue: 0.58),
    ], startPoint: .top, endPoint: .bottom)

  static func font(_ size: CGFloat, bold: Bool = false) -> Font {
    .custom(bold ? "HelveticaNeue-Bold" : "HelveticaNeue", size: size)
  }
}

struct ChromeButtonStyle: ButtonStyle {
  var dark = false
  var capsule = true

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(CameraTheme.font(14, bold: true))
      .foregroundStyle(dark ? .white : Color(white: 0.13))
      .shadow(
        color: dark ? .black.opacity(0.8) : .white.opacity(0.7), radius: 0,
        y: dark ? -1 : 1
      )
      .padding(.horizontal, 12)
      .frame(minHeight: 29)
      .background {
        RoundedRectangle(cornerRadius: capsule ? 16 : 5)
          .fill(dark ? CameraTheme.dark : CameraTheme.silver)
          .overlay {
            RoundedRectangle(cornerRadius: capsule ? 16 : 5).stroke(
              .black.opacity(0.8), lineWidth: 1
            )
            .padding(0.5)
          }
          .overlay {
            RoundedRectangle(cornerRadius: capsule ? 16 : 5).stroke(
              .white.opacity(0.45), lineWidth: 1
            )
            .padding(1.5)
          }
          .shadow(color: .black.opacity(0.7), radius: 1, y: 1)
      }
      .brightness(configuration.isPressed ? -0.18 : 0)
      .contentShape(Rectangle())
  }
}

struct CameraGlyph: View {
  var video = false

  var body: some View {
    GeometryReader { geometry in
      let w = geometry.size.width
      let h = geometry.size.height
      Path { path in
        if video {
          path.addRoundedRect(
            in: CGRect(x: 0, y: h * 0.18, width: w * 0.7, height: h * 0.65),
            cornerSize: CGSize(width: 2, height: 2))
          path.move(to: CGPoint(x: w * 0.75, y: h * 0.35))
          path.addLine(to: CGPoint(x: w, y: h * 0.18))
          path.addLine(to: CGPoint(x: w, y: h * 0.83))
          path.addLine(to: CGPoint(x: w * 0.75, y: h * 0.65))
          path.closeSubpath()
        } else {
          path.addRoundedRect(
            in: CGRect(x: 0, y: h * 0.24, width: w, height: h * 0.72),
            cornerSize: CGSize(width: 2, height: 2))
          path.addRoundedRect(
            in: CGRect(x: w * 0.28, y: h * 0.05, width: w * 0.44, height: h * 0.35),
            cornerSize: CGSize(width: 1, height: 1))
        }
      }.fill()
      if !video {
        Circle().stroke(Color(white: 0.75), lineWidth: max(1.5, w * 0.065))
          .frame(width: w * 0.43, height: w * 0.43).position(x: w * 0.5, y: h * 0.58)
      }
    }.accessibilityHidden(true)
  }
}

struct ClassicSwitch: View {
  let label: String
  let isOn: Bool
  var enabled = true
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 0) {
        if isOn {
          Text(L10n.text("ON")).font(CameraTheme.font(15, bold: true)).foregroundStyle(.white)
            .frame(width: 43, height: 27).background(
              LinearGradient(
                colors: [
                  Color(red: 0.11, green: 0.32, blue: 0.70),
                  Color(red: 0.32, green: 0.63, blue: 0.98),
                ], startPoint: .top, endPoint: .bottom))
        }
        RoundedRectangle(cornerRadius: 3).fill(CameraTheme.silver).frame(width: 31, height: 27)
          .overlay(RoundedRectangle(cornerRadius: 3).stroke(.black.opacity(0.25)))
        if !isOn {
          Text(L10n.text("OFF")).font(CameraTheme.font(14, bold: true)).foregroundStyle(
            Color(white: 0.4)
          )
          .frame(width: 43, height: 27).background(Color(white: 0.92))
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: 4))
      .overlay(RoundedRectangle(cornerRadius: 4).stroke(.black.opacity(0.7)))
      .opacity(enabled ? 1 : 0.4)
      .frame(minHeight: 44)
    }
    .buttonStyle(.plain)
    .disabled(!enabled)
    .accessibilityLabel(L10n.text(label))
    .accessibilityValue(L10n.text(isOn ? "On" : "Off"))
    .accessibilityIdentifier(
      label.lowercased().replacingOccurrences(of: " ", with: "-") + "-switch")
  }
}

struct ClassicNavigation: View {
  let title: String
  let leading: String
  let action: () -> Void
  var trailing: AnyView? = nil

  var body: some View {
    ZStack {
      CameraTheme.blue
      HStack {
        Button(L10n.text(leading), action: action).buttonStyle(
          ChromeButtonStyle(dark: true, capsule: false)
        )
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityIdentifier("navigation-back")
        Spacer()
        if let trailing { trailing } else { Color.clear.frame(width: 64) }
      }.padding(.horizontal, 7)
      Text(title).font(CameraTheme.font(20, bold: true)).foregroundStyle(.white)
        .shadow(color: .black.opacity(0.6), radius: 0, y: -1)
        .allowsHitTesting(false).padding(.horizontal, 85).lineLimit(1).minimumScaleFactor(0.7)
    }
    .frame(height: 48)
    .overlay(alignment: .bottom) { Rectangle().fill(.black.opacity(0.5)).frame(height: 1) }
  }
}

struct Pinstripes: View {
  var body: some View {
    Canvas { context, size in
      context.fill(
        Path(CGRect(origin: .zero, size: size)),
        with: .color(Color(red: 0.82, green: 0.85, blue: 0.88)))
      for x in stride(from: 0.0, through: size.width, by: 7) {
        context.fill(
          Path(CGRect(x: x, y: 0, width: 1, height: size.height)),
          with: .color(.white.opacity(0.35)))
      }
    }.allowsHitTesting(false).accessibilityHidden(true)
  }
}
