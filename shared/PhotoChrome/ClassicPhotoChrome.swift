import SwiftUI

// Camera Roll and Photos share the same classic chrome and interaction dimensions.
enum ClassicPhotoChrome {
  static let chrome = LinearGradient(
    stops: [
      .init(color: Color(white: 0.66), location: 0),
      .init(color: Color(white: 0.46), location: 0.49),
      .init(color: Color(white: 0.38), location: 0.51),
      .init(color: Color(white: 0.37), location: 1),
    ], startPoint: .top, endPoint: .bottom)
  static let black = LinearGradient(
    stops: [
      .init(color: Color(white: 0.26), location: 0),
      .init(color: Color(white: 0.13), location: 0.49),
      .init(color: Color(white: 0.035), location: 0.51), .init(color: .black, location: 1),
    ], startPoint: .top, endPoint: .bottom)
  static func font(_ size: CGFloat, bold: Bool = false) -> Font {
    .custom(bold ? "HelveticaNeue-Bold" : "HelveticaNeue", size: size, relativeTo: .body)
  }
}

struct ClassicPhotoButtonStyle: ButtonStyle {
  var primary = false
  var destructive = false
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(ClassicPhotoChrome.font(13, bold: true))
      .foregroundStyle(.white).shadow(color: .black.opacity(0.7), radius: 0, y: -1)
      .padding(.horizontal, 11).frame(minHeight: 30)
      .background {
        let shape = RoundedRectangle(cornerRadius: 5, style: .circular)
        shape.fill(
          LinearGradient(
            colors: destructive
              ? [
                Color(red: 0.86, green: 0.46, blue: 0.44),
                Color(red: 0.65, green: 0.09, blue: 0.08),
              ]
              : primary
                ? [
                  Color(red: 0.45, green: 0.66, blue: 0.92),
                  Color(red: 0.10, green: 0.34, blue: 0.65),
                ] : [Color(white: 0.42), Color(white: 0.02)], startPoint: .top, endPoint: .bottom)
        )
        .overlay { shape.strokeBorder(.black.opacity(0.6), lineWidth: 1) }
        .overlay {
          // Keep the highlight inside the bezel so it follows both upper corners.
          shape.inset(by: 1).strokeBorder(
            LinearGradient(
              stops: [
                .init(color: .white.opacity(0.4), location: 0),
                .init(color: .white.opacity(0.08), location: 0.5),
                .init(color: .black.opacity(0.16), location: 1),
              ], startPoint: .top, endPoint: .bottom),
            lineWidth: 1)
        }
      }
      .brightness(configuration.isPressed ? -0.15 : 0)
      .opacity(configuration.isPressed ? 0.85 : 1)
  }
}

struct ClassicPhotoNavigation<Leading: View, Trailing: View>: View {
  let title: String
  var dark = false
  var accessibilityTitle: String? = nil
  var titleIdentifier = "photo-navigation-title"
  @ViewBuilder let leading: Leading
  @ViewBuilder let trailing: Trailing
  var body: some View {
    PhotoNavigationLayout {
      ZStack {
        Color.clear.frame(width: 0, height: 0)
        leading
      }.frame(minWidth: 44, minHeight: 44)
      Text(title).font(ClassicPhotoChrome.font(20, bold: true)).lineLimit(1).minimumScaleFactor(0.7)
        .foregroundStyle(.white).shadow(color: .black.opacity(0.7), radius: 0, y: -1)
        .frame(maxWidth: .infinity).clipped()
        .accessibilityLabel(accessibilityTitle ?? title)
        .accessibilityIdentifier(titleIdentifier)
      ZStack {
        Color.clear.frame(width: 0, height: 0)
        trailing
      }.frame(minWidth: 44, minHeight: 44)
    }.padding(.horizontal, 7).frame(height: 44)
      .background(
        dark ? AnyShapeStyle(ClassicPhotoChrome.black) : AnyShapeStyle(ClassicPhotoChrome.chrome),
        ignoresSafeAreaEdges: []
      )
      .overlay(alignment: .top) { Color.white.opacity(0.45).frame(height: 1) }
      .overlay(alignment: .bottom) { Color.black.opacity(0.5).frame(height: 1) }
  }
}

private struct PhotoNavigationLayout: Layout {
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    CGSize(width: proposal.width ?? 320, height: 44)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    guard subviews.count == 3 else { return }
    let left = subviews[0].sizeThatFits(.unspecified).width
    let right = subviews[2].sizeThatFits(.unspecified).width
    let titleWidth = max(0, bounds.width - 2 * (max(left, right) + 8))
    subviews[0].place(
      at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading,
      proposal: ProposedViewSize(width: left, height: 44))
    subviews[1].place(
      at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center,
      proposal: ProposedViewSize(width: titleWidth, height: 44))
    subviews[2].place(
      at: CGPoint(x: bounds.maxX, y: bounds.midY), anchor: .trailing,
      proposal: ProposedViewSize(width: right, height: 44))
  }
}
