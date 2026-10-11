import SwiftUI

struct AnalogClock: View {
  let date: Date
  let zone: TimeZone
  var body: some View {
    let hour = calendar.component(.hour, from: date)
    let night = hour < 6 || hour >= 18
    GeometryReader { geometry in
      let side = min(geometry.size.width, geometry.size.height)
      ZStack {
        Circle().fill(
          LinearGradient(
            colors: night ? [Color(hex: 0x292B30), .black] : [.white, Color(hex: 0xDDDDDB)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .overlay { Circle().stroke(night ? .black : Color(hex: 0xACACAC), lineWidth: 1) }
        .shadow(color: .white.opacity(0.5), radius: 0, y: 1)
        ForEach(1...12, id: \.self) { index in
          let angle = Double(index) * .pi / 6
          Text(String(index)).font(.custom("HelveticaNeue", size: side * 0.125))
            .foregroundStyle(night ? .white : .black)
            .position(
              x: side / 2 + sin(angle) * side * 0.37,
              y: side / 2 - cos(angle) * side * 0.37)
        }
        Canvas { context, size in
          let center = CGPoint(x: size.width / 2, y: size.height / 2)
          let minute = Double(calendar.component(.minute, from: date))
          let second = Double(calendar.component(.second, from: date))
          func hand(
            _ angle: Double, length: Double, width: Double, color: Color, tail: Double = 0.07
          ) {
            let radians = angle * .pi / 180
            var path = Path()
            path.move(
              to: CGPoint(
                x: center.x - sin(radians) * side * tail, y: center.y + cos(radians) * side * tail))
            path.addLine(
              to: CGPoint(
                x: center.x + sin(radians) * side * length,
                y: center.y - cos(radians) * side * length))
            context.stroke(
              path, with: .color(color),
              style: StrokeStyle(lineWidth: side * width, lineCap: .round))
          }
          hand(
            Double(hour % 12) * 30 + minute / 2, length: 0.23, width: 0.045,
            color: night ? .white : .black)
          hand(minute * 6 + second / 10, length: 0.32, width: 0.025, color: night ? .white : .black)
          hand(second * 6, length: 0.36, width: 0.012, color: Color(hex: 0xB92527), tail: 0.12)
          context.fill(
            Path(ellipseIn: CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)),
            with: .color(Color(hex: 0xB92527)))
        }
      }.frame(width: side, height: side)
    }.dynamicTypeSize(.medium).accessibilityHidden(true)
  }
  private var calendar: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = zone
    return c
  }
}

struct WorldMapArtwork: View {
  var body: some View {
    Canvas { context, size in
      // Original simplified silhouettes, normalized to a 360 by 180 map.
      let continents: [[CGPoint]] = [
        [
          CGPoint(x: 18, y: 30), CGPoint(x: 42, y: 20), CGPoint(x: 60, y: 12),
          CGPoint(x: 79, y: 24), CGPoint(x: 94, y: 22), CGPoint(x: 106, y: 36),
          CGPoint(x: 95, y: 52), CGPoint(x: 76, y: 57), CGPoint(x: 68, y: 72),
          CGPoint(x: 86, y: 88), CGPoint(x: 104, y: 96), CGPoint(x: 89, y: 100),
          CGPoint(x: 71, y: 89), CGPoint(x: 54, y: 64), CGPoint(x: 35, y: 59),
          CGPoint(x: 28, y: 46),
        ],
        [
          CGPoint(x: 97, y: 98), CGPoint(x: 114, y: 98), CGPoint(x: 135, y: 112),
          CGPoint(x: 128, y: 132), CGPoint(x: 115, y: 145), CGPoint(x: 109, y: 171),
          CGPoint(x: 101, y: 157), CGPoint(x: 100, y: 134), CGPoint(x: 91, y: 114),
        ],
        [
          CGPoint(x: 117, y: 13), CGPoint(x: 149, y: 9), CGPoint(x: 145, y: 35),
          CGPoint(x: 128, y: 42), CGPoint(x: 117, y: 30),
        ],
        [
          CGPoint(x: 167, y: 53), CGPoint(x: 171, y: 39), CGPoint(x: 186, y: 35),
          CGPoint(x: 194, y: 20), CGPoint(x: 206, y: 26), CGPoint(x: 221, y: 18),
          CGPoint(x: 257, y: 20), CGPoint(x: 276, y: 15), CGPoint(x: 319, y: 26),
          CGPoint(x: 341, y: 38), CGPoint(x: 325, y: 49), CGPoint(x: 298, y: 45),
          CGPoint(x: 313, y: 59), CGPoint(x: 289, y: 70), CGPoint(x: 277, y: 94),
          CGPoint(x: 268, y: 103), CGPoint(x: 251, y: 85), CGPoint(x: 236, y: 103),
          CGPoint(x: 226, y: 82), CGPoint(x: 208, y: 76), CGPoint(x: 197, y: 62),
          CGPoint(x: 183, y: 59),
        ],
        [
          CGPoint(x: 174, y: 69), CGPoint(x: 196, y: 66), CGPoint(x: 208, y: 85),
          CGPoint(x: 221, y: 95), CGPoint(x: 214, y: 107), CGPoint(x: 203, y: 117),
          CGPoint(x: 194, y: 141), CGPoint(x: 181, y: 143), CGPoint(x: 173, y: 119),
          CGPoint(x: 160, y: 95), CGPoint(x: 163, y: 79),
        ],
        [
          CGPoint(x: 285, y: 123), CGPoint(x: 312, y: 115), CGPoint(x: 327, y: 132),
          CGPoint(x: 323, y: 149), CGPoint(x: 306, y: 153), CGPoint(x: 283, y: 142),
        ],
        [
          CGPoint(x: 333, y: 151), CGPoint(x: 342, y: 140), CGPoint(x: 345, y: 145),
          CGPoint(x: 339, y: 160),
        ],
      ]
      let scale = min(size.width / 360, size.height / 180)
      for points in continents {
        var path = Path()
        for (index, point) in points.enumerated() {
          let p = CGPoint(
            x: point.x * scale + (size.width - 360 * scale) / 2,
            y: point.y * scale + (size.height - 180 * scale) / 2)
          if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        context.fill(path, with: .color(.white.opacity(0.14)))
      }
    }.accessibilityHidden(true)
  }
}

struct ClockTabIcon: View {
  var tab: ClockTab
  var selected: Bool
  var body: some View {
    Canvas { context, size in
      let color = selected ? Color(hex: 0x80C5FF) : Color(hex: 0x999999)
      let center = CGPoint(x: size.width / 2, y: size.height / 2 + 1)
      let radius = 12.0
      var ring = Path(
        ellipseIn: CGRect(
          x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
      if tab == .world {
        ring.addEllipse(
          in: CGRect(x: center.x - 5, y: center.y - radius, width: 10, height: radius * 2))
        for y in [-6.0, 0, 6] {
          ring.move(to: CGPoint(x: center.x - 11, y: center.y + y))
          ring.addLine(to: CGPoint(x: center.x + 11, y: center.y + y))
        }
      } else {
        ring.move(to: center)
        ring.addLine(to: CGPoint(x: center.x, y: center.y - 8))
        if tab == .alarm {
          ring.move(to: center)
          ring.addLine(to: CGPoint(x: center.x - 6, y: center.y))
        }
        if tab == .timer {
          ring.move(to: CGPoint(x: center.x - 6, y: center.y - 7))
          ring.addLine(to: CGPoint(x: center.x + 5, y: center.y + 6))
        }
        if tab == .stopwatch {
          ring.move(to: CGPoint(x: center.x, y: center.y - 16))
          ring.addLine(to: CGPoint(x: center.x, y: center.y - 12))
        }
        if tab == .alarm {
          ring.addArc(
            center: CGPoint(x: center.x - 7, y: center.y - 10), radius: 6,
            startAngle: .degrees(200), endAngle: .degrees(290), clockwise: false)
          ring.addArc(
            center: CGPoint(x: center.x + 7, y: center.y - 10), radius: 6,
            startAngle: .degrees(250), endAngle: .degrees(340), clockwise: false)
        }
      }
      context.stroke(ring, with: .color(color), style: StrokeStyle(lineWidth: 2.3, lineCap: .round))
    }.frame(width: 34, height: 32).accessibilityHidden(true)
  }
}
