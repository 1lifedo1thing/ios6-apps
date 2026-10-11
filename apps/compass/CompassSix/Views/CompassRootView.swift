import SwiftUI

struct CompassRootView: View {
  let compass: CompassService
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.openURL) private var openURL
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var settings = false
  @State private var mapsError = false

  var body: some View {
    ZStack {
      WalnutBackground()
      mainScreen
        .accessibilityHidden(settings)
        .allowsHitTesting(!settings)
        .rotation3DEffect(.degrees(settings && !reduceMotion ? -90 : 0), axis: (x: 0, y: 1, z: 0))
        .opacity(settings ? 0 : 1)
      if settings {
        CompassSettingsView(compass: compass) { changeSettings(false) }
          .transition(
            reduceMotion
              ? .opacity
              : .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity))
          )
          .accessibilityAddTraits(.isModal)
          .accessibilityAction(.escape) { changeSettings(false) }
          .zIndex(1)
      }
    }
    .background { HeadingOrientationReader { compass.updateOrientation($0) } }
    .onAppear { if scenePhase == .active { compass.start() } }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { compass.start() } else { compass.stop() }
    }
    .alert(L10n.text("Couldn't open Maps"), isPresented: $mapsError) {
      Button(L10n.text("OK"), role: .cancel) {}
    } message: {
      Text(L10n.text("Please try again or open Maps from the Home Screen."))
    }
  }

  private var mainScreen: some View {
    GeometryReader { geometry in
      let landscape = geometry.size.width > geometry.size.height
      VStack(spacing: 0) {
        if landscape {
          HStack(spacing: 25) {
            instrument(size: min(geometry.size.height - 104, geometry.size.width * 0.45))
            readout
          }
          .padding(.horizontal, 20).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          VStack(spacing: 0) {
            Spacer(minLength: 10)
            bearing
            instrument(size: min(geometry.size.width - 20, geometry.size.height * 0.6))
              .padding(.top, 14)
            readout
              .padding(.top, 16)
            Spacer(minLength: 10)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        toolbar
      }
    }
  }

  private var bearing: some View {
    Text(compass.heading.map { CompassMath.bearing($0) } ?? "—°")
      .font(.custom("HelveticaNeue", size: 46)).foregroundColor(.white)
      .monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
      .shadow(color: .black, radius: 2, y: 2)
      .accessibilityLabel(L10n.text("Heading"))
      .accessibilityValue(
        compass.heading.map { CompassMath.bearing($0) } ?? L10n.text("Unavailable")
      )
      .accessibilityIdentifier("heading-readout")
  }

  private func instrument(size: CGFloat) -> some View {
    ZStack {
      ZStack(alignment: .top) {
        Path { path in
          path.move(to: CGPoint(x: size / 2, y: -25))
          path.addLine(to: CGPoint(x: size / 2 - 21, y: 0))
          path.addLine(to: CGPoint(x: size / 2 + 21, y: 0))
          path.closeSubpath()
        }
        .fill(.black.opacity(0.65)).shadow(color: .white.opacity(0.2), radius: 0.5, y: 1)
        CompassDial(
          angle: compass.heading == nil ? 0 : compass.dialAngle, available: compass.heading != nil)
      }
      .accessibilityHidden(true)
      Color.clear.frame(width: max(100, size), height: max(100, size))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.text("Compass dial"))
        .accessibilityValue(
          compass.heading.map { CompassMath.bearing($0) } ?? L10n.text("Unavailable")
        )
        .accessibilityIdentifier("compass-dial")
    }
    .frame(width: max(100, size), height: max(100, size))
  }

  private var readout: some View {
    VStack(spacing: 8) {
      if let orientation = UIApplication.shared.connectedScenes.compactMap({
        ($0 as? UIWindowScene)?.interfaceOrientation
      }).first,
        orientation.isLandscape
      {
        bearing
      }
      if compass.demo {
        Text(L10n.text("SIMULATOR PREVIEW"))
          .font(.custom("HelveticaNeue-Bold", size: 11)).foregroundColor(
            Color(red: 1, green: 0.87, blue: 0.58)
          )
          .accessibilityIdentifier("preview-badge")
        HStack(spacing: 20) {
          Button {
            compass.turnPreview(by: -15)
          } label: {
            Text("↶").font(.system(size: 22))
          }
          .accessibilityLabel(L10n.text("Turn preview left"))
          .accessibilityIdentifier("preview-left")
          Button {
            compass.turnPreview(by: 15)
          } label: {
            Text("↷").font(.system(size: 22))
          }
          .accessibilityLabel(L10n.text("Turn preview right"))
          .accessibilityIdentifier("preview-right")
        }
        .buttonStyle(ClassicButtonStyle())
      }
      if !compass.headingMessage.isEmpty {
        Text(L10n.text(compass.headingMessage))
          .font(.custom("HelveticaNeue", size: 14)).foregroundColor(.white.opacity(0.85))
          .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("heading-status")
      }
      if compass.heading == nil || compass.accuracy.map({ $0 > 20 }) == true {
        Button(L10n.text("Compass Help")) { changeSettings(true) }
          .font(.custom("HelveticaNeue-Bold", size: 13)).buttonStyle(ClassicButtonStyle())
          .accessibilityIdentifier("compass-help")
      }
    }
    .padding(.horizontal, 20)
  }

  private var toolbar: some View {
    HStack(spacing: 3) {
      Button(action: showMaps) {
        Image(systemName: "location.fill").font(.system(size: 18))
      }
      .buttonStyle(ClassicButtonStyle())
      .disabled(compass.location == nil || compass.demo)
      .opacity(compass.location == nil || compass.demo ? 0.45 : 1)
      .accessibilityLabel(L10n.text("Show current location in Maps"))
      .accessibilityIdentifier("open-maps")
      if let location = compass.location {
        Text(CompassMath.coordinates(location))
          .font(.custom("HelveticaNeue-Bold", size: 13)).foregroundColor(.white)
          .lineLimit(1).minimumScaleFactor(0.65).frame(maxWidth: .infinity)
          .accessibilityLabel(L10n.text("Coordinates"))
          .accessibilityValue(CompassMath.coordinates(location))
          .accessibilityIdentifier("coordinates")
      } else {
        Button {
          changeSettings(true)
        } label: {
          Text(L10n.text("Location unavailable"))
            .font(.custom("HelveticaNeue-Bold", size: 12)).foregroundColor(.white.opacity(0.75))
            .lineLimit(2).frame(maxWidth: .infinity, minHeight: 44)
        }
        .accessibilityIdentifier("location-unavailable")
      }
      Button {
        changeSettings(true)
      } label: {
        Text("i").font(.custom("Georgia-BoldItalic", size: 21))
      }
      .buttonStyle(ClassicButtonStyle())
      .accessibilityLabel(L10n.text("Compass settings"))
      .accessibilityIdentifier("compass-settings")
    }
    .padding(.horizontal, 5).frame(height: 48)
    .background { CompassToolbar() }
  }

  private func changeSettings(_ show: Bool) {
    withAnimation(reduceMotion ? .easeInOut(duration: 0.12) : .easeInOut(duration: 0.35)) {
      settings = show
    }
  }

  private func showMaps() {
    guard !compass.demo, let location = compass.location,
      let url = CompassMath.mapsURL(for: location)
    else { return }
    openURL(url) { success in if !success { mapsError = true } }
  }
}
