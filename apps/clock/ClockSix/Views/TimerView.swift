import SwiftUI

struct TimerView: View {
  let store: ClockStore
  var onSoundPresentation: (Bool) -> Void = { _ in }
  @State private var soundSelection = false
  @Environment(\.openURL) private var openURL

  var body: some View {
    let countdown = store.countdown
    ZStack {
      if soundSelection {
        SoundSelectionView(
          sound: Binding(
            get: { store.countdown.sound },
            set: {
              store.countdown.sound = $0
              store.save()
            }), timer: true
        ) {
          soundSelection = false
        }.preferredColorScheme(.light).accessibilityAddTraits(.isModal)
      } else {
        GeometryReader { geometry in
          if geometry.size.width > geometry.size.height {
            HStack(spacing: 20) {
              instrument(countdown).frame(maxWidth: .infinity)
              VStack(spacing: 20) {
                soundRow(countdown)
                controls(countdown)
                permissionNotice
              }
              .frame(maxWidth: .infinity)
            }.padding(.horizontal, 15).frame(maxHeight: .infinity)
          } else {
            VStack(spacing: 25) {
              instrument(countdown).padding(.top, 20)
              soundRow(countdown).padding(.horizontal, 15)
              controls(countdown).padding(.horizontal, 25)
              permissionNotice
              Spacer(minLength: 0)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
          }
        }
      }
    }
    .onChange(of: soundSelection) { _, value in onSoundPresentation(value) }
    .onDisappear { onSoundPresentation(false) }
  }
  @ViewBuilder private func instrument(_ countdown: CountdownState) -> some View {
    if countdown.active {
      TimelineView(.periodic(from: .now, by: 0.2)) { timeline in
        Text(ClockFormat.countdown(store.countdown.seconds(at: timeline.date)))
          .font(.custom("HelveticaNeue-Light", size: 69)).foregroundStyle(.white).monospacedDigit()
          .lineLimit(1).minimumScaleFactor(0.4).frame(maxWidth: .infinity).frame(height: 180)
          .accessibilityLabel(L10n.text("Time remaining"))
          .accessibilityValue(ClockFormat.countdown(store.countdown.seconds(at: timeline.date)))
          .accessibilityIdentifier("timer-display")
      }
    } else {
      ClassicTimePicker(hour: hourBinding, minute: minuteBinding, duration: true)
    }
  }
  private func soundRow(_ countdown: CountdownState) -> some View {
    Button {
      soundSelection = true
    } label: {
      HStack {
        Text(L10n.text("When Timer Ends")).font(ClockTheme.font(17, bold: true))
        Spacer(minLength: 6)
        Text(L10n.text(countdown.sound.rawValue)).font(ClockTheme.font(17))
        Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold))
      }.foregroundStyle(.black).padding(.horizontal, 14).frame(minHeight: 48)
        .background(ClockTheme.row).clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.4), lineWidth: 1) }
    }.buttonStyle(.plain).accessibilityIdentifier("timer-sound").disabled(countdown.active)
      .dynamicTypeSize(.small ... .xxxLarge)
  }
  @ViewBuilder private func controls(_ countdown: CountdownState) -> some View {
    if countdown.active {
      HStack(spacing: 24) {
        Button(L10n.text("Cancel")) { store.cancelTimer() }
          .buttonStyle(GlossyButtonStyle(tint: .red)).accessibilityIdentifier("timer-cancel")
        Button(L10n.text(countdown.running ? "Pause" : "Resume")) { store.toggleTimer() }
          .buttonStyle(GlossyButtonStyle(tint: countdown.running ? .gray : .green))
          .disabled(countdown.remaining <= 0).accessibilityIdentifier("timer-start")
      }
    } else {
      Button(L10n.text("Start")) { store.toggleTimer() }
        .buttonStyle(GlossyButtonStyle(tint: .green)).disabled(countdown.remaining <= 0)
        .accessibilityValue(ClockFormat.countdown(countdown.remaining)).accessibilityIdentifier(
          "timer-start")
    }
  }
  @ViewBuilder private var permissionNotice: some View {
    if store.notificationDenied {
      Button {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
      } label: {
        Text(L10n.text("Enable notifications in Settings for background reminders."))
          .font(ClockTheme.font(13)).foregroundStyle(.white).padding(12)
      }
    }
  }
  private var hourBinding: Binding<Int> {
    Binding(
      get: { Int(store.countdown.duration) / 3600 },
      set: {
        guard $0 != Int(store.countdown.duration) / 3600 else { return }
        store.countdown.configure(hours: $0, minutes: Int(store.countdown.duration / 60) % 60)
        store.save()
      })
  }
  private var minuteBinding: Binding<Int> {
    Binding(
      get: { Int(store.countdown.duration / 60) % 60 },
      set: {
        guard $0 != Int(store.countdown.duration / 60) % 60 else { return }
        store.countdown.configure(hours: Int(store.countdown.duration) / 3600, minutes: $0)
        store.save()
      })
  }
}
