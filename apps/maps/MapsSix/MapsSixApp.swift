import SwiftUI

@main
struct MapsSixApp: App {
  @State private var store: MapsStore
  init() {
    var testing = false
    var automaticallyLocate = true
    var defaults = UserDefaults.standard
    #if targetEnvironment(simulator)
      testing = ProcessInfo.processInfo.arguments.contains("--ui-testing")
      automaticallyLocate = !ProcessInfo.processInfo.arguments.contains("--skip-initial-location")
      if testing {
        defaults = UserDefaults(suiteName: "MapsSixUITests")!
        if !ProcessInfo.processInfo.arguments.contains("--preserve-preferences") {
          defaults.removePersistentDomain(forName: "MapsSixUITests")
        }
      }
    #endif
    _store = State(
      initialValue: MapsStore(
        defaults: defaults, testing: testing, automaticallyLocate: automaticallyLocate))
  }
  var body: some Scene {
    WindowGroup {
      MapsRootView(store: store)
        .environment(\.locale, AppLanguage.current.locale)
    }
  }
}
