import SwiftUI

enum CalendarPalette {
  static let ink = Color(red: 0.24, green: 0.29, blue: 0.36)
  static let blue = Color(red: 0.17, green: 0.40, blue: 0.73)
  static let paper = Color(red: 0.94, green: 0.95, blue: 0.97)
}

extension EventColor {
  var color: Color {
    switch self {
    case .blue: return Color(red: 0.22, green: 0.48, blue: 0.82)
    case .green: return Color(red: 0.22, green: 0.62, blue: 0.23)
    case .red: return Color(red: 0.84, green: 0.21, blue: 0.20)
    case .orange: return Color(red: 0.96, green: 0.53, blue: 0.14)
    case .purple: return Color(red: 0.60, green: 0.34, blue: 0.76)
    case .brown: return Color(red: 0.62, green: 0.45, blue: 0.29)
    }
  }
  var label: String { L10n.text(rawValue.capitalized) }
}

struct CalendarPinstripes: View {
  var body: some View {
    Canvas { context, size in
      context.fill(
        Path(CGRect(origin: .zero, size: size)),
        with: .color(Color(red: 0.86, green: 0.88, blue: 0.91)))
      var lines = Path()
      for x in stride(from: 0.0, to: size.width, by: 6) {
        lines.move(to: CGPoint(x: x, y: 0))
        lines.addLine(to: CGPoint(x: x, y: size.height))
      }
      context.stroke(lines, with: .color(.white.opacity(0.30)), lineWidth: 1)
    }.accessibilityHidden(true).allowsHitTesting(false)
  }
}

struct CalendarMetal: View {
  var body: some View {
    LinearGradient(
      stops: [
        .init(color: Color(red: 0.73, green: 0.78, blue: 0.84), location: 0),
        .init(color: Color(red: 0.57, green: 0.65, blue: 0.75), location: 0.5),
        .init(color: Color(red: 0.44, green: 0.54, blue: 0.67), location: 0.51),
        .init(color: Color(red: 0.46, green: 0.56, blue: 0.69), location: 1),
      ], startPoint: .top, endPoint: .bottom
    )
    .overlay(alignment: .top) { Color.white.opacity(0.55).frame(height: 1) }
    .overlay(alignment: .bottom) { Color(red: 0.27, green: 0.35, blue: 0.45).frame(height: 1) }
    .allowsHitTesting(false)
  }
}

struct ClassicCalendarButtonStyle: ButtonStyle {
  var primary = false
  var destructive = false
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.custom("HelveticaNeue-Bold", size: 14, relativeTo: .subheadline))
      .foregroundStyle(.white)
      .shadow(color: .black.opacity(0.6), radius: 0, y: -1)
      .padding(.horizontal, 11).frame(minHeight: 31)
      .background {
        RoundedRectangle(cornerRadius: 5).fill(
          LinearGradient(
            colors: destructive
              ? [
                Color(red: 0.96, green: 0.47, blue: 0.46),
                Color(red: 0.66, green: 0.02, blue: 0.02),
              ]
              : primary
                ? [
                  Color(red: 0.40, green: 0.63, blue: 0.95),
                  Color(red: 0.04, green: 0.28, blue: 0.71),
                ]
                : [
                  Color(red: 0.64, green: 0.72, blue: 0.82),
                  Color(red: 0.27, green: 0.38, blue: 0.53),
                ],
            startPoint: .top, endPoint: .bottom)
        )
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(.black.opacity(0.42), lineWidth: 1))
        .overlay(alignment: .top) {
          RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.35)).frame(height: 1).padding(
            .horizontal, 2)
        }
      }
      .brightness(configuration.isPressed ? -0.14 : 0)
      .opacity(configuration.isPressed ? 0.9 : 1)
      .contentShape(Rectangle())
  }
}

