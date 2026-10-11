import SwiftUI

struct WalnutBackground: View {
  var body: some View {
    GeometryReader { geometry in
      Image("Walnut")
        .resizable()
        .scaledToFill()
        .frame(width: geometry.size.width, height: geometry.size.height)
        .clipped()
        .overlay {
          LinearGradient(
            colors: [.black.opacity(0.12), .clear, .black.opacity(0.2)],
            startPoint: .top, endPoint: .bottom)
        }
        .overlay {
          RadialGradient(
            colors: [.clear, .black.opacity(0.3)], center: .init(x: 0.4, y: 0.38),
            startRadius: geometry.size.width * 0.3,
            endRadius: max(geometry.size.width, geometry.size.height) * 0.85)
        }
    }
    .ignoresSafeArea()
    .accessibilityHidden(true)
  }
}

struct CompassDial: View {
  let angle: Double
  let available: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    GeometryReader { geometry in
      let size = min(geometry.size.width, geometry.size.height)
      ZStack {
        Circle().fill(.black)
          .shadow(color: .black.opacity(0.8), radius: 6, y: 7)
          .shadow(color: .black.opacity(0.5), radius: 1.5, y: 2)
        brassBezel(size: size)
        Circle()
          .stroke(
            LinearGradient(
              colors: [
                Color(red: 0.09, green: 0.06, blue: 0.035),
                Color(red: 0.86, green: 0.79, blue: 0.57),
              ],
              startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: size * 0.014
          ).padding(size * 0.071)
        Circle()
          .fill(
            RadialGradient(
              colors: [
                Color(red: 1, green: 0.95, blue: 0.84),
                Color(red: 0.96, green: 0.88, blue: 0.72),
                Color(red: 0.79, green: 0.69, blue: 0.5),
              ],
              center: .init(x: 0.42, y: 0.35), startRadius: size * 0.05, endRadius: size * 0.48)
          )
          .padding(size * 0.087)
        enamelGrain.padding(size * 0.087).clipShape(Circle())
        dialCard
          .padding(size * 0.087)
          .rotationEffect(.degrees(-angle))
          .animation(reduceMotion ? nil : .linear(duration: 0.18), value: angle)
          .clipShape(Circle())
          .opacity(available ? 1 : 0.55)
        Circle()
          .fill(
            RadialGradient(
              stops: [
                .init(color: .clear, location: 0),
                .init(color: .clear, location: 0.88),
                .init(color: .black.opacity(0.28), location: 1),
              ], center: .center, startRadius: 0, endRadius: size * 0.414)
          )
          .padding(size * 0.087)
          .allowsHitTesting(false)
        glassReflection.padding(size * 0.087).clipShape(Circle())
        Circle()
          .stroke(
            LinearGradient(
              colors: [.black.opacity(0.8), .white.opacity(0.65)],
              startPoint: .top, endPoint: .bottom), lineWidth: 1.4
          )
          .padding(size * 0.083)
        Circle()
          .fill(
            RadialGradient(
              colors: [
                Color(red: 1, green: 0.94, blue: 0.69),
                Color(red: 0.79, green: 0.6, blue: 0.27),
                Color(red: 0.36, green: 0.22, blue: 0.08),
              ], center: .init(x: 0.3, y: 0.25), startRadius: 0, endRadius: size * 0.115)
          )
          .overlay {
            Circle().stroke(
              LinearGradient(
                colors: [.white.opacity(0.85), .black.opacity(0.85)],
                startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2)
          }
          .overlay { Circle().stroke(.black.opacity(0.18), lineWidth: 0.5).padding(2) }
          .frame(width: size * 0.115, height: size * 0.115)
          .shadow(color: .black.opacity(0.55), radius: 1.5, y: 2)
        Circle().fill(Color(red: 0.045, green: 0.03, blue: 0.015))
          .overlay {
            Circle().stroke(
              LinearGradient(
                colors: [.black, .white.opacity(0.6)],
                startPoint: .top, endPoint: .bottom), lineWidth: 0.8)
          }
          .frame(width: size * 0.021, height: size * 0.021)
      }
      .frame(width: size, height: size)
      .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
    }
    .accessibilityHidden(true)
  }

  private func brassBezel(size: CGFloat) -> some View {
    Circle()
      .fill(
        AngularGradient(
          stops: [
            .init(color: Color(red: 0.31, green: 0.2, blue: 0.07), location: 0),
            .init(color: Color(red: 0.76, green: 0.64, blue: 0.36), location: 0.12),
            .init(color: Color(red: 0.97, green: 0.92, blue: 0.69), location: 0.2),
            .init(color: Color(red: 0.53, green: 0.39, blue: 0.17), location: 0.32),
            .init(color: Color(red: 0.17, green: 0.105, blue: 0.04), location: 0.46),
            .init(color: Color(red: 0.58, green: 0.46, blue: 0.23), location: 0.56),
            .init(color: Color(red: 1, green: 0.96, blue: 0.77), location: 0.68),
            .init(color: Color(red: 0.88, green: 0.77, blue: 0.47), location: 0.77),
            .init(color: Color(red: 0.36, green: 0.25, blue: 0.1), location: 0.91),
            .init(color: Color(red: 0.31, green: 0.2, blue: 0.07), location: 1),
          ], center: .center)
      )
      .overlay {
        Circle().fill(
          RadialGradient(
            stops: [
              .init(color: .clear, location: 0.86),
              .init(color: .black.opacity(0.48), location: 0.88),
              .init(color: .clear, location: 0.905),
              .init(color: .white.opacity(0.16), location: 0.935),
              .init(color: .clear, location: 0.962),
              .init(color: .black.opacity(0.36), location: 0.99),
              .init(color: .black.opacity(0.7), location: 1),
            ], center: .center, startRadius: 0, endRadius: size * 0.5))
      }
      .overlay {
        Circle().stroke(
          LinearGradient(
            colors: [.white.opacity(0.8), .black.opacity(0.75)],
            startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: size * 0.006
        )
        .padding(size * 0.004)
      }
      .overlay {
        Canvas { context, dimensions in
          let center = CGPoint(x: dimensions.width / 2, y: dimensions.height / 2)
          for index in 0..<42 {
            let radius = size * (0.487 - Double(index) * 0.0013)
            let rect = CGRect(
              x: center.x - radius, y: center.y - radius,
              width: radius * 2, height: radius * 2)
            let brightness = sin(Double(index) * 2.37)
            context.stroke(
              Path(ellipseIn: rect),
              with: .color(
                brightness > 0
                  ? .white.opacity(brightness * 0.12)
                  : .black.opacity(-brightness * 0.16)), lineWidth: 0.35)
          }
        }
      }
      .overlay {
        Circle().stroke(
          LinearGradient(
            colors: [.black.opacity(0.7), .white.opacity(0.8)],
            startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: size * 0.009
        )
        .padding(size * 0.06)
      }
  }

  private var enamelGrain: some View {
    Canvas { context, size in
      for index in 0..<2400 {
        let x = Double((index * 73 + 19) % 2411) / 2411 * size.width
        let y = Double((index * 151 + 7) % 2417) / 2417 * size.height
        let diameter = index % 3 == 0 ? 0.65 : 0.35
        context.fill(
          Path(ellipseIn: CGRect(x: x, y: y, width: diameter, height: diameter)),
          with: .color(index % 2 == 0 ? .black.opacity(0.065) : .white.opacity(0.18)))
      }
    }
    .allowsHitTesting(false)
  }

  private var glassReflection: some View {
    Canvas { context, size in
      var reflection = Path()
      reflection.move(to: CGPoint(x: 0, y: size.height * 0.26))
      reflection.addCurve(
        to: CGPoint(x: size.width, y: size.height * 0.42),
        control1: CGPoint(x: size.width * 0.22, y: -size.height * 0.12),
        control2: CGPoint(x: size.width * 0.73, y: size.height * 0.09))
      reflection.addLine(to: CGPoint(x: size.width, y: 0))
      reflection.addLine(to: .zero)
      reflection.closeSubpath()
      context.fill(
        reflection,
        with: .linearGradient(
          Gradient(colors: [.white.opacity(0.18), .white.opacity(0.015)]),
          startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height * 0.45)))
    }
    .allowsHitTesting(false)
  }

  private var dialCard: some View {
    Canvas { context, size in
      let center = CGPoint(x: size.width / 2, y: size.height / 2)
      let radius = size.width / 2
      let ink = Color(red: 0.075, green: 0.05, blue: 0.025)
      for fraction in [0.99, 0.94, 0.82] {
        let rect = CGRect(
          x: center.x - radius * fraction, y: center.y - radius * fraction,
          width: radius * 2 * fraction, height: radius * 2 * fraction)
        context.stroke(Path(ellipseIn: rect), with: .color(ink.opacity(0.6)), lineWidth: 0.7)
      }
      for degrees in stride(from: 0, to: 360, by: 2) {
        let major = degrees % 10 == 0
        let theta = Double(degrees) * .pi / 180
        let outer = radius * 0.985
        let inner = radius * (major ? 0.935 : 0.956)
        var tick = Path()
        tick.move(to: point(center, radius: inner, theta: theta))
        tick.addLine(to: point(center, radius: outer, theta: theta))
        context.stroke(tick, with: .color(ink), lineWidth: major ? 1 : 0.5)
        if major {
          var rotated = context
          rotated.translateBy(x: center.x, y: center.y)
          rotated.rotate(by: .degrees(Double(degrees)))
          rotated.draw(
            Text("\(degrees)").font(.custom("TimesNewRomanPSMT", fixedSize: radius * 0.076))
              .foregroundColor(ink), at: CGPoint(x: 0, y: -radius * 0.877))
        }
      }
      for index in 0..<8 {
        let theta = Double(index) * .pi / 4
        let long = index % 2 == 0
        let length = radius * (long ? 0.61 : 0.47)
        let tip = point(center, radius: length, theta: theta)
        let left = point(center, radius: radius * 0.105, theta: theta - .pi / 2)
        let right = point(center, radius: radius * 0.105, theta: theta + .pi / 2)
        var dark = Path()
        dark.move(to: center)
        dark.addLine(to: left)
        dark.addLine(to: tip)
        dark.closeSubpath()
        context.fill(
          dark,
          with: .linearGradient(
            Gradient(colors: [ink, Color(red: 0.22, green: 0.17, blue: 0.1)]),
            startPoint: tip, endPoint: center))
        var light = Path()
        light.move(to: center)
        light.addLine(to: right)
        light.addLine(to: tip)
        light.closeSubpath()
        context.fill(
          light,
          with: .linearGradient(
            Gradient(colors: [
              Color(red: 0.91, green: 0.81, blue: 0.6),
              Color(red: 0.52, green: 0.4, blue: 0.23),
            ]), startPoint: tip, endPoint: center))
        context.stroke(light, with: .color(ink), lineWidth: 0.5)
      }
      let labels = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
      for index in 0..<8 {
        var rotated = context
        rotated.translateBy(x: center.x, y: center.y)
        rotated.rotate(by: .degrees(Double(index) * 45))
        if index == 0 {
          var triangle = Path()
          triangle.move(to: CGPoint(x: 0, y: -radius * 0.81))
          triangle.addLine(to: CGPoint(x: -radius * 0.106, y: -radius * 0.64))
          triangle.addLine(to: CGPoint(x: radius * 0.106, y: -radius * 0.64))
          triangle.closeSubpath()
          rotated.fill(
            triangle,
            with: .linearGradient(
              Gradient(colors: [
                Color(red: 0.94, green: 0.12, blue: 0.08),
                Color(red: 0.53, green: 0, blue: 0),
              ]), startPoint: CGPoint(x: 0, y: -radius * 0.81),
              endPoint: CGPoint(x: 0, y: -radius * 0.64)))
          rotated.draw(
            Text(L10n.text("N")).font(.custom("TimesNewRomanPS-BoldMT", fixedSize: radius * 0.13))
              .foregroundColor(.white), at: CGPoint(x: 0, y: -radius * 0.695))
        } else {
          rotated.draw(
            Text(L10n.text(labels[index]))
              .font(
                .custom(
                  "TimesNewRomanPS-BoldMT", fixedSize: radius * (index % 2 == 0 ? 0.155 : 0.107))
              )
              .foregroundColor(ink), at: CGPoint(x: 0, y: -radius * 0.718))
        }
      }
    }
  }

  private func point(_ center: CGPoint, radius: Double, theta: Double) -> CGPoint {
    CGPoint(x: center.x + sin(theta) * radius, y: center.y - cos(theta) * radius)
  }
}

struct ClassicButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundColor(.white)
      .shadow(color: .black, radius: 0.5, y: -1)
      .padding(.horizontal, 10).frame(minWidth: 44, minHeight: 44)
      .background {
        RoundedRectangle(cornerRadius: 5)
          .fill(
            LinearGradient(
              colors: configuration.isPressed
                ? [Color(white: 0.14), Color(white: 0.06)]
                : [Color(white: 0.44), Color(white: 0.18), Color(white: 0.08)],
              startPoint: .top, endPoint: .bottom)
          )
          .overlay { RoundedRectangle(cornerRadius: 5).stroke(.black.opacity(0.85), lineWidth: 1) }
          .overlay {
            RoundedRectangle(cornerRadius: 5).stroke(.white.opacity(0.3), lineWidth: 0.5).padding(1)
          }
          .padding(.vertical, 7)
      }
      .contentShape(Rectangle())
  }
}

struct CompassToolbar: View {
  var body: some View {
    LinearGradient(
      stops: [
        .init(color: Color(white: 0.4), location: 0),
        .init(color: Color(white: 0.15), location: 0.48),
        .init(color: .black, location: 0.51), .init(color: Color(white: 0.07), location: 1),
      ],
      startPoint: .top, endPoint: .bottom
    )
    .overlay(alignment: .top) { Color.white.opacity(0.4).frame(height: 1) }
  }
}

struct HeadingOrientationReader: UIViewRepresentable {
  let changed: (UIInterfaceOrientation) -> Void

  func makeUIView(context: Context) -> OrientationView {
    let view = OrientationView()
    view.changed = changed
    return view
  }
  func updateUIView(_ view: OrientationView, context: Context) { view.changed = changed }

  final class OrientationView: UIView {
    var changed: ((UIInterfaceOrientation) -> Void)?
    private var reported = UIInterfaceOrientation.unknown
    override func layoutSubviews() {
      super.layoutSubviews()
      guard let orientation = window?.windowScene?.interfaceOrientation,
        orientation != reported
      else { return }
      reported = orientation
      DispatchQueue.main.async { [weak self] in self?.changed?(orientation) }
    }
  }
}
