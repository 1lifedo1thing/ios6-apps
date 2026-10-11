import SwiftUI

@main
struct ClockSixApp: App {
  @State private var store: ClockStore
  init() {
    let args = ProcessInfo.processInfo.arguments
    let testing = args.contains("--uitesting")
    let defaults = testing ? UserDefaults(suiteName: "ClockSix-UITests")! : .standard
    if args.contains("--reset") { defaults.removePersistentDomain(forName: "ClockSix-UITests") }
    let clock = ClockStore(
      defaults: defaults, testing: testing, realReminders: args.contains("--real-reminders"))
    if args.contains("--short-timer") {
      clock.countdown.duration = 3
      clock.countdown.remaining = 3
    }
    if args.contains("--integration-timer") {
      clock.countdown.duration = 10
      clock.countdown.remaining = 10
    }
    _store = State(initialValue: clock)
  }
  var body: some Scene {
    WindowGroup {
      ClockRootView(store: store)
        .environment(\.locale, AppLanguage.current.locale)
    }
  }
}
