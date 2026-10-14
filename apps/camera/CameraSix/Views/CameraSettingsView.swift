import SwiftUI

struct CameraSettingsView: View {
  @ObservedObject var camera: CameraStore
  let dismiss: () -> Void

  var body: some View {
    ZStack {
      Pinstripes().ignoresSafeArea()
      VStack(spacing: 0) {
        ClassicNavigation(title: L10n.text("Camera Settings"), leading: "Done", action: dismiss)
        ScrollView {
          VStack(spacing: 22) {
            section("HDR") {
              setting("Keep Normal Photo", isOn: camera.settings.keepNormal) {
                camera.updateSettings { $0.keepNormal.toggle() }
              }
            }
            Text(
              L10n.text(
                "HDR combines three exposures. Keep iPhone steady. Flash is disabled while HDR is on."
              )
            )
            .font(CameraTheme.font(14)).foregroundStyle(Color(white: 0.4)).padding(.horizontal, 10)
            section("Saving") {
              setting("Save to Photos", isOn: camera.settings.saveToPhotos) {
                camera.updateSettings { $0.saveToPhotos.toggle() }
              }
            }
            Text(
              L10n.text(
                "A local copy is always kept in Camera Roll. Photos permission is requested when saving."
              )
            )
            .font(CameraTheme.font(14)).foregroundStyle(Color(white: 0.4)).padding(.horizontal, 10)
            section("Permissions") {
              Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                  UIApplication.shared.open(url)
                }
              } label: {
                HStack {
                  Text(L10n.text("Open Settings"))
                  Spacer()
                  Image(systemName: "chevron.right").foregroundStyle(.gray)
                }.padding(.horizontal, 12).frame(height: 50).contentShape(Rectangle())
              }.buttonStyle(.plain).foregroundStyle(Color(white: 0.12)).font(
                CameraTheme.font(17, bold: true))
            }
            Text(L10n.text("Camera follows your iPhone language: English or Simplified Chinese."))
              .font(CameraTheme.font(14)).foregroundStyle(Color(white: 0.4)).padding(
                .horizontal, 10)
            if camera.isDemo {
              Text(
                L10n.text(
                  "Simulator uses an illustrated demo scene. Test camera, microphone, flash, and panorama motion on an iPhone."
                )
              )
              .font(CameraTheme.font(14)).foregroundStyle(Color(white: 0.4)).padding(
                .horizontal, 10)
            }
          }.padding(.horizontal, 12).padding(.vertical, 20)
        }
      }
    }.preferredColorScheme(.light)
  }

  private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content)
    -> some View
  {
    VStack(alignment: .leading, spacing: 6) {
      Text(L10n.text(title)).font(CameraTheme.font(17, bold: true)).foregroundStyle(
        Color(red: 0.30, green: 0.36, blue: 0.45)
      )
      .shadow(color: .white, radius: 0, y: 1).padding(.leading, 9)
      content().background(.white, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(white: 0.65), lineWidth: 1))
    }
  }

  private func setting(_ label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
    HStack {
      Text(L10n.text(label)).font(CameraTheme.font(17, bold: true)).foregroundStyle(
        Color(white: 0.1))
      Spacer()
      ClassicSwitch(label: label, isOn: isOn, action: action)
    }.padding(.horizontal, 12).frame(height: 50)
  }
}
