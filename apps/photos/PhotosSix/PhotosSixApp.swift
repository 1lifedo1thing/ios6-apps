import SwiftUI

@main
struct PhotosSixApp: App {
  @State private var library = PhotoLibrary()
  var body: some Scene {
    WindowGroup { PhotosRootView(library: library) }
  }
}
