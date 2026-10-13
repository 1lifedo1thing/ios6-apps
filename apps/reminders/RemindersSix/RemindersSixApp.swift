import SwiftUI

@main
struct RemindersSixApp: App {
  @State private var store: ReminderStore
  init() {
    let arguments = ProcessInfo.processInfo.arguments
    let demo = arguments.contains("--demo")
    let testing = arguments.contains("--uitesting")
    let testFile = arguments.firstIndex(of: "--test-store").flatMap { index in
      arguments.indices.contains(index + 1) ? URL(fileURLWithPath: arguments[index + 1]) : nil
    }
    _store = State(
      initialValue: ReminderStore(fileURL: testFile, isolated: demo || testing, demo: demo))
  }
  var body: some Scene {
    WindowGroup {
      RemindersRootView(store: store)
        .environment(\.locale, AppLanguage.current.locale)
    }
  }
}
