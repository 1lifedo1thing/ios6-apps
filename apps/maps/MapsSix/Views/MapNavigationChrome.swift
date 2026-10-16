import SwiftUI

struct NavigationMetal: View {
  var body: some View {
    LinearGradient(
      stops: [
        .init(color: Color(red: 0.97, green: 0.97, blue: 0.98), location: 0),
        .init(color: Color(red: 0.90, green: 0.91, blue: 0.92), location: 0.42),
        .init(color: Color(red: 0.78, green: 0.80, blue: 0.82), location: 1),
      ], startPoint: .top, endPoint: .bottom
    )
    .overlay(alignment: .top) { Color.white.opacity(0.9).frame(height: 0.5) }
    .overlay(alignment: .bottom) { Color(white: 0.48).frame(height: 0.5) }
    .allowsHitTesting(false).accessibilityHidden(true)
  }
}

struct ClassicHeader: View {
  let title: String
  var prompt: String?
  var back = "Cancel"
  var done = "Done"
  var onBack: (() -> Void)?
  var onDone: (() -> Void)?
  var clear: (() -> Void)?
  var canClear = false

  var body: some View {
    VStack(spacing: 0) {
      if let prompt {
        Text(L10n.text(prompt))
          .font(MapTheme.font(13))
          .foregroundStyle(Color(red: 0.46, green: 0.48, blue: 0.51))
          .shadow(color: .white.opacity(0.5), radius: 0, y: 0.5)
          .lineLimit(1).minimumScaleFactor(0.8)
          .frame(maxWidth: .infinity).frame(height: 20)
      }
      ZStack {
        Text(L10n.text(title)).font(MapTheme.font(20, bold: true))
          .foregroundStyle(Color(red: 0.36, green: 0.39, blue: 0.43))
          .shadow(color: .white.opacity(0.7), radius: 0, y: 0.5)
          .lineLimit(1).minimumScaleFactor(0.7).padding(.horizontal, 82)
          .accessibilityIdentifier("panel-title")
        HStack(spacing: 0) {
          if let onBack {
            Button(L10n.text(back), action: onBack)
              .buttonStyle(NavigationButton(backArrow: back == "Back"))
          } else if let clear {
            Button(L10n.text("Clear"), action: clear)
              .buttonStyle(NavigationButton()).disabled(!canClear)
              .accessibilityIdentifier("clear-recents")
          }
          Spacer(minLength: 0)
          if let onDone {
            Button(L10n.text(done), action: onDone)
              .buttonStyle(NavigationButton(primary: true))
              .accessibilityIdentifier("panel-done")
          }
        }.padding(.horizontal, 6)
      }.frame(height: 44)
    }
    .background { NavigationMetal() }
  }
}

private struct NavigationButton: ButtonStyle {
  var primary = false
  var backArrow = false
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(MapTheme.font(13, bold: true)).foregroundStyle(.white)
      .shadow(color: .black.opacity(0.4), radius: 0, y: -0.5)
      .padding(.leading, backArrow ? 17 : 11).padding(.trailing, 11)
      .frame(height: 29)
      .background {
        NavigationButtonOutline(arrow: backArrow)
          .fill(
            LinearGradient(
              stops: [
                .init(
                  color: primary ? Color(red: 0.53, green: 0.69, blue: 0.91) : Color(white: 0.70),
                  location: 0),
                .init(
                  color: primary ? Color(red: 0.35, green: 0.54, blue: 0.80) : Color(white: 0.57),
                  location: 0.49),
                .init(
                  color: primary ? Color(red: 0.23, green: 0.43, blue: 0.72) : Color(white: 0.48),
                  location: 0.51),
                .init(
                  color: primary ? Color(red: 0.28, green: 0.49, blue: 0.78) : Color(white: 0.55),
                  location: 1),
              ], startPoint: .top, endPoint: .bottom)
          )
          .overlay {
            NavigationButtonOutline(arrow: backArrow)
              .stroke(.black.opacity(0.45), lineWidth: 0.7)
          }
          .overlay {
            NavigationButtonOutline(arrow: backArrow)
              .stroke(.white.opacity(0.28), lineWidth: 0.7).padding(1)
          }
          .shadow(color: .white.opacity(0.85), radius: 0, y: 1)
      }
      .brightness(configuration.isPressed ? -0.16 : 0)
      .opacity(isEnabled ? 1 : 0.45)
      .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
  }
}

private struct NavigationButtonOutline: Shape {
  var arrow: Bool

