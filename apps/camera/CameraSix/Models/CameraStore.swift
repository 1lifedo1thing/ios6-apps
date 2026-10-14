import AVFoundation
import SwiftUI
import UIKit

@MainActor
final class CameraStore: ObservableObject {
  let engine = CameraEngine()
  let library: MediaLibrary
  @Published var settings: CameraSettings
  @Published private(set) var mode: CaptureMode = .photo
  @Published private(set) var ready = false
  @Published private(set) var capabilities = CameraCapabilities()
  @Published private(set) var recording = false
  @Published private(set) var busy = false
  @Published private(set) var front = false
  @Published var focusLocked = false
  @Published var zoom: CGFloat = 1
  @Published var message: String?
  @Published var unavailable: String?
  @Published var showRoll = false
  @Published var panoramaRunning = false
  @Published var panoramaProgress = 0.0
  @Published var panoramaLevel = 0.0
  @Published var panoramaDirection = 1.0
  @Published var capturePulse = 0
  @Published var recordStarted: Date?
  @Published private(set) var switchPhase: CameraSwitchPhase = .idle
  @Published var transitioning = false
  private var recordingTimer: Timer?
  private var savedTorchMode: FlashMode = .off
  private var mediaTasks = 0
  private var switchID: UUID?
  let isDemo: Bool
  private let isTesting: Bool
  private let isHardwareSmoke: Bool

  init() {
    let arguments = ProcessInfo.processInfo.arguments
    isTesting = arguments.contains("--ui-testing")
    #if targetEnvironment(simulator)
      isDemo = true
    #else
      isDemo = arguments.contains("--demo")
    #endif
    let hardwareSmoke = arguments.contains("--hardware-smoke")
    isHardwareSmoke = hardwareSmoke
    let directory: URL? =
      isTesting
      ? FileManager.default.temporaryDirectory
        .appendingPathComponent("CameraSix-UI", isDirectory: true)
      : hardwareSmoke
        ? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
          .appendingPathComponent("HardwareSmoke", isDirectory: true) : nil
    if isTesting, !arguments.contains("--preserve-test-roll"), let directory {
      try? FileManager.default.removeItem(at: directory)
    }
    library = MediaLibrary(directory: directory)
    settings = isTesting || hardwareSmoke ? CameraSettings() : CameraSettings.load()
    if isTesting || isDemo || hardwareSmoke { settings.saveToPhotos = false }
    engine.event = { [weak self] event in self?.handle(event) }
    #if DEBUG
      if hardwareSmoke {
        let logURL = library.directory.appendingPathComponent("diagnostic.txt")
        engine.diagnostic = { text in try? Data(text.utf8).write(to: logURL, options: .atomic) }
      }
    #endif
  }

  var canCapture: Bool { ready && !busy && !transitioning && mediaTasks == 0 && !showRoll }
  var isSwitchingCamera: Bool { switchPhase != .idle }
  var demoImage: UIImage { UIImage(named: front ? "DemoFront" : "DemoScene") ?? UIImage() }

  func activate() async {
    if isDemo {
      capabilities = CameraCapabilities(
        flash: !front, hdr: true, switchCamera: true, maximumZoom: 5)
      ready = true
      unavailable = nil
      UIApplication.shared.isIdleTimerDisabled = true
    } else {
      await engine.start()
    }
  }

  func deactivate() {
    cancelCameraSwitch()
    if recording && isDemo { shutter() }
    if panoramaRunning && isDemo { shutter() }
    if !isDemo { engine.suspend() }
    ready = false
    UIApplication.shared.isIdleTimerDisabled = false
  }

  private func handle(_ event: CameraEvent) {
    switch event {
    case .ready(let value):
      capabilities = value
      ready = true
      unavailable = nil
      UIApplication.shared.isIdleTimerDisabled = true
      if !value.flash { settings.flash = .off }
      if !value.hdr { settings.hdr = false }
    case .unavailable(let key):
      cancelCameraSwitch()
      ready = false
      unavailable = key
      UIApplication.shared.isIdleTimerDisabled = false
    case .error(let key):
      cancelCameraSwitch()
      busy = false
      transitioning = false
      if mode == .panorama { panoramaRunning = false }
      message = key
    case .photo(let data, let hdr, let normal):
      capturePulse += 1
      mediaTasks += 1
      Task {
        defer {
          mediaTasks -= 1
          objectWillChange.send()
        }
        do {
          if let normal {
            let item = try await library.addPhoto(normal)
            await autoSave(item)
          }
          let item = try await library.addPhoto(data, hdr: hdr)
          await autoSave(item)
        } catch { message = "The photo could not be saved. Please check available storage." }
      }
    case .movie(let url):
      mediaTasks += 1
      Task {
        defer {
          mediaTasks -= 1
          objectWillChange.send()
        }
        do {
          let item = try await library.addVideo(url)
          await autoSave(item)
        } catch { message = "The video could not be saved. Please check available storage." }
      }
    case .recording(let value):
      recording = value
      transitioning = false
      recordStarted = value ? .now : nil
      UIApplication.shared.isIdleTimerDisabled = value || ready
    case .panoramaProgress(let progress, let level):
      panoramaProgress = progress
      panoramaLevel = level
    case .panorama(let data):
      panoramaRunning = false
      capturePulse += 1
      mediaTasks += 1
      Task {
        defer {
          mediaTasks -= 1
          objectWillChange.send()
        }
        do {
          let item = try await library.addPhoto(data, kind: .panorama)
          await autoSave(item)
        } catch { message = "The photo could not be saved. Please check available storage." }
      }
    case .busy(let value): busy = value
    }
  }