struct CalendarNavBar<Left: View, Right: View>: View {
  let title: String
  @ViewBuilder let left: Left
  @ViewBuilder let right: Right
  var body: some View {
    ZStack {
      Text(title).font(.custom("HelveticaNeue-Bold", size: 20, relativeTo: .headline))
        .foregroundStyle(.white).shadow(color: .black.opacity(0.55), radius: 0, y: -1)
        .lineLimit(1).minimumScaleFactor(0.7).padding(.horizontal, 100).accessibilityAddTraits(
          .isHeader)
      HStack {
        left
        Spacer(minLength: 8)
        right
      }.padding(.horizontal, 8)
    }
    .frame(minHeight: 44).padding(.vertical, 3)
    .background { CalendarMetal() }
  }
}

struct CalendarGroup<Content: View>: View {
  var title = ""
  @ViewBuilder let content: Content
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if !title.isEmpty {
        Text(L10n.text(title)).font(.custom("HelveticaNeue-Bold", size: 17, relativeTo: .headline))
          .foregroundStyle(CalendarPalette.ink).shadow(color: .white, radius: 0, y: 1).padding(
            .horizontal, 9)
      }
      VStack(spacing: 0) { content }
        .background(.white, in: RoundedRectangle(cornerRadius: 9))
        .overlay {
          RoundedRectangle(cornerRadius: 9).stroke(Color(white: 0.65), lineWidth: 1)
            .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }.padding(.horizontal, 15)
  }
}

struct CalendarRow: View {
  let title: String
  var value = ""
  var chevron = false
  var body: some View {
    HStack(spacing: 10) {
      Text(L10n.text(title)).foregroundStyle(.black)
      Spacer(minLength: 6)
      if !value.isEmpty {
        Text(value).foregroundStyle(CalendarPalette.ink).multilineTextAlignment(.trailing)
      }
      if chevron {
        Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(
          Color(white: 0.55))
      }
    }
    .font(.custom("HelveticaNeue", size: 17, relativeTo: .body))
    .padding(.horizontal, 13).padding(.vertical, 13).frame(minHeight: 46)
    .contentShape(Rectangle())
    .overlay(alignment: .bottom) { Color(white: 0.85).frame(height: 0.5) }
  }
}

struct CalendarCheck: View {
  var checked: Bool
  var body: some View {
    Image(systemName: checked ? "checkmark" : "circle")
      .font(.system(size: 19, weight: .bold)).foregroundStyle(
        checked ? CalendarPalette.blue : Color(white: 0.72)
      )
      .frame(width: 25)
  }
}

struct CalendarEmpty: View {
  let title: String
  var subtitle = ""
  var body: some View {
    VStack(spacing: 12) {
      Text(L10n.text(title)).font(.custom("HelveticaNeue-Bold", size: 22, relativeTo: .title2))
        .foregroundStyle(Color(white: 0.55))
      if !subtitle.isEmpty {
        Text(L10n.text(subtitle)).font(.custom("HelveticaNeue", size: 14, relativeTo: .subheadline))
          .foregroundStyle(Color(white: 0.48)).multilineTextAlignment(.center)
      }
    }.padding(30).frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

struct CalendarNotice: View {
  let message: String
  let dismiss: () -> Void
  var body: some View {
    ZStack {
      Color.black.opacity(0.42).ignoresSafeArea().accessibilityHidden(true)
      VStack(spacing: 18) {
        Text(L10n.text("Calendar")).font(.custom("HelveticaNeue-Bold", size: 21))
        Text(message).font(.custom("HelveticaNeue", size: 16)).multilineTextAlignment(.center)
        Button(L10n.text("OK"), action: dismiss).buttonStyle(
          ClassicCalendarButtonStyle(primary: true)
        ).accessibilityIdentifier("notice-ok")
      }.padding(24).frame(maxWidth: 310)
        .foregroundStyle(.white).shadow(color: .black, radius: 0, y: -1)
        .background(
          RoundedRectangle(cornerRadius: 12).fill(
            LinearGradient(
              colors: [
                Color(red: 0.35, green: 0.44, blue: 0.59),
                Color(red: 0.12, green: 0.20, blue: 0.36),
              ], startPoint: .top, endPoint: .bottom))
        )
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.7), lineWidth: 2))
        .accessibilityAddTraits(.isModal)
    }
  }
}