  func path(in rect: CGRect) -> Path {
    guard arrow else { return Path(roundedRect: rect, cornerRadius: 4) }
    let tip = rect.height * 0.36
    return Path { path in
      path.move(to: CGPoint(x: tip + 2, y: rect.minY))
      path.addLine(to: CGPoint(x: rect.maxX - 4, y: rect.minY))
      path.addQuadCurve(to: CGPoint(x: rect.maxX, y: 4), control: CGPoint(x: rect.maxX, y: 0))
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 4))
      path.addQuadCurve(
        to: CGPoint(x: rect.maxX - 4, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
      path.addLine(to: CGPoint(x: tip + 2, y: rect.maxY))
      path.addQuadCurve(
        to: CGPoint(x: tip - 1, y: rect.maxY - 2), control: CGPoint(x: tip, y: rect.maxY))
      path.addLine(to: CGPoint(x: 0.5, y: rect.midY + 1.2))
      path.addQuadCurve(
        to: CGPoint(x: 0.5, y: rect.midY - 1.2), control: CGPoint(x: -0.5, y: rect.midY))
      path.addLine(to: CGPoint(x: tip - 1, y: 2))
      path.addQuadCurve(to: CGPoint(x: tip + 2, y: rect.minY), control: CGPoint(x: tip, y: 0))
      path.closeSubpath()
    }
  }
}

struct BookmarkSelector: View {
  @Binding var selection: Int
  private let tabs = ["Bookmarks", "Recents", "Landmarks"]

  var body: some View {
    HStack(spacing: 0) {
      ForEach(tabs.indices, id: \.self) { index in
        Button {
          selection = index
        } label: {
          Text(L10n.text(tabs[index]))
            .lineLimit(1).minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity).frame(height: 30)
            .contentShape(Rectangle())
        }
        .buttonStyle(BookmarkSegment(selected: selection == index, index: index))
        .accessibilityIdentifier("bookmarks-tab-\(index)")
        .accessibilityAddTraits(selection == index ? .isSelected : [])
      }
    }
    .background {
      RoundedRectangle(cornerRadius: 5)
        .fill(Color(white: 0.48))
        .overlay {
          RoundedRectangle(cornerRadius: 5).stroke(.black.opacity(0.48), lineWidth: 0.7)
        }
        .shadow(color: .white.opacity(0.95), radius: 0, y: 1)
        .padding(.vertical, 7)
    }
    .padding(.horizontal, 8)
    .background { NavigationMetal().rotationEffect(.degrees(180)) }
  }
}

private struct BookmarkSegment: ButtonStyle {
  let selected: Bool
  let index: Int

  func makeBody(configuration: Configuration) -> some View {
    let shape = UnevenRoundedRectangle(
      topLeadingRadius: index == 0 ? 4 : 0,
      bottomLeadingRadius: index == 0 ? 4 : 0,
      bottomTrailingRadius: index == 2 ? 4 : 0,
      topTrailingRadius: index == 2 ? 4 : 0)
    configuration.label
      .font(MapTheme.font(13, bold: true))
      .foregroundStyle(selected ? .white : Color(white: 0.31))
      .shadow(color: selected ? .black.opacity(0.6) : .white, radius: 0, y: selected ? -1 : 1)
      .background {
        shape.fill(
          LinearGradient(
            stops: selected
              ? [
                .init(color: Color(white: 0.36), location: 0),
                .init(color: Color(white: 0.43), location: 0.52),
                .init(color: Color(white: 0.52), location: 1),
              ]
              : [
                .init(color: Color(white: 0.98), location: 0),
                .init(color: Color(white: 0.89), location: 0.49),
                .init(color: Color(white: 0.82), location: 0.51),
                .init(color: Color(white: 0.75), location: 1),
              ], startPoint: .top, endPoint: .bottom)
        )
        .overlay(alignment: .top) {
          Color(selected ? .black : .white).opacity(selected ? 0.25 : 0.8).frame(height: 1)
        }
        .overlay(alignment: .leading) {
          if index > 0 {
            HStack(spacing: 0) {
              Color.black.opacity(0.35).frame(width: 0.5)
              Color.white.opacity(selected ? 0.1 : 0.65).frame(width: 0.5)
            }
          }
        }
        .clipShape(shape).padding(.vertical, 0.7).padding(.horizontal, index == 1 ? 0 : 0.7)
      }
      .brightness(configuration.isPressed ? -0.14 : 0)
      .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
  }
}