  func updateSettings(_ action: (inout CameraSettings) -> Void) {
    action(&settings)
    if !isTesting && !isHardwareSmoke { settings.save() }
    if mode == .video, !isDemo { engine.setTorch(settings.flash == .on) }
  }

  func setMode(_ target: CaptureMode) async {
    guard !recording, !panoramaRunning, !busy, !transitioning, target != mode else { return }
    transitioning = true
    defer { transitioning = false }
    let changed = isDemo ? true : await engine.setMode(target)
    if changed {
      mode = target
      focusLocked = false
      panoramaProgress = 0
      if target == .video {
        savedTorchMode = settings.flash
        settings.flash = .off
      } else if target == .photo {
        settings.flash = savedTorchMode
      }
    }
  }

  func switchCamera() {
    guard canCapture, !recording, !panoramaRunning, capabilities.switchCamera else { return }
    switchID = UUID()
    transitioning = true
    switchPhase = .closing
  }

  func commitCameraSwitch() async {
    guard switchPhase == .closing, let identifier = switchID else { return }
    switchPhase = .changing
    let result: CameraSwitchResult
    if isDemo {
      // The demo models the short wait for the replacement camera's first frames.
      try? await Task.sleep(for: .milliseconds(90))
      guard switchID == identifier else { return }
      result = CameraSwitchResult(front: !front, succeeded: true)
    } else {
      result = await engine.switchCamera()
    }
    front = result.front
    guard switchID == identifier else { return }
    zoom = 1
    focusLocked = false
    if isDemo { capabilities.flash = !front }
    if !capabilities.flash { settings.flash = .off }
    if !result.succeeded { message = "Unable to switch cameras. Please try again." }
    switchPhase = .opening
  }

  func finishCameraSwitch() {
    guard switchPhase == .opening else { return }
    switchID = nil
    switchPhase = .idle
    transitioning = false
  }

  private func cancelCameraSwitch() {
    guard isSwitchingCamera else { return }
    switchID = nil
    switchPhase = .idle
    transitioning = false
  }

  func focus(_ point: CGPoint, locked: Bool) {
    focusLocked = locked
    if !isDemo { engine.focus(point, locked: locked) }
  }

  func setZoom(_ value: CGFloat) {
    guard mode != .panorama else { return }
    zoom = min(capabilities.maximumZoom, max(1, value))
    if !isDemo { engine.zoom(zoom) }
  }

  func shutter() {
    guard canCapture else { return }
    switch mode {
    case .photo:
      if isDemo {
        handle(
          .photo(
            demoPhoto(), hdr: settings.hdr,
            normal: settings.hdr && settings.keepNormal ? demoPhoto() : nil))
      } else {
        engine.capture(settings: settings)
      }
    case .video:
      if isDemo {
        if recording {
          let duration = min(12, max(1, Date.now.timeIntervalSince(recordStarted ?? .now)))
          handle(.recording(false))
          busy = true
          Task {
            do {
              handle(.movie(try await DemoMedia.video(image: demoImage, duration: duration)))
            } catch { message = "The video could not be recorded. Please try again." }
            busy = false
          }
        } else {
          handle(.recording(true))
        }
      } else {
        transitioning = true
        engine.toggleRecording()
      }
    case .panorama:
      if panoramaRunning {
        recordingTimer?.invalidate()
        recordingTimer = nil
        if isDemo {
          panoramaRunning = false
          let image = UIImage(named: "DemoPanorama") ?? demoImage
          if let data = image.jpegData(compressionQuality: 0.94) { handle(.panorama(data)) }
        } else {
          busy = true
          engine.finishPanorama()
        }
      } else {
        panoramaRunning = true
        panoramaProgress = 0
        if isDemo {
          recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) {
            [weak self] _ in
            Task { @MainActor in
              guard let self else { return }
              self.panoramaProgress += 0.025
              if self.panoramaProgress >= 1 { self.shutter() }
            }
          }
        } else {
          engine.beginPanorama(direction: panoramaDirection)
        }
      }
    }
  }

  func videoSnapshot() {
    guard recording, !busy else { return }
    if isDemo {
      handle(.photo(demoPhoto(), hdr: false, normal: nil))
    } else {
      var snapshot = settings
      snapshot.hdr = false
      snapshot.flash = .off
      engine.capture(settings: snapshot)
    }
  }

  private func demoPhoto() -> Data {
    let image = demoImage
    let size = image.size
    let crop = CGRect(
      x: size.width / 2 - size.width / zoom / 2,
      y: size.height / 2 - size.height / zoom / 2, width: size.width / zoom,
      height: size.height / zoom)
    if let cgImage = image.cgImage?.cropping(to: crop) {
      return UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.94) ?? Data()
    }
    return image.jpegData(compressionQuality: 0.94) ?? Data()
  }

  private func autoSave(_ item: CapturedMedia) async {
    guard settings.saveToPhotos else { return }
    do { try await library.saveToPhotos(item) } catch LibraryError.permissionDenied {
      message =
        "Saved in Camera Roll. Allow Photos access in Settings to save to your photo library."
    } catch {
      message = "Saved in Camera Roll, but saving to Photos failed. You can retry from Camera Roll."
    }
  }
}
