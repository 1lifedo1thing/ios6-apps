import SwiftUI

@main
struct CameraSixApp: App {
  @StateObject private var camera = CameraStore()

  var body: some Scene {
    WindowGroup {
      CameraRootView(camera: camera)
        .onOpenURL { url in
          if url.scheme == "camerasix", url.host == "capture" { camera.showRoll = false }
        }
        .preferredColorScheme(.dark)
        .environment(\.locale, AppLanguage.current.locale)
    }
  }
}
