import SwiftUI

// Eight curved leaves share their boundaries, so the iris never exposes gaps between blades.
struct IrisGeometry {
  static let bladeCount = 8
  let size: CGSize
  let closure: Double

  private var center: CGPoint { CGPoint(x: size.width / 2, y: size.height / 2) }
  private var diagonal: CGFloat { hypot(size.width, size.height) / 2 }
  private var outerRadius: CGFloat { diagonal * 1.6 }
  private var aperture: CGFloat {
    diagonal * 1.18 * CGFloat(pow(1 - min(1, max(0, closure)), 1.15))
  }
  private var step: Double { .pi / 4 }
  private var rotation: Double { -.pi / 2 + 0.14 + (1 - closure) * 0.20 }

  private func point(_ radius: CGFloat, _ angle: Double) -> CGPoint {
    CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
  }

  private func seamPoints(_ index: Int) -> (CGPoint, CGPoint, CGPoint, CGPoint) {
    let angle = rotation + Double(index) * step
    let travel = outerRadius - aperture
    return (
      point(aperture, angle),
      point(aperture + travel * 0.26, angle - 0.62 * closure),
      point(aperture + travel * 0.70, angle - 0.47 * closure),
      point(outerRadius, angle - 0.20)
    )
  }

  func blade(_ index: Int) -> Path {
    let a = seamPoints(index)
    let b = seamPoints(index + 1)
    let angle = rotation + Double(index) * step
    return Path { path in
      path.move(to: a.0)
      path.addCurve(to: a.3, control1: a.1, control2: a.2)
      path.addArc(
        center: center, radius: outerRadius,
        startAngle: .radians(angle - 0.20), endAngle: .radians(angle + step - 0.20),
        clockwise: false)
      path.addCurve(to: b.0, control1: b.2, control2: b.1)
      path.addQuadCurve(
        to: a.0, control: point(aperture * 1.04, angle + step / 2))
      path.closeSubpath()
    }
  }

  func seam(_ index: Int) -> Path {
    let points = seamPoints(index)
    return Path { path in
      path.move(to: points.0)
      path.addCurve(to: points.3, control1: points.1, control2: points.2)
    }
  }
}

struct IrisShutter: View, Animatable {
  var closure: Double
  var animatableData: Double {
    get { closure }
    set { closure = newValue }
  }

  var body: some View {
    Canvas { context, size in
      let iris = IrisGeometry(size: size, closure: closure)
      for index in 0..<IrisGeometry.bladeCount {
        let variation = Double(index % 3 - 1) * 0.006
        context.fill(
          iris.blade(index),
          with: .linearGradient(
            Gradient(stops: [
              .init(color: Color(white: 0.245 + variation), location: 0),
              .init(color: Color(white: 0.170 + variation), location: 0.45),
              .init(color: Color(white: 0.065 + variation), location: 1),
            ]), startPoint: .zero, endPoint: CGPoint(x: size.width * 0.12, y: size.height)))
      }
      // A cached bitmap keeps the fine material grain stable and cheap to draw.
      context.drawLayer { grain in
        let mask = (0..<IrisGeometry.bladeCount).reduce(into: Path()) { $0.addPath(iris.blade($1)) }
        grain.clip(to: mask)
        grain.draw(Image("IrisGrain"), in: CGRect(origin: .zero, size: size))
      }
      for index in 0..<IrisGeometry.bladeCount {
        let seam = iris.seam(index)
        context.drawLayer { shadow in
          shadow.addFilter(.shadow(color: .black.opacity(0.58), radius: 1.3, x: 0.7, y: 0.7))
          shadow.stroke(seam, with: .color(.black.opacity(0.56)), lineWidth: 0.9)
        }
        var highlight = context
        highlight.translateBy(x: -0.4, y: -0.4)
        highlight.stroke(seam, with: .color(.white.opacity(0.08)), lineWidth: 0.45)
      }
    }
    .clipped()
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

// Both faces stay upright; the replacement face appears only at the edge of the turn.
struct CameraTurn: ViewModifier, Animatable {
  var degrees: Double
  var animatableData: Double {
    get { degrees }
    set { degrees = newValue }
  }

  func body(content: Content) -> some View {
    let face = degrees <= 90 ? degrees : degrees - 180
    content
      .overlay {
        Color.black.opacity(0.16 * abs(sin(degrees * .pi / 180))).allowsHitTesting(false)
      }
      .rotation3DEffect(.degrees(face), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
  }
}
