import SwiftUI

struct CameraRootView: View {
  @ObservedObject var camera: CameraStore
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  @State private var optionsOpen = false
  @State private var flashOpen = false
  @State private var settingsOpen = false
  @State private var focusPoint: CGPoint?
  @State private var focusToken = UUID()
  @State private var flashWhite = false
  @State private var irisClosure = 1.0
  @State private var cameraTurn = 0.0
  @State private var turnFinished = true
  @State private var transitionToken = UUID()

  private var reduceMotion: Bool {
    #if DEBUG
      let arguments = ProcessInfo.processInfo.arguments
      if arguments.contains("--ui-testing") && arguments.contains("--reduce-motion") { return true }
    #endif
    return systemReduceMotion
  }

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      GeometryReader { geometry in
        let landscape = geometry.size.width > geometry.size.height
        if landscape {
          HStack(spacing: 0) {
            viewfinder(size: CGSize(width: geometry.size.width - 88, height: geometry.size.height))
            captureBar(vertical: true).frame(width: 88)
          }
        } else {
          VStack(spacing: 0) {
            viewfinder(size: CGSize(width: geometry.size.width, height: geometry.size.height - 83))
            captureBar(vertical: false).frame(height: 83)
          }
        }
      }
      if let message = camera.message {
        ClassicCameraAlert(title: "Camera", message: message, confirm: "OK") {
          camera.message = nil
        }
      }
    }
    .task {
      await camera.activate()
      #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--hardware-smoke") {
          await HardwareSmokeCheck.run(camera)
        }
      #endif
    }
    .onChange(of: scenePhase) {
      if scenePhase == .active && !camera.showRoll {
        Task { await camera.activate() }
      } else if scenePhase == .background {
        camera.deactivate()
      }
    }
    .onChange(of: camera.showRoll) {
      optionsOpen = false
      flashOpen = false
      if camera.showRoll { camera.deactivate() } else { Task { await camera.activate() } }
    }
    .onChange(of: camera.capturePulse) {
      flashWhite = true
      Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(110))
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { flashWhite = false }
      }
    }
    .onChange(of: camera.switchPhase) { animateCameraSwitch() }
    .onChange(of: camera.ready) {
      if camera.ready && !camera.isSwitchingCamera {
        // The original opening iris also warms the material renderer before the first switch.
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.28)) { irisClosure = 0 }
      }
    }
    .onChange(of: reduceMotion) { if camera.isSwitchingCamera { animateCameraSwitch() } }
    .fullScreenCover(isPresented: $camera.showRoll) {
      CameraRollView(library: camera.library, isDemo: camera.isDemo) { camera.showRoll = false }
    }
    .fullScreenCover(isPresented: $settingsOpen) {
      CameraSettingsView(camera: camera) { settingsOpen = false }
    }
  }

  private func animateCameraSwitch() {
    switch camera.switchPhase {
    case .closing:
      let token = UUID()
      transitionToken = token
      focusPoint = nil
      optionsOpen = false
      flashOpen = false
      turnFinished = reduceMotion
      if reduceMotion {
        Task { await camera.commitCameraSwitch() }
      } else {
        withAnimation(
          .timingCurve(0.45, 0.0, 0.22, 1.0, duration: 0.22),
          completionCriteria: .logicallyComplete
        ) {
          irisClosure = 1
        } completion: {
          guard transitionToken == token, camera.switchPhase == .closing else { return }
          Task { await camera.commitCameraSwitch() }
        }
      }
    case .changing:
      let token = transitionToken
      if reduceMotion {
        cameraTurn = 0
        turnFinished = true
      } else {
        withAnimation(.easeInOut(duration: 0.42), completionCriteria: .logicallyComplete) {
          cameraTurn = 180
        } completion: {
          guard transitionToken == token else { return }
          turnFinished = true
          revealCamera()
        }
      }
    case .opening:
      if reduceMotion { turnFinished = true }
      revealCamera()
    case .idle:
      transitionToken = UUID()
      var transaction = Transaction(animation: nil)
      transaction.disablesAnimations = true
      withTransaction(transaction) {
        irisClosure = 0
        cameraTurn = 0
        turnFinished = true
      }
    }
  }

  private func revealCamera() {
    guard camera.switchPhase == .opening, turnFinished else { return }
    let token = transitionToken
    withAnimation(
      reduceMotion ? nil : .timingCurve(0.20, 0.0, 0.25, 1.0, duration: 0.28),
      completionCriteria: .logicallyComplete
    ) {
      irisClosure = 0
    } completion: {
      guard transitionToken == token else { return }
      camera.finishCameraSwitch()
    }
  }

  private func viewfinder(size: CGSize) -> some View {
    let landscape = size.width > size.height
    let portraitRatio: CGFloat = camera.mode == .video ? 0.5625 : 0.75
    let ratio: CGFloat = landscape ? 1 / portraitRatio : portraitRatio
    let width = min(size.width, size.height * ratio)
    let height = min(size.height, size.width / ratio)
    return ZStack {
      Color.black
      ZStack(alignment: .top) {
        ZStack {
          if camera.isDemo {
            Image(uiImage: camera.demoImage).resizable().scaledToFill()
              .scaleEffect(camera.zoom).frame(width: width, height: height).clipped()
          }
          CameraPreview(camera: camera) { point, locked in
            focusPoint = point
            let token = UUID()
            focusToken = token
            if !locked {
              Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                if focusToken == token { focusPoint = nil }
              }
            }
          }
          if camera.settings.grid && camera.mode == .photo { GridOverlay() }
          if let point = focusPoint {
            Rectangle().stroke(Color(red: 0.36, green: 0.63, blue: 0.96), lineWidth: 2)
              .frame(width: 76, height: 76).position(point)
              .shadow(color: .black.opacity(0.5), radius: 0, y: 1)
              .allowsHitTesting(false).accessibilityHidden(true)
          }
          if camera.mode == .panorama { panoramaOverlay }
          IrisShutter(closure: irisClosure)
          if flashWhite { Color.white.allowsHitTesting(false).accessibilityHidden(true) }
        }
        .frame(width: width, height: height)
        .modifier(CameraTurn(degrees: cameraTurn))
        VStack(spacing: 0) {
          topControls
          if flashOpen { flashChoices.padding(.horizontal, 10).padding(.top, 3) }
          if optionsOpen { optionsPanel.padding(.horizontal, 12).padding(.top, 5) }
        }
        .foregroundStyle(.white)
        if !camera.ready {
          VStack(spacing: 16) {
            if let unavailable = camera.unavailable {
              Text(L10n.text(unavailable)).font(CameraTheme.font(17)).multilineTextAlignment(
                .center)
              Button(L10n.text("Open Settings")) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                  UIApplication.shared.open(url)
                }
              }.buttonStyle(ChromeButtonStyle())
            } else {
              ProgressView().tint(.white)
              Text(L10n.text("Opening camera…")).font(CameraTheme.font(15))
            }
          }.padding(30).frame(maxWidth: .infinity, maxHeight: .infinity).background(
            .black.opacity(0.83))
        }
      }.frame(width: width, height: height)
        .overlay(alignment: .bottom) {
          if camera.ready && !camera.isSwitchingCamera { viewfinderStatus }
        }
        .clipped()
    }.frame(width: size.width, height: size.height)
  }

  private var viewfinderStatus: some View {
    VStack(spacing: 0) {
      if camera.recording {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
          HStack(spacing: 6) {
            Circle().fill(.red).frame(width: 9, height: 9)
            Text(
              CameraTiming.timecode(
                timeline.date.timeIntervalSince(camera.recordStarted ?? timeline.date))
            )
            .font(CameraTheme.font(18, bold: true)).monospacedDigit()
          }.padding(.horizontal, 9).padding(.vertical, 4).background(.black.opacity(0.55))
        }.accessibilityIdentifier("recording-timer")
      }
      if camera.focusLocked {
        Text(L10n.text("AE/AF Lock")).font(CameraTheme.font(14, bold: true)).foregroundStyle(
          .yellow
        )
        .padding(5).background(.black.opacity(0.65)).accessibilityIdentifier("focus-lock")
      }
      if camera.settings.hdr && camera.mode == .photo {
        Text("HDR").font(CameraTheme.font(14, bold: true)).padding(5).background(
          .black.opacity(0.5))
      }
      if camera.isDemo {
        Text(L10n.text("Simulator • Demo Viewfinder")).font(CameraTheme.font(11))
          .padding(.horizontal, 8).padding(.vertical, 3).background(.black.opacity(0.55))
          .accessibilityIdentifier("demo-indicator")
      }
      if camera.zoom > 1.01 && camera.mode != .panorama {
        HStack {
          Text("−").font(CameraTheme.font(22))
          Slider(
            value: Binding(get: { Double(camera.zoom) }, set: { camera.setZoom(CGFloat($0)) }),
            in: 1...Double(max(1.01, camera.capabilities.maximumZoom))
          )
          .tint(.white).accessibilityLabel(L10n.text("Zoom")).accessibilityIdentifier("zoom-slider")
          Text("+").font(CameraTheme.font(20))
        }.padding(.horizontal, 14).frame(height: 38).background(.black.opacity(0.5))
      }
    }.foregroundStyle(.white)
  }

  private var topControls: some View {
    HStack(spacing: 0) {
      if camera.mode == .panorama {
        Button(L10n.text(camera.panoramaRunning ? "Done" : "Cancel")) {
          if camera.panoramaRunning {
            camera.shutter()
          } else {
            Task { await camera.setMode(.photo) }
          }
        }.buttonStyle(ChromeButtonStyle(dark: true, capsule: false)).frame(minHeight: 44)
        Spacer()
        Text(L10n.text("Panorama")).font(CameraTheme.font(20, bold: true)).shadow(
          color: .black, radius: 1)
        Spacer()
        Color.clear.frame(width: 60, height: 44)
      } else {
        Button {
          flashOpen.toggle()
          optionsOpen = false
        } label: {
          HStack(spacing: 4) {
            Image(systemName: "bolt.fill").font(.system(size: 12, weight: .bold))
            Text(L10n.text(camera.settings.flash.rawValue))
          }
        }.buttonStyle(ChromeButtonStyle()).frame(minWidth: 65, minHeight: 44)
          .disabled(
            !camera.capabilities.flash || camera.recording || camera.busy || camera.transitioning
          )
          .opacity(camera.capabilities.flash ? 1 : 0.45)
          .accessibilityLabel(L10n.text("Flash") + ": " + L10n.text(camera.settings.flash.rawValue))
          .accessibilityIdentifier("flash-button")
        Spacer()
        if camera.mode == .photo {
          Button(L10n.text(optionsOpen ? "Done" : "Options")) {
            optionsOpen.toggle()
            flashOpen = false
          }.buttonStyle(ChromeButtonStyle()).frame(minHeight: 44)
            .disabled(camera.busy || camera.transitioning).accessibilityIdentifier("options-button")
        }
        Spacer()
        Button {
          camera.switchCamera()
        } label: {
          Image(systemName: "arrow.triangle.2.circlepath.camera.fill").font(
            .system(size: 18, weight: .bold))
        }.buttonStyle(ChromeButtonStyle()).frame(minWidth: 54, minHeight: 44)
          .disabled(
            camera.recording || camera.busy || camera.transitioning
              || !camera.capabilities.switchCamera
          )
          .accessibilityLabel(L10n.text("Switch camera"))
          .accessibilityValue(L10n.text(camera.front ? "Front camera" : "Back camera"))
          .accessibilityIdentifier("switch-camera")
      }
    }.frame(height: 44).padding(.horizontal, 10)
      .background(camera.mode == .panorama ? .black.opacity(0.6) : .clear)
  }

  private var flashChoices: some View {
    HStack {
      ForEach(camera.mode == .video ? [.on, .off] : FlashMode.allCases, id: \.self) { mode in
        Button(L10n.text(mode.rawValue)) {
          camera.updateSettings { $0.setFlash(mode) }
          flashOpen = false
        }.buttonStyle(ChromeButtonStyle(dark: camera.settings.flash == mode))
          .frame(maxWidth: .infinity, minHeight: 44)
          .accessibilityIdentifier("flash-" + mode.rawValue.lowercased())
      }
    }.padding(5).background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
  }

  private var optionsPanel: some View {
    VStack(spacing: 0) {
      optionRow("Grid", isOn: camera.settings.grid) { camera.updateSettings { $0.grid.toggle() } }
      Divider().overlay(.white.opacity(0.2))
      optionRow("HDR", isOn: camera.settings.hdr, enabled: camera.capabilities.hdr) {
        camera.updateSettings { $0.setHDR(!$0.hdr) }
      }
      Divider().overlay(.white.opacity(0.2))
      Button {
        optionsOpen = false
        camera.setZoom(1)
        Task { await camera.setMode(.panorama) }
      } label: {
        HStack {
          Image(systemName: "pano.fill").font(.system(size: 22))
          Text(L10n.text("Panorama")).font(CameraTheme.font(18, bold: true))
          Spacer()
          Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold))
        }.padding(.horizontal, 14).frame(height: 48).contentShape(Rectangle())
      }.buttonStyle(.plain).accessibilityIdentifier("panorama-button")
      Divider().overlay(.white.opacity(0.2))
      Button(L10n.text("Camera Settings")) {
        optionsOpen = false
        settingsOpen = true
      }
      .font(CameraTheme.font(14, bold: true)).frame(maxWidth: .infinity, minHeight: 44)
      .buttonStyle(.plain).accessibilityIdentifier("camera-settings")
    }
    .background(CameraTheme.dark, in: RoundedRectangle(cornerRadius: 10))
    .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.4), lineWidth: 1))
    .shadow(color: .black.opacity(0.7), radius: 5, y: 3)
  }

  private func optionRow(
    _ label: String, isOn: Bool, enabled: Bool = true,
    action: @escaping () -> Void
  ) -> some View {
    HStack {
      Text(L10n.text(label)).font(CameraTheme.font(18, bold: true)).opacity(enabled ? 1 : 0.5)
      Spacer()
      ClassicSwitch(label: label, isOn: isOn, enabled: enabled, action: action)
    }.padding(.horizontal, 14).frame(height: 48)
  }

  private var panoramaOverlay: some View {
    VStack(spacing: 12) {
      Spacer()
      Text(
        L10n.text(
          camera.panoramaRunning
            ? "Keep the arrow on the line and pan slowly."
            : "Tap the shutter and move iPhone in the direction of the arrow.")
      )
      .font(CameraTheme.font(15, bold: true)).multilineTextAlignment(.center)
      .padding(.horizontal, 20).shadow(color: .black, radius: 2)
      Button {
        guard !camera.panoramaRunning else { return }
        camera.panoramaDirection *= -1
      } label: {
        GeometryReader { geometry in
          let width = geometry.size.width
          ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 5).fill(.black.opacity(0.72))
              .overlay(RoundedRectangle(cornerRadius: 5).stroke(.white.opacity(0.55)))
            Rectangle().fill(Color(red: 0.46, green: 0.71, blue: 1).opacity(0.55))
              .frame(width: max(2, width * camera.panoramaProgress)).padding(3)
            Rectangle().fill(.white.opacity(0.8)).frame(height: 2).padding(.horizontal, 7)
            Image(systemName: camera.panoramaDirection > 0 ? "arrow.right" : "arrow.left")
              .font(.system(size: 28, weight: .bold)).foregroundStyle(.white).shadow(
                color: .black, radius: 1
              )
              .position(
                x: camera.panoramaDirection > 0
                  ? max(32, (width - 32) * camera.panoramaProgress)
                  : min(width - 32, width - (width - 32) * camera.panoramaProgress),
                y: 32 + CGFloat(max(-0.4, min(0.4, camera.panoramaLevel))) * 35)
          }
        }.frame(height: 64).contentShape(Rectangle())
      }.buttonStyle(.plain).padding(.horizontal, 18)
        .accessibilityLabel(L10n.text("Reverse panorama direction"))
        .accessibilityValue(
          L10n.text(camera.panoramaDirection > 0 ? "Left to right" : "Right to left")
        )
        .accessibilityIdentifier("panorama-direction")
      Spacer().frame(height: 50)
    }.foregroundStyle(.white)
  }

  private func captureBar(vertical: Bool) -> some View {
    Group {
      if vertical {
        VStack(spacing: 12) {
          thumbnail
          Spacer(minLength: 0)
          shutter.scaleEffect(0.68).frame(width: 82, height: 54)
          Spacer(minLength: 0)
          modeControl
        }
        .padding(.vertical, 12)
      } else {
        HStack {
          thumbnail
          Spacer(minLength: 10)
          shutter
          Spacer(minLength: 10)
          modeControl
        }
        .padding(.horizontal, 16)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(CameraTheme.dark)
    .overlay(alignment: vertical ? .leading : .top) {
      Rectangle().fill(.white.opacity(0.24)).frame(
        width: vertical ? 1 : nil, height: vertical ? nil : 1)
    }
  }

  private var thumbnail: some View {
    Button {
      camera.showRoll = true
    } label: {
      ZStack {
        RoundedRectangle(cornerRadius: 4).fill(Color(white: 0.06))
        if let item = camera.library.items.first, let image = camera.library.thumbnail(for: item) {
          Image(uiImage: image).resizable().scaledToFill().frame(width: 43, height: 43).clipped()
        } else {
          Image(systemName: "photo.fill").font(.system(size: 25)).foregroundStyle(
            Color(white: 0.35))
        }
      }.frame(width: 46, height: 46).clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(CameraTheme.silver, lineWidth: 2))
        .shadow(color: .black, radius: 1, y: 2)
    }.buttonStyle(.plain).disabled(
      camera.recording || camera.panoramaRunning || camera.busy || camera.transitioning
    )
    .accessibilityLabel(L10n.text("Camera Roll"))
    .accessibilityIdentifier("camera-roll")
  }

  private var shutter: some View {
    Button {
      optionsOpen = false
      flashOpen = false
      camera.shutter()
    } label: {
      ZStack {
        Capsule().fill(Color(white: 0.03)).frame(width: 112, height: 54)
          .overlay(Capsule().stroke(Color(white: 0.7), lineWidth: 1))
        Capsule().fill(CameraTheme.silver).frame(width: 102, height: 44)
          .overlay(Capsule().stroke(.white.opacity(0.8), lineWidth: 1).padding(1))
          .shadow(color: .black, radius: 1, y: 1)
        if camera.busy || (camera.transitioning && !camera.isSwitchingCamera) {
          ProgressView().tint(Color(white: 0.2))
        } else if camera.mode == .video {
          if camera.recording {
            RoundedRectangle(cornerRadius: 2).fill(.red).frame(width: 19, height: 19)
              .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color(red: 0.5, green: 0, blue: 0)))
          } else {
            Circle().fill(
              LinearGradient(
                colors: [.red, Color(red: 0.65, green: 0, blue: 0)],
                startPoint: .top, endPoint: .bottom)
            ).frame(width: 25, height: 25)
              .overlay(Circle().stroke(Color(red: 0.5, green: 0, blue: 0)))
          }
        } else if camera.panoramaRunning {
          Text(L10n.text("Done")).font(CameraTheme.font(18, bold: true)).foregroundStyle(
            Color(white: 0.2))
        } else {
          CameraGlyph().foregroundStyle(Color(white: 0.2)).frame(width: 29, height: 24)
        }
      }.scaleEffect(0.97)
    }.buttonStyle(ShutterButtonStyle())
      .disabled(!camera.canCapture)
      .accessibilityLabel(
        L10n.text(
          camera.mode == .video
            ? (camera.recording ? "Stop recording" : "Record video")
            : camera.mode == .panorama
              ? (camera.panoramaRunning ? "Finish panorama" : "Start panorama") : "Take photo")
      )
      .accessibilityIdentifier("shutter")
  }

  @ViewBuilder private var modeControl: some View {
    if camera.recording {
      Button {
        camera.videoSnapshot()
      } label: {
        CameraGlyph().frame(width: 24, height: 20).foregroundStyle(.white)
          .frame(width: 70, height: 46).background(CameraTheme.dark, in: Capsule())
      }.buttonStyle(.plain).disabled(camera.busy).accessibilityLabel(
        L10n.text("Take photo while recording")
      )
      .accessibilityIdentifier("video-snapshot")
    } else if camera.mode == .panorama {
      Text(L10n.text("Panorama")).font(CameraTheme.font(12, bold: true)).foregroundStyle(.white)
        .frame(width: 78)
    } else {
      PhotoVideoSwitch(mode: camera.mode, enabled: !camera.busy && !camera.transitioning) { mode in
        optionsOpen = false
        flashOpen = false
        Task { await camera.setMode(mode) }
      }.frame(width: 88)
    }
  }
}

