import SwiftUI

struct CompassSettingsView: View {
  let compass: CompassService
  let done: () -> Void
  @Environment(\.openURL) private var openURL

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Color.clear.frame(width: 64, height: 44)
        Text(L10n.text("Compass"))
          .font(.custom("HelveticaNeue-Bold", fixedSize: 20)).frame(maxWidth: .infinity)
          .shadow(color: .black, radius: 1, y: -1)
        Button(L10n.text("Done"), action: done)
          .font(.custom("HelveticaNeue-Bold", fixedSize: 13))
          .buttonStyle(ClassicButtonStyle()).frame(width: 64)
          .accessibilityIdentifier("settings-done")
      }
      .padding(.horizontal, 6).frame(height: 44).background(CompassToolbar())
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          VStack(spacing: 0) {
            ForEach(NorthReference.allCases, id: \.rawValue) { reference in
              Button {
                compass.select(reference)
              } label: {
                HStack {
                  Text(L10n.text(reference.title))
                    .font(.custom("HelveticaNeue-Bold", size: 17))
                  Spacer()
                  if compass.reference == reference {
                    Text("✓").font(.system(size: 20, weight: .bold)).foregroundColor(
                      Color(red: 0.2, green: 0.33, blue: 0.5))
                  }
                }
                .foregroundColor(.black).padding(.horizontal, 15).frame(minHeight: 50)
                .background(compass.reference == reference ? Color(white: 0.94) : .white)
              }
              .accessibilityValue(compass.reference == reference ? L10n.text("Selected") : "")
              .accessibilityAddTraits(compass.reference == reference ? [.isSelected] : [])
              .accessibilityIdentifier("north-" + reference.rawValue)
              if reference == .magnetic { Color.gray.opacity(0.3).frame(height: 1) }
            }
          }
          .clipShape(RoundedRectangle(cornerRadius: 10))
          .overlay { RoundedRectangle(cornerRadius: 10).stroke(.black.opacity(0.6), lineWidth: 1) }
          Text(
            L10n.text(
              "Magnetic north follows Earth's magnetic field. True north uses your current location to point toward the geographic North Pole."
            )
          )
          .font(.custom("HelveticaNeue", size: 14)).foregroundColor(.white.opacity(0.85))
          section("Location") {
            Text(
              L10n.text(
                compass.locationMessage.isEmpty
                  ? "Coordinates are available." : compass.locationMessage))
            if let location = compass.location {
              Text(CompassMath.coordinates(location)).font(.custom("HelveticaNeue-Bold", size: 15))
              Text(L10n.format("Location accuracy: ±%.0f m", location.horizontalAccuracy))
            }
            if compass.authorization == .denied {
              Button(L10n.text("Open Settings")) {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
              }
              .buttonStyle(ClassicButtonStyle()).accessibilityIdentifier("open-settings")
            } else if compass.authorization == .notDetermined {
              Button(L10n.text("Allow Location")) { compass.requestLocation() }
                .buttonStyle(ClassicButtonStyle())
            }
          }
          section("Calibration") {
            Text(
              L10n.text(
                "Hold iPhone flat, level with the ground. Move it in a figure eight when calibration is needed."
              ))
            Text(L10n.text("Keep away from magnets, magnetic cases, speakers, and metal surfaces."))
            if let accuracy = compass.accuracy {
              Text(L10n.format("Heading accuracy: ±%.0f°", accuracy))
            }
          }
          #if targetEnvironment(simulator)
            section("Simulator") {
              Text(
                L10n.text(
                  "Simulator has no magnetometer. Preview readings are sample data, not your real heading or location."
                ))
              Button(L10n.text(compass.demo ? "Stop Preview" : "Start Preview")) {
                compass.togglePreview()
              }
              .buttonStyle(ClassicButtonStyle()).accessibilityIdentifier("toggle-preview")
            }
          #endif
          Text(
            L10n.text(
              "Use for basic navigation assistance. Magnetic interference can affect accuracy.")
          )
          .font(.custom("HelveticaNeue", size: 13)).foregroundColor(.white.opacity(0.7))
        }
        .padding(20).frame(maxWidth: 600).frame(maxWidth: .infinity)
      }
      .accessibilityIdentifier("settings-scroll")
    }
    .foregroundColor(.white)
    .background {
      Color(red: 0.19, green: 0.2, blue: 0.22).ignoresSafeArea()
      Canvas { context, size in
        for y in stride(from: 0.0, to: size.height, by: 3) {
          let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
          context.fill(Path(rect), with: .color(.white.opacity(0.025)))
        }
        for x in stride(from: 0.0, to: size.width, by: 3) {
          let rect = CGRect(x: x, y: 0, width: 1, height: size.height)
          context.fill(Path(rect), with: .color(.black.opacity(0.09)))
        }
      }.ignoresSafeArea().accessibilityHidden(true)
    }
  }

  private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content)
    -> some View
  {
    VStack(alignment: .leading, spacing: 10) {
      Text(L10n.text(title)).font(.custom("HelveticaNeue-Bold", size: 17))
      content().font(.custom("HelveticaNeue", size: 14)).fixedSize(
        horizontal: false, vertical: true)
    }
  }
}
