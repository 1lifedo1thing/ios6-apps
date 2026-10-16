import SwiftUI

struct MapFoldGeometry: Equatable {
  static let canvasSize = CGSize(width: 84, height: 108)
  var scale: CGFloat
  var roundedDisplay: Bool

  func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
    CGPoint(
      x: Self.canvasSize.width - (roundedDisplay ? 20 : 0) + (x - 32) * scale,
      y: Self.canvasSize.height - (roundedDisplay ? 20 : 0) + (y - 40) * scale)
  }
  var tip: CGPoint { point(6.5, 25.5) }
  var upper: CGPoint {
    let base = point(32, 0)
    let extensionWidth = Self.canvasSize.width - base.x
    return CGPoint(x: Self.canvasSize.width, y: base.y - extensionWidth)
  }
  var lower: CGPoint { point(15, 40) }
  var roll: CGPoint {
    let base = point(31.66, 13.62)
    let extensionWidth = Self.canvasSize.width - point(32, 0).x
    return CGPoint(x: base.x + extensionWidth * 0.7, y: base.y - extensionWidth * 0.7)
  }
  var outer: CGPoint { CGPoint(x: Self.canvasSize.width, y: Self.canvasSize.height) }
  var foot: CGPoint {
    CGPoint(
      x: roundedDisplay ? min(lower.x, Self.canvasSize.width - 66) : lower.x,
      y: Self.canvasSize.height)
  }
  var lowerJoin: CGPoint { CGPoint(x: lower.x, y: (lower.y + foot.y) / 2) }
  var cutout: Path {
    Path { path in
      path.move(to: tip)
      path.addLine(to: upper)
      path.addLine(to: outer)
      path.addLine(to: foot)
      path.addQuadCurve(to: lower, control: lowerJoin)
      path.closeSubpath()
    }
  }
  var paper: Path {
    Path { path in
      path.move(to: tip)
      path.addLine(to: upper)
      path.addQuadCurve(to: lower, control: roll)
      path.closeSubpath()
    }
  }
  var recess: Path {
    Path { path in
      path.move(to: upper)
      path.addLine(to: outer)
      path.addLine(to: foot)
      path.addQuadCurve(to: lower, control: lowerJoin)
      path.addQuadCurve(to: upper, control: roll)
      path.closeSubpath()
    }
  }
}

struct CurlCorner: View {
  let geometry: MapFoldGeometry

  var body: some View {
    Canvas { context, size in
      let scale = geometry.scale
      let tip = geometry.tip
      let upper = geometry.upper
      let lower = geometry.lower
      let roll = geometry.roll
      let recess = geometry.recess
      context.fill(
        recess,
        with: .linearGradient(
          Gradient(colors: [
            Color(red: 0.20, green: 0.21, blue: 0.24),
            Color(red: 0.15, green: 0.16, blue: 0.18),
          ]), startPoint: upper, endPoint: geometry.outer))
      var backing = context
      backing.clip(to: recess)
      for y in stride(from: 0.0, to: size.height, by: 1.3 * scale) {
        backing.fill(
          Path(CGRect(x: 0, y: y, width: size.width, height: 0.3 * scale)),
          with: .color(.black.opacity(0.025)))
      }
      if geometry.roundedDisplay {
        backing.fill(
          Path(CGRect(origin: .zero, size: size)),
          with: .linearGradient(
            Gradient(colors: [.clear, .black.opacity(0.64)]),
            startPoint: lower, endPoint: geometry.foot))
      }
      var rolledEdge = Path()
      rolledEdge.move(to: upper)
      rolledEdge.addQuadCurve(to: lower, control: roll)
      var contact = backing
      contact.addFilter(.blur(radius: 1.1 * scale))
      contact.stroke(rolledEdge, with: .color(.black.opacity(0.5)), lineWidth: 2 * scale)

      let paper = geometry.paper
      var shadow = context
      shadow.addFilter(
        .shadow(color: .black.opacity(0.33), radius: 2.3 * scale, x: -0.6 * scale, y: 1.4 * scale))
      shadow.fill(paper, with: .color(.black))
      var surface = context
      surface.clip(to: paper)
      // Follow the rolled edge instead of projecting one flat gradient across the paper.
      for band in 0..<160 {
        let start = CGFloat(band) / 160
        let end = CGFloat(band + 1) / 160
        let t = (start + end) / 2
        let curve = { (t: CGFloat) in
          let a: CGFloat = (1 - t) * (1 - t)
          let b: CGFloat = 2 * (1 - t) * t
          let c: CGFloat = t * t
          return CGPoint(
            x: a * upper.x + b * roll.x + c * lower.x,
            y: a * upper.y + b * roll.y + c * lower.y)
        }
        let y0 = curve(start).y
        let y1 = curve(end).y
        let right = curve(t)
        let left: CGFloat
        let referenceY: CGFloat
        if right.y <= tip.y {
          let fraction = (right.y - upper.y) / (tip.y - upper.y)
          left = upper.x + (tip.x - upper.x) * fraction
          referenceY = 25.5 * fraction
        } else {
          let fraction = (right.y - tip.y) / (lower.y - tip.y)
          left = tip.x + (lower.x - tip.x) * fraction
          referenceY = 25.5 + 14.5 * fraction
        }
        surface.fill(
          Path(CGRect(x: 0, y: y0, width: size.width, height: y1 - y0 + 0.5)),
          with: .linearGradient(
            paperLighting(at: referenceY),
            startPoint: CGPoint(x: left, y: right.y), endPoint: right))
      }
      var edge = Path()
      edge.move(to: lower)
      edge.addLine(to: tip)
      edge.addLine(to: upper)
      context.stroke(
        edge,
        with: .linearGradient(
          Gradient(colors: [.white.opacity(0.8), .white.opacity(0.15)]),
          startPoint: tip, endPoint: lower), lineWidth: 0.45 * scale)
    }
    .frame(width: MapFoldGeometry.canvasSize.width, height: MapFoldGeometry.canvasSize.height)
    .fixedSize()
    .frame(width: 64, height: 80, alignment: .bottomTrailing)
    .accessibilityHidden(true)
  }

  private func paperLighting(at y: CGFloat) -> Gradient {
    let falloff = pow(max(0, (Double(y) - 25.5) / 14.5), 0.85)
    let positions: [CGFloat] = [0, 0.18, 0.42, 0.68, 0.90, 1]
    let highlight: [(Double, Double, Double)] = [
      (0.98, 0.985, 0.99), (0.94, 0.95, 0.96), (0.85, 0.87, 0.89),
      (0.74, 0.76, 0.79), (0.61, 0.64, 0.68), (0.38, 0.41, 0.46),
    ]
    let underside: [(Double, Double, Double)] = [
      (0.50, 0.52, 0.54), (0.56, 0.58, 0.60), (0.60, 0.62, 0.64),
      (0.54, 0.56, 0.59), (0.45, 0.47, 0.51), (0.37, 0.39, 0.43),
    ]
    return Gradient(
      stops: positions.indices.map { index in
        let a = highlight[index]
        let b = underside[index]
        return .init(
          color: Color(
            red: a.0 + (b.0 - a.0) * falloff,
            green: a.1 + (b.1 - a.1) * falloff,
            blue: a.2 + (b.2 - a.2) * falloff), location: positions[index])
      })
  }

}
