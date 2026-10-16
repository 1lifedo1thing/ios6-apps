import SwiftUI

struct MapFloatingButton: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .frame(minWidth: 44, minHeight: 44)
      .shadow(color: .white.opacity(0.9), radius: 0, y: 1)
      .background(configuration.isPressed ? Color.black.opacity(0.13) : .clear)
      .overlay(alignment: .trailing) {
        Color.black.opacity(0.18).frame(width: 0.7).padding(.vertical, 1).allowsHitTesting(false)
      }.contentShape(Rectangle())
  }
}

struct MapOptionButton: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(MapTheme.font(16, bold: true)).lineLimit(1).minimumScaleFactor(0.7)
      .foregroundStyle(MapTheme.ink).shadow(color: .white.opacity(0.85), radius: 0, y: 1)
      .frame(maxWidth: .infinity, minHeight: 44)
      .background(MapTheme.silver, in: RoundedRectangle(cornerRadius: 6))
      .overlay {
        RoundedRectangle(cornerRadius: 6).stroke(.black.opacity(0.5), lineWidth: 0.8)
          .overlay {
            RoundedRectangle(cornerRadius: 5).stroke(.white.opacity(0.55), lineWidth: 0.7)
              .padding(1)
          }.allowsHitTesting(false)
      }
      .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
      .brightness(configuration.isPressed ? -0.12 : 0)
      .contentShape(Rectangle())
  }
}

struct MapOptionSegment: ButtonStyle {
  let selected: Bool
  let first: Bool
  let last: Bool

  func makeBody(configuration: Configuration) -> some View {
    let shape = UnevenRoundedRectangle(
      topLeadingRadius: first ? 5 : 0, bottomLeadingRadius: first ? 5 : 0,
      bottomTrailingRadius: last ? 5 : 0, topTrailingRadius: last ? 5 : 0)
    configuration.label
      .font(MapTheme.font(14, bold: true)).lineLimit(1).minimumScaleFactor(0.7)
      .foregroundStyle(selected ? .white : MapTheme.ink)
      .shadow(color: selected ? .black.opacity(0.5) : .white, radius: 0, y: selected ? -1 : 1)
      .frame(maxWidth: .infinity, minHeight: 44)
      .background(
        selected ? AnyShapeStyle(MapTheme.graphite) : AnyShapeStyle(MapTheme.silver), in: shape
      )
      .overlay(shape.stroke(.black.opacity(0.45), lineWidth: 0.7).allowsHitTesting(false))
      .brightness(configuration.isPressed ? -0.1 : 0)
      .contentShape(Rectangle())
  }
}
