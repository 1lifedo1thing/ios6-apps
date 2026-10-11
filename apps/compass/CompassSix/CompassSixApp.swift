import SwiftUI

@main
struct CompassSixApp: App {
  @State private var compass: CompassService

  init() {
    let arguments = ProcessInfo.processInfo.arguments
    #if targetEnvironment(simulator)
      let defaults =
        arguments.contains("--uitesting")
        ? UserDefaults(suiteName: "CompassSixUITests")! : .standard
      if arguments.contains("--uitesting"), !arguments.contains("--preserve-preferences") {
        defaults.removePersistentDomain(forName: "CompassSixUITests")
      }
    #else
      let defaults = UserDefaults.standard
    #endif
    let service = CompassService(defaults: defaults)
    service.configurePreview(arguments: arguments)
    _compass = State(initialValue: service)
  }

  var body: some Scene {
    WindowGroup {
      CompassRootView(compass: compass)
        .environment(\.locale, AppLanguage.current.locale)
        .preferredColorScheme(.dark)
    }
  }
}
