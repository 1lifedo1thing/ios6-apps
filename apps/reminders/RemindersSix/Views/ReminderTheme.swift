import SwiftUI

enum Classic {
  static let ink = Color(red: 0.20, green: 0.20, blue: 0.18)
  static let red = Color(red: 0.68, green: 0.12, blue: 0.19)
  static let paper = Color(red: 0.95, green: 0.95, blue: 0.93)
  static let muted = Color(red: 0.48, green: 0.48, blue: 0.44)
  static func font(_ size: CGFloat, bold: Bool = false) -> Font {
    .custom(bold ? "HelveticaNeue-Bold" : "HelveticaNeue", size: size, relativeTo: .body)
  }
}

struct LeatherSurface: View {
  var body: some View {
    Image(decorative: "LeatherTexture").resizable(resizingMode: .tile).accessibilityHidden(true)
      .overlay(
        LinearGradient(
          colors: [.white.opacity(0.015), .clear, .black.opacity(0.08)], startPoint: .top,
          endPoint: .bottom)
      )
      .accessibilityHidden(true).allowsHitTesting(false)
  }
}

struct DarkListSurface: View {
  var body: some View {
    LinearGradient(
      colors: [Color(white: 0.185), Color(white: 0.175)], startPoint: .top,
      endPoint: .bottom
    ).accessibilityHidden(true).allowsHitTesting(false)
  }
}

struct PaperSurface: View {
  var body: some View {
    Image(decorative: "PaperTexture").resizable(resizingMode: .tile).accessibilityHidden(true)
      .accessibilityHidden(true).allowsHitTesting(false)
  }
}

struct TopBodySurface: View {
  let paper: Bool
  let ruled: Bool
  var body: some View {
    GeometryReader { geometry in
      if geometry.safeAreaInsets.top > 0 {
        Group {
          if paper {
            PaperSurface().overlay {
              if ruled { BlankRules(firstLine: 12).padding(.horizontal, 7) }
            }
          } else {
            Color(white: 0.185)
          }
        }
        .frame(height: geometry.safeAreaInsets.top)
        .offset(y: -geometry.safeAreaInsets.top)
      }
    }.accessibilityHidden(true).allowsHitTesting(false)
  }
}

struct ClassicButtonStyle: ButtonStyle {
  var silver = false
  var danger = false
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(Classic.font(14, bold: true))
      .foregroundStyle(danger ? Classic.red : (silver ? Classic.ink : .white))
      .shadow(
        color: silver ? .white.opacity(0.7) : .black.opacity(0.8), radius: 0, y: silver ? 1 : -1
      )
      .padding(.horizontal, 11).frame(minHeight: 30)
      .background {
        RoundedRectangle(cornerRadius: 5)
          .fill(
            LinearGradient(
              colors: silver
                ? [Color(white: 0.94), Color(white: 0.71), Color(white: 0.60)]
                : [Color(white: 0.25), Color(white: 0.19), Color(white: 0.13)],
              startPoint: .top, endPoint: .bottom)
          )
          .overlay(
            RoundedRectangle(cornerRadius: 5).strokeBorder(
              silver ? Color.black.opacity(0.35) : .black.opacity(0.7), lineWidth: 1)
          )
          .overlay(
            RoundedRectangle(cornerRadius: 4).inset(by: 1).stroke(
              .white.opacity(silver ? 0.5 : 0.1), lineWidth: 1)
          )
          .shadow(color: .black.opacity(0.5), radius: 1, y: 1)
      }
      .brightness(configuration.isPressed ? -0.15 : 0)
      .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
  }
}

