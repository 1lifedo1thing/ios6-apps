import SwiftUI

@main
struct CameraSixApp: App {
  @StateObject private var camera = CameraStore()

  var body: some Scene {
    WindowGroup {
      CameraRootView(camera: camera)
        .preferredColorScheme(.dark)
        .environment(\.locale, AppLanguage.current.locale)
    }
  }
}
