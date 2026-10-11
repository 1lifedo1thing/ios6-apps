import SwiftUI

struct StopwatchView: View {
  let store: ClockStore
  var body: some View {
    GeometryReader { geometry in
      let landscape = geometry.size.width > geometry.size.height
      if landscape {
        HStack(spacing: 0) {
          instrument.frame(maxWidth: .infinity)
          lapList.frame(maxWidth: .infinity)
        }
      } else {
        VStack(spacing: 0) {
          instrument
          lapList
        }
      }
    }
  }
  private var instrument: some View {
    TimelineView(.periodic(from: .now, by: 0.1)) { timeline in
      VStack(spacing: 0) {
        Text(ClockFormat.stopwatch(store.stopwatch.currentLap(at: timeline.date)))
          .font(ClockTheme.font(29, bold: true)).monospacedDigit().foregroundStyle(
            Color(hex: 0xD5D5D5)
          )
          .shadow(color: .black, radius: 0, y: -1)
          .frame(maxWidth: .infinity, alignment: .trailing).padding(.trailing, 40).frame(height: 65)
          .background {
            LinearGradient(
              colors: [Color(hex: 0x8E8E8E), .black], startPoint: .top, endPoint: .bottom)
          }
          .accessibilityLabel(L10n.text("Current lap"))
        Text(ClockFormat.stopwatch(store.stopwatch.elapsed(at: timeline.date)))
          .font(.custom("HelveticaNeue-Light", size: 76)).monospacedDigit().foregroundStyle(.white)
          .lineLimit(1).minimumScaleFactor(0.4).padding(.horizontal, 12).frame(maxWidth: .infinity)
          .frame(height: 85)
          .accessibilityLabel(L10n.text("Elapsed time"))
          .accessibilityValue(ClockFormat.stopwatch(store.stopwatch.elapsed(at: timeline.date)))
          .accessibilityIdentifier("stopwatch-display")
        HStack(spacing: 24) {
          Button(L10n.text(store.stopwatch.running ? "Stop" : "Start")) { store.toggleStopwatch() }
            .buttonStyle(GlossyButtonStyle(tint: store.stopwatch.running ? .red : .green))
            .accessibilityIdentifier("stopwatch-start")
          Button(L10n.text(store.stopwatch.running ? "Lap" : "Reset")) { store.lapOrReset() }
            .buttonStyle(GlossyButtonStyle()).disabled(
              !store.stopwatch.running && store.stopwatch.accumulated == 0
            )
            .accessibilityIdentifier("stopwatch-lap")
        }.padding(.horizontal, 25).padding(.top, 14).padding(.bottom, 32)
      }.background(.black)
    }
  }
  private var lapList: some View {
    let laps = store.stopwatch.laps
    return GeometryReader { geometry in
      ScrollView {
        LazyVStack(spacing: 0) {
          ForEach(Array(laps.enumerated().reversed()), id: \.offset) { lap in
            HStack {
              Text(L10n.text("Lap") + " \(lap.offset + 1)").font(ClockTheme.font(20, bold: true))
              Spacer()
              Text(ClockFormat.stopwatch(lap.element)).font(ClockTheme.font(25)).monospacedDigit()
            }.foregroundStyle(.black).padding(.horizontal, 22).frame(height: 50)
              .background(ClockTheme.row).overlay(alignment: .bottom) { SilverSeparator() }
              .accessibilityElement(children: .combine)
              .accessibilityIdentifier("lap-\(lap.offset + 1)")
          }
        }.frame(minHeight: geometry.size.height, alignment: .top)
      }.accessibilityIdentifier("lap-list")
        .background {
          Canvas { context, size in
            for y in stride(from: 0.0, through: size.height, by: 50) {
              let rect = CGRect(x: 0, y: y, width: size.width, height: 50)
              context.fill(
                Path(rect),
                with: .linearGradient(
                  Gradient(colors: [Color(hex: 0xE0E0E2), Color(hex: 0xB5B5BC)]),
                  startPoint: CGPoint(x: 0, y: y), endPoint: CGPoint(x: 0, y: y + 50)))
              context.fill(
                Path(CGRect(x: 0, y: y + 49, width: size.width, height: 1)),
                with: .color(.white.opacity(0.7)))
            }
          }.accessibilityHidden(true)
        }
    }
  }
}