struct ClassicHeader<Leading: View, Trailing: View>: View {
  let title: String
  var darkLeather = false
  @ViewBuilder var leading: Leading
  @ViewBuilder var trailing: Trailing
  var body: some View {
    HStack(spacing: 4) {
      leading.frame(minWidth: 62, alignment: .leading)
      Text(title).font(Classic.font(20, bold: true)).foregroundStyle(Color(white: 0.91))
        .shadow(color: .black, radius: 0, y: -1).lineLimit(1).minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity)
      trailing.frame(minWidth: 62, alignment: .trailing)
    }
    .padding(.horizontal, 8).frame(minHeight: 44)
    .background {
      LeatherSurface()
        .overlay {
          LinearGradient(
            colors: darkLeather
              ? [.black.opacity(0.20), .black.opacity(0.38)]
              : [.white.opacity(0.025), .black.opacity(0.04)], startPoint: .top,
            endPoint: .bottom)
        }
    }
    .overlay(alignment: .top) {
      Rectangle().fill(.white.opacity(0.07)).frame(height: 0.5).allowsHitTesting(false)
    }
    .overlay(alignment: .bottom) {
      Rectangle().fill(.black.opacity(0.45)).frame(height: 0.5).allowsHitTesting(false)
    }
  }
}

struct PaperAddButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.frame(width: 34, height: 34)
      .background {
        RoundedRectangle(cornerRadius: 5)
          .fill(Color.black.opacity(configuration.isPressed ? 0.08 : 0.025))
          .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.black.opacity(0.20)))
          .overlay(RoundedRectangle(cornerRadius: 4).inset(by: 1).stroke(.white.opacity(0.65)))
          .shadow(color: .white.opacity(0.65), radius: 0, y: 1)
      }
      .frame(width: 44, height: 44).contentShape(Rectangle())
  }
}

struct RecessedListPanel<Content: View>: View {
  @ViewBuilder var content: Content
  var body: some View {
    content.background { DarkListSurface() }
      .clipShape(RoundedRectangle(cornerRadius: 5))
      .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.black.opacity(0.55)))
      .overlay(alignment: .top) {
        RoundedRectangle(cornerRadius: 4).fill(.black.opacity(0.12)).frame(height: 3).padding(1)
      }
      .shadow(color: .white.opacity(0.08), radius: 0, y: 1)
  }
}

struct PaperCard<Content: View>: View {
  @ViewBuilder var content: Content
  var body: some View {
    content.foregroundStyle(Classic.ink).background { PaperSurface() }
      .clipShape(RoundedRectangle(cornerRadius: 5))
      .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.black.opacity(0.35), lineWidth: 1))
      .overlay(
        RoundedRectangle(cornerRadius: 4).inset(by: 2).stroke(.white.opacity(0.6), lineWidth: 1)
      )
      .shadow(color: .black.opacity(0.65), radius: 2, y: 2)
  }
}

struct MarginRules: View {
  var body: some View {
    HStack(spacing: 2) {
      Rectangle().fill(Color(red: 0.94, green: 0.56, blue: 0.60).opacity(0.6)).frame(width: 1)
      Rectangle().fill(Color(red: 0.94, green: 0.56, blue: 0.60).opacity(0.5)).frame(width: 1)
    }.frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 47)
      .accessibilityHidden(true).allowsHitTesting(false)
  }
}
struct DottedRule: View {
  var body: some View {
    Canvas { context, size in
      var path = Path()
      path.move(to: CGPoint(x: 0, y: 0.5))
      path.addLine(to: CGPoint(x: size.width, y: 0.5))
      context.stroke(
        path, with: .color(.gray.opacity(0.32)), style: StrokeStyle(lineWidth: 0.6, dash: [1, 2]))
    }.frame(height: 1).accessibilityHidden(true).allowsHitTesting(false)
  }
}
struct BlankRules: View {
  var firstLine: CGFloat = 52
  var body: some View {
    Canvas { context, size in
      for y in stride(from: firstLine, to: size.height, by: 52) {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: y))
        path.addLine(to: CGPoint(x: size.width, y: y))
        context.stroke(
          path, with: .color(.gray.opacity(0.25)), style: StrokeStyle(lineWidth: 0.6, dash: [1, 2]))
      }
    }.overlay { MarginRules() }.accessibilityHidden(true).allowsHitTesting(false)
  }
}

struct ClassicCheckbox: View {
  let checked: Bool
  var body: some View {
    Rectangle()
      .fill(
        LinearGradient(
          colors: [Color(white: 0.78), Color(white: 0.89)], startPoint: .top, endPoint: .bottom)
      )
      .overlay { Rectangle().strokeBorder(Color(white: 0.56), lineWidth: 0.75) }
      .frame(width: 16, height: 16)
      .shadow(color: .white.opacity(0.75), radius: 0, y: 1)
      .overlay {
        if checked {
          NotebookCheckmark().stroke(
            Classic.ink, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
          ).accessibilityHidden(true).allowsHitTesting(false)
        }
      }
  }
}

