import SwiftUI

struct ClockRootView: View {
  let store: ClockStore
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var route: Route?
  @State private var editing = false
  @State private var timerSoundPresented = false
  private enum Route {
    case city
    case alarm(ClockAlarm, Bool)
  }

  var body: some View {
    ZStack {
      background
      if route == nil {
        VStack(spacing: 0) {
          content
          tabBar
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .accessibilityHidden(store.ringing != nil || store.timerFinished || store.error != nil)
      }
      if let route {
        routeView(route).transition(reduceMotion ? .opacity : .move(edge: .bottom))
          .accessibilityAddTraits(.isModal).accessibilityAction(.escape) { close() }.zIndex(1)
      }
    }
    .preferredColorScheme(
      route != nil || store.tab == .alarm || timerSoundPresented ? .light : .dark
    )
    .fullScreenCover(item: ringingPresentation) { presentation in
      switch presentation {
      case .error(let message):
        RingingPanel(title: L10n.text("Clock"), message: message, buttonTitle: "OK") {
          store.error = nil
        }
        .presentationBackground(.clear).interactiveDismissDisabled()
      case .alarm(let alarm):
        RingingPanel(
          title: L10n.text("Alarm"), message: alarm.displayLabel,
          snooze: alarm.snooze ? { store.snooze(alarm) } : nil, stop: store.dismissRing
        )
        .presentationBackground(.clear).interactiveDismissDisabled()
        .onAppear { if !store.testing { ClockAudio.shared.playAlarm(alarm) } }
      case .timer:
        RingingPanel(title: L10n.text("Timer"), message: L10n.text("Timer finished")) {
          ClockAudio.shared.stop()
          store.cancelTimer()
        }.presentationBackground(.clear).interactiveDismissDisabled()
          .onAppear {
            if !store.testing {
              if store.countdown.sound == .stopPlaying {
                ClockAudio.shared.stopOtherPlayback()
              } else {
                ClockAudio.shared.play(store.countdown.sound, loop: true)
              }
            }
          }
      }
    }
    .task {
      store.reschedule()
      while !Task.isCancelled {
        if UIApplication.shared.applicationState == .active { store.tick() }
        try? await Task.sleep(for: .milliseconds(200))
      }
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active {
        store.tick()
        store.reschedule()
        if !store.testing, let alarm = store.ringing { ClockAudio.shared.playAlarm(alarm) }
      } else {
        store.save()
        ClockAudio.shared.stop()
      }
    }
  }
  private enum RingPresentation: Identifiable {
    case alarm(ClockAlarm)
    case timer
    case error(String)
    var id: String {
      switch self {
      case .alarm(let alarm): alarm.id.uuidString
      case .timer: "timer"
      case .error: "error"
      }
    }
  }
  private var ringingPresentation: Binding<RingPresentation?> {
    var transaction = Transaction()
    transaction.disablesAnimations = true
    return Binding<RingPresentation?>(
      get: {
        if let message = store.error { return .error(message) }
        if let alarm = store.ringing { return .alarm(alarm) }
        if store.timerFinished { return .timer }
        return nil
      },
      set: { value in
        if value == nil {
          if store.error != nil {
            store.error = nil
            return
          }
          if store.timerFinished { store.cancelTimer() }
          store.dismissRing()
        }
      }
    ).transaction(transaction)
  }
  @ViewBuilder private var background: some View {
    if route != nil || store.tab == .alarm || timerSoundPresented {
      PinstripeBackground()
    } else if store.tab == .world {
      PinstripeBackground(dark: true)
    } else {
      (store.tab == .timer ? Color(hex: 0x1B1B1B) : Color.black).ignoresSafeArea()
    }
  }
  @ViewBuilder private var content: some View {
    switch store.tab {
    case .world:
      WorldClockView(
        store: store, editing: editing, onEdit: { editing.toggle() }, onAdd: { present(.city) })
    case .alarm:
      AlarmListView(
        store: store, editing: editing, onEdit: { editing.toggle() },
        onAdd: { present(.alarm(ClockAlarm(), true)) }, onOpen: { present(.alarm($0, false)) })
    case .stopwatch: StopwatchView(store: store)
    case .timer: TimerView(store: store, onSoundPresentation: { timerSoundPresented = $0 })
    }
  }
  @ViewBuilder private func routeView(_ route: Route) -> some View {
    switch route {
    case .city: CitySearchView(store: store, close: close)
    case .alarm(let alarm, let isNew):
      AlarmEditorView(store: store, initial: alarm, isNew: isNew, close: close)
    }
  }
  private func present(_ next: Route) {
    withAnimation(reduceMotion || store.testing ? nil : .easeOut(duration: 0.25)) { route = next }
  }
  private func close() {
    ClockAudio.shared.stop()
    withAnimation(reduceMotion || store.testing ? nil : .easeIn(duration: 0.2)) { route = nil }
  }
  private var tabBar: some View {
    HStack(spacing: 0) {
      ForEach(ClockTab.allCases, id: \.self) { tab in
        Button {
          store.tab = tab
          editing = false
        } label: {
          VStack(spacing: 0) {
            ClockTabIcon(tab: tab, selected: store.tab == tab)
            Text(L10n.text(tab.rawValue)).font(.custom("HelveticaNeue-Bold", size: 10))
              .foregroundStyle(store.tab == tab ? .white : Color(hex: 0x999999))
              .lineLimit(1).minimumScaleFactor(0.75)
          }.frame(maxWidth: .infinity).frame(height: 49)
            .background {
              if store.tab == tab {
                RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.13)).padding(.horizontal, 2)
                  .padding(.vertical, 2)
              }
            }.contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier(tab.identifier)
          .accessibilityAddTraits(store.tab == tab ? .isSelected : [])
      }
    }.frame(height: 49).fixedSize(horizontal: false, vertical: true).dynamicTypeSize(
      .small ... .xxxLarge
    )
    .background(
      LinearGradient(
        stops: [
          .init(color: Color(hex: 0x3F3F3F), location: 0),
          .init(color: Color(hex: 0x202020), location: 0.5), .init(color: .black, location: 0.51),
          .init(color: .black, location: 1),
        ], startPoint: .top, endPoint: .bottom), ignoresSafeAreaEdges: []
    )
    .overlay(alignment: .top) { Color.gray.opacity(0.5).frame(height: 1) }
  }
}