private struct ShutterButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.brightness(configuration.isPressed ? -0.22 : 0)
      .scaleEffect(configuration.isPressed ? 0.97 : 1)
  }
}

private struct GridOverlay: View {
  var body: some View {
    GeometryReader { geometry in
      Path { path in
        for fraction in [1.0 / 3, 2.0 / 3] {
          path.move(to: CGPoint(x: geometry.size.width * fraction, y: 0))
          path.addLine(to: CGPoint(x: geometry.size.width * fraction, y: geometry.size.height))
          path.move(to: CGPoint(x: 0, y: geometry.size.height * fraction))
          path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height * fraction))
        }
      }.stroke(.white.opacity(0.6), lineWidth: 1).shadow(
        color: .black.opacity(0.5), radius: 0, y: 1)
    }.allowsHitTesting(false).accessibilityHidden(true)
  }
}

private struct PhotoVideoSwitch: View {
  let mode: CaptureMode
  let enabled: Bool
  let action: (CaptureMode) -> Void

  var body: some View {
    VStack(spacing: 5) {
      HStack {
        Button {
          action(.photo)
        } label: {
          CameraGlyph().frame(width: 18, height: 15).frame(width: 44, height: 44).contentShape(
            Rectangle())
        }
        .accessibilityLabel(L10n.text("Photo mode")).accessibilityIdentifier("photo-mode")
        Spacer(minLength: 0)
        Button {
          action(.video)
        } label: {
          CameraGlyph(video: true).frame(width: 19, height: 15).frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(L10n.text("Video mode")).accessibilityIdentifier("video-mode")
      }.foregroundStyle(.white)
      ZStack(alignment: mode == .photo ? .leading : .trailing) {
        Capsule().fill(.black).frame(height: 13).overlay(
          Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
        Capsule().fill(CameraTheme.silver).frame(width: 30, height: 12)
          .overlay(Capsule().stroke(.white.opacity(0.65), lineWidth: 1)).padding(.horizontal, 1)
      }
      .gesture(
        DragGesture(minimumDistance: 6).onEnded { value in
          action(value.translation.width > 0 ? .video : .photo)
        }
      )
      .accessibilityElement().accessibilityLabel(L10n.text("Camera/Video switch"))
      .accessibilityValue(L10n.text(mode == .photo ? "Photo mode" : "Video mode"))
      .accessibilityAdjustableAction { direction in
        action(direction == .increment ? .video : .photo)
      }
    }.buttonStyle(.plain).disabled(!enabled).frame(height: 62)
  }
}

struct ClassicCameraAlert: View {
  let title: String
  let message: String
  let confirm: String
  var cancel: String? = nil
  let action: () -> Void
  var dismiss: (() -> Void)? = nil

  var body: some View {
    ZStack {
      Color.black.opacity(0.5).ignoresSafeArea()
      VStack(spacing: 14) {
        Text(L10n.text(title)).font(CameraTheme.font(20, bold: true))
        Text(L10n.text(message)).font(CameraTheme.font(16)).multilineTextAlignment(.center)
        HStack(spacing: 9) {
          if let cancel {
            Button(L10n.text(cancel)) { dismiss?() }.frame(maxWidth: .infinity, minHeight: 44)
              .buttonStyle(ChromeButtonStyle(dark: true, capsule: false))
          }
          Button(L10n.text(confirm), action: action).frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(ChromeButtonStyle(dark: true, capsule: false))
            .accessibilityIdentifier("alert-confirm")
        }
      }
      .foregroundStyle(.white).shadow(color: .black.opacity(0.7), radius: 0, y: -1)
      .padding(18).frame(maxWidth: 290)
      .background(
        LinearGradient(
          colors: [
            Color(red: 0.30, green: 0.40, blue: 0.56),
            Color(red: 0.10, green: 0.20, blue: 0.37),
          ], startPoint: .top, endPoint: .bottom),
        in: RoundedRectangle(cornerRadius: 11)
      )
      .overlay(RoundedRectangle(cornerRadius: 11).stroke(.white.opacity(0.8), lineWidth: 2))
      .shadow(color: .black.opacity(0.6), radius: 9, y: 5)
      .accessibilityAddTraits(.isModal)
    }
  }
}