private struct NotebookCheckmark: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.minX + rect.width * 0.17, y: rect.minY + rect.height * 0.47))
    path.addQuadCurve(
      to: CGPoint(x: rect.minX + rect.width * 0.34, y: rect.minY + rect.height * 0.70),
      control: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.77))
    // The long arm intentionally extends above and to the right of the square.
    path.addCurve(
      to: CGPoint(x: rect.minX + rect.width * 1.06, y: rect.minY - rect.height * 0.09),
      control1: CGPoint(x: rect.minX + rect.width * 0.52, y: rect.minY + rect.height * 0.50),
      control2: CGPoint(x: rect.minX + rect.width * 0.82, y: rect.minY + rect.height * 0.17))
    return path
  }
}

struct ClassicToggle: View {
  let title: String
  @Binding var isOn: Bool
  var body: some View {
    Button {
      isOn.toggle()
    } label: {
      HStack {
        Text(L10n.text(title)).font(Classic.font(17)).frame(
          maxWidth: .infinity, alignment: .leading)
        ZStack(alignment: isOn ? .trailing : .leading) {
          Capsule().fill(
            LinearGradient(
              colors: isOn
                ? [
                  Color(red: 0.10, green: 0.32, blue: 0.73),
                  Color(red: 0.26, green: 0.57, blue: 0.95),
                ] : [Color(white: 0.62), Color(white: 0.86)], startPoint: .top, endPoint: .bottom)
          )
          .overlay(Capsule().strokeBorder(.black.opacity(0.3), lineWidth: 1))
          Text(L10n.text(isOn ? "ON" : "OFF")).font(Classic.font(13, bold: true))
            .foregroundStyle(isOn ? .white : Color(white: 0.4)).frame(width: 42).offset(
              x: isOn ? -31 : 31)
          Circle().fill(
            LinearGradient(
              colors: [.white, Color(white: 0.83)], startPoint: .top, endPoint: .bottom)
          )
          .overlay(Circle().stroke(.black.opacity(0.3), lineWidth: 1)).padding(1)
        }.frame(width: 76, height: 28)
      }.frame(minHeight: 50).padding(.horizontal, 12).contentShape(Rectangle())
    }.buttonStyle(.plain).accessibilityLabel(L10n.text(title))
      .accessibilityValue(L10n.text(isOn ? "ON" : "OFF")).accessibilityAddTraits(
        isOn ? .isSelected : []
      )
      .accessibilityIdentifier(title)
  }
}

struct DetailGroup<Content: View>: View {
  @ViewBuilder var content: Content
  var body: some View {
    VStack(spacing: 0) { content }
      .background(.white.opacity(0.08))
      .overlay(Rectangle().strokeBorder(.gray.opacity(0.35), lineWidth: 0.7))
  }
}
struct DetailLine: View {
  var body: some View { Rectangle().fill(.gray.opacity(0.3)).frame(height: 0.7) }
}
struct DetailRow: View {
  let title: String
  var value = ""
  var action: (() -> Void)?
  var body: some View {
    Button {
      action?()
    } label: {
      HStack {
        Text(L10n.text(title)).font(Classic.font(17))
        Spacer(minLength: 12)
        Text(value).font(Classic.font(16)).foregroundStyle(Classic.muted).lineLimit(2)
        if action != nil {
          Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(
            .gray.opacity(0.6))
        }
      }.frame(minHeight: 50).padding(.horizontal, 12).contentShape(Rectangle())
    }.buttonStyle(.plain).disabled(action == nil).accessibilityIdentifier(title)
  }
}

struct ClassicError: ViewModifier {
  @Binding var error: String?
  func body(content: Content) -> some View {
    content.alert(
      L10n.text("Reminders"),
      isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    ) {
      Button(L10n.text("OK")) { error = nil }
    } message: {
      Text(error ?? "")
    }
  }
}