struct RingingPanel: View {
  var title: String
  var message: String
  var snooze: (() -> Void)? = nil
  var buttonTitle = "Stop"
  var stop: () -> Void
  var body: some View {
    ZStack {
      Color.black.opacity(0.6).ignoresSafeArea().contentShape(Rectangle())
        .onTapGesture {}.accessibilityHidden(true)
      VStack(spacing: 18) {
        Text(title).font(ClockTheme.font(25, bold: true)).foregroundStyle(.white)
        Text(message).font(ClockTheme.font(19)).foregroundStyle(.white).multilineTextAlignment(
          .center)
        if let snooze {
          Button(L10n.text("Snooze"), action: snooze).buttonStyle(GlossyButtonStyle(tint: .green))
            .accessibilityIdentifier("ring-snooze")
        }
        Button(L10n.text(buttonTitle), action: stop).buttonStyle(GlossyButtonStyle())
          .accessibilityIdentifier("ring-stop")
      }.padding(25).frame(maxWidth: 330).dynamicTypeSize(.small ... .xxxLarge)
        .background(
          LinearGradient(
            colors: [Color(hex: 0x657794), Color(hex: 0x263C60)], startPoint: .top,
            endPoint: .bottom)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.7), lineWidth: 2) }
        .shadow(color: .black.opacity(0.8), radius: 12, y: 8)
    }.accessibilityAddTraits(.isModal).accessibilityAction(.escape, stop)
  }
}
