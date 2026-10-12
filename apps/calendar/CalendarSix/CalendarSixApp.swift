import SwiftUI

@main
struct CalendarSixApp: App {
  @State private var store: CalendarStore
  @State private var icon: CalendarIconController
  init() {
    let args = ProcessInfo.processInfo.arguments
    let testing = args.contains("--uitesting")
    let demo = args.contains("--demo")
    let unitTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    let directory = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("CalendarSix", isDirectory: true)
    let file = directory.appendingPathComponent(testing ? "ui-tests.json" : "calendar.json")
    if testing && args.contains("--reset") { try? FileManager.default.removeItem(at: file) }
    let reference = ISO8601DateFormatter().date(from: "2026-10-12T08:00:00Z")!
    let iconTesting = testing && args.contains("--icon-testing")
    let iconPreview = demo && args.contains("--icon-preview")
    var iconDate: Date?
    #if DEBUG
      if iconTesting, let index = args.firstIndex(of: "--icon-date"), index + 1 < args.count {
        iconDate = ISO8601DateFormatter().date(from: args[index + 1])
      }
    #endif
    _icon = State(
      initialValue: CalendarIconController(
        defaults: (testing || demo || unitTesting) ? nil : .standard,
        isolated: (unitTesting || testing || demo) && !iconTesting && !iconPreview,
        now: { iconDate ?? .now }))
    _store = State(
      initialValue: CalendarStore(
        fileURL: demo && !testing ? nil : file,
        testing: testing, demo: demo, now: (testing || demo) ? reference : .now))
  }
  var body: some Scene {
    WindowGroup {
      CalendarRootView(store: store, icon: icon)
        .environment(\.locale, AppLanguage.current.locale)
        .environment(\.calendar, store.calendar)
        .preferredColorScheme(.light)
    }
  }
}
