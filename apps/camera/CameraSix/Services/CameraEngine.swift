import AVFoundation
import CoreMotion
import UIKit

struct CameraCapabilities {
  var flash = false
  var hdr = false
  var switchCamera = false
  var maximumZoom: CGFloat = 1
}

enum CameraEvent {
  case ready(CameraCapabilities)
  case unavailable(String)
  case error(String)
  case photo(Data, hdr: Bool, normal: Data?)
  case movie(URL)
  case recording(Bool)
  case panoramaProgress(Double, Double)
  case panorama(Data)
  case busy(Bool)
}

// Mutable capture state is confined to queue; expensive processing runs on processing.
final class CameraEngine: NSObject, AVCaptureFileOutputRecordingDelegate,
  AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable
{
  let session = AVCaptureSession()
  var event: ((CameraEvent) -> Void)?
  var diagnostic: ((String) -> Void)?
  private let queue = DispatchQueue(label: "CameraSix.capture", qos: .userInitiated)
  private let processing = DispatchQueue(label: "CameraSix.processing", qos: .userInitiated)
  private let photos = AVCapturePhotoOutput()
  private let movies = AVCaptureMovieFileOutput()
  private let frames = AVCaptureVideoDataOutput()
  private let motion = CMMotionManager()
  private var input: AVCaptureDeviceInput?
  private var microphone: AVCaptureDeviceInput?
  private var delegates: [Int64: PhotoDelegate] = [:]
  private var configured = false
  private var active = false
  private var mode: CaptureMode = .photo
  private var angle: CGFloat = 90
  private var panorama: PanoramaBuilder?
  private var panoDirection = 1.0
  private var previousYaw: Double?
  private var accumulatedYaw = 0.0
  private var capturedYaw = -10.0
  private var lastFrameTime = 0.0
  private var observers: [NSObjectProtocol] = []
  private var photoBusy = false
  private var focusGeneration = 0
  private struct PendingSwitch {
    let id: UUID
    let continuation: CheckedContinuation<CameraSwitchResult, Never>
    let restoreMovieOutput: Bool
    var framesReceived = 0
  }
  private var pendingSwitch: PendingSwitch?

  override init() {
    super.init()
    let center = NotificationCenter.default
    observers.append(
      center.addObserver(forName: .AVCaptureSessionWasInterrupted, object: session, queue: nil) {
        [weak self] _ in
        self?.emit(.unavailable("Camera interrupted. Return to the app to resume."))
      })
    observers.append(
      center.addObserver(forName: .AVCaptureSessionInterruptionEnded, object: session, queue: nil) {
        [weak self] _ in
        self?.resume()
      })
    observers.append(
      center.addObserver(forName: .AVCaptureSessionRuntimeError, object: session, queue: nil) {
        [weak self] notification in
        guard let self else { return }
        let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError
        if error?.code == .mediaServicesWereReset {
          self.resume()
        } else {
          self.emit(.unavailable("Camera unavailable. Try reopening the app."))
        }
      })
  }

  deinit { observers.forEach(NotificationCenter.default.removeObserver) }

  private func emit(_ value: CameraEvent) {
    DispatchQueue.main.async { [weak self] in self?.event?(value) }
  }

  func start() async {
    var status = AVCaptureDevice.authorizationStatus(for: .video)
    if status == .notDetermined {
      _ = await AVCaptureDevice.requestAccess(for: .video)
      status = AVCaptureDevice.authorizationStatus(for: .video)
    }
    guard status == .authorized else {
      emit(.unavailable("Camera access is disabled. Enable Camera in Settings."))
      return
    }
    queue.async { [weak self] in
      guard let self else { return }
      self.active = true
      do {
        if !self.configured { try self.configure() }
        if !self.session.isRunning { self.session.startRunning() }
        self.publishCapabilities()
      } catch { self.emit(.unavailable("Camera unavailable. Try reopening the app.")) }
    }
  }

  private func configure() throws {
    session.beginConfiguration()
    defer { session.commitConfiguration() }
    session.sessionPreset = .photo
    guard
      let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        ?? AVCaptureDevice.default(for: .video)
    else { throw ImageProcessingError.invalidImage }
    let newInput = try AVCaptureDeviceInput(device: device)
    guard session.canAddInput(newInput), session.canAddOutput(photos), session.canAddOutput(frames)
    else {
      throw ImageProcessingError.invalidImage
    }
    session.addInput(newInput)
    input = newInput
    session.addOutput(photos)
    photos.maxPhotoQualityPrioritization = .quality
    frames.alwaysDiscardsLateVideoFrames = true
    frames.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    frames.setSampleBufferDelegate(self, queue: queue)
    session.addOutput(frames)
    configured = true
    orientConnections()
  }

  private func publishCapabilities() {
    guard active, session.isRunning, let device = input?.device else { return }
    let front = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
    let back = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    emit(
      .ready(
        CameraCapabilities(
          flash: device.hasFlash, hdr: photos.maxBracketedCapturePhotoCount >= 3,
          switchCamera: front != nil && back != nil,
          maximumZoom: min(5, device.activeFormat.videoMaxZoomFactor))))
  }

  func resume() {
    queue.async { [weak self] in
      guard let self, self.active, self.configured else { return }
      if !self.session.isRunning { self.session.startRunning() }
      self.publishCapabilities()
    }
  }

  func suspend() {
    queue.async { [weak self] in
      guard let self else { return }
      self.active = false
      self.focusGeneration += 1
      self.completeCameraSwitch(succeeded: false)
      if self.movies.isRecording { self.movies.stopRecording() }
      if self.panorama != nil { self.finishPanoramaOnQueue() }
      self.motion.stopDeviceMotionUpdates()
      self.setTorchOnQueue(false)
      if self.session.isRunning { self.session.stopRunning() }
    }
  }

  func setMode(_ mode: CaptureMode) async -> Bool {
    if mode == .video {
      var status = AVCaptureDevice.authorizationStatus(for: .audio)
      if status == .notDetermined {
        _ = await AVCaptureDevice.requestAccess(for: .audio)
        status = AVCaptureDevice.authorizationStatus(for: .audio)
      }
      guard status == .authorized else {
        emit(
          .error("Microphone access is disabled. Enable Microphone in Settings to record sound."))
        return false
      }
    }
    return await withCheckedContinuation { continuation in
      queue.async { [weak self] in
        guard let self, self.configured, self.pendingSwitch == nil, !self.movies.isRecording,
          !self.photoBusy,
          self.panorama == nil
        else {
          continuation.resume(returning: false)
          return
        }
        self.session.beginConfiguration()
        self.focusGeneration += 1
        self.setTorchOnQueue(false)
        if mode == .video {
          if let device = AVCaptureDevice.default(for: .audio), self.microphone == nil,
            let audio = try? AVCaptureDeviceInput(device: device), self.session.canAddInput(audio)
          {
            self.session.addInput(audio)
            self.microphone = audio
          }
          if self.session.outputs.contains(self.frames) { self.session.removeOutput(self.frames) }
          self.session.sessionPreset = .high
          if !self.session.outputs.contains(self.movies), self.session.canAddOutput(self.movies) {
            self.session.addOutput(self.movies)
          }
        } else {
          if self.session.outputs.contains(self.movies) { self.session.removeOutput(self.movies) }
          if let audio = self.microphone {
            self.session.removeInput(audio)
            self.microphone = nil
          }
          self.session.sessionPreset = .photo
          if !self.session.outputs.contains(self.frames), self.session.canAddOutput(self.frames) {
            self.session.addOutput(self.frames)
          }
        }
        self.mode = mode
        self.orientConnections()
        self.session.commitConfiguration()
        self.publishCapabilities()
        continuation.resume(returning: true)
      }
    }
  }

  func switchCamera() async -> CameraSwitchResult {
    await withCheckedContinuation { continuation in
      queue.async { [self] in
        let previousFront = input?.device.position == .front
        guard active, session.isRunning, let old = input, pendingSwitch == nil,
          !movies.isRecording, !photoBusy, panorama == nil
        else {
          continuation.resume(returning: CameraSwitchResult(front: previousFront, succeeded: false))
          return
        }
        let position: AVCaptureDevice.Position = previousFront ? .back : .front
        guard
          let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: position),
          let new = try? AVCaptureDeviceInput(device: camera)
        else {
          continuation.resume(returning: CameraSwitchResult(front: previousFront, succeeded: false))
          return
        }
        session.beginConfiguration()
        focusGeneration += 1
        setTorchOnQueue(false)
        let restoreMovie = session.outputs.contains(movies)
        // Probe real frames while the iris is closed; recording is already excluded here.
        if restoreMovie { session.removeOutput(movies) }
        if !session.outputs.contains(frames), session.canAddOutput(frames) {
          session.addOutput(frames)
        }
        session.removeInput(old)
        let changed = session.canAddInput(new) && session.outputs.contains(frames)
        if changed {
          session.addInput(new)
          input = new
        } else {
          session.addInput(old)
        }
        orientConnections()
        session.commitConfiguration()
        let id = UUID()
        pendingSwitch = PendingSwitch(
          id: id, continuation: continuation, restoreMovieOutput: restoreMovie)
        if !changed {
          completeCameraSwitch(succeeded: false)
          return
        }
        // A missing camera stream must not leave the iris or controls locked indefinitely.
        queue.asyncAfter(deadline: .now() + 3) { [weak self] in
          guard self?.pendingSwitch?.id == id else { return }
          self?.completeCameraSwitch(succeeded: false)
        }
      }
    }
  }

  private func completeCameraSwitch(succeeded: Bool) {
    guard let pending = pendingSwitch else { return }
    pendingSwitch = nil
    var restored = true
    if pending.restoreMovieOutput {
      session.beginConfiguration()
      if session.outputs.contains(frames) { session.removeOutput(frames) }
      if session.canAddOutput(movies) { session.addOutput(movies) } else { restored = false }
      orientConnections()
      session.commitConfiguration()
    }
    publishCapabilities()
    pending.continuation.resume(
      returning: CameraSwitchResult(
        front: input?.device.position == .front, succeeded: succeeded && restored))
    if !restored { emit(.unavailable("Camera unavailable. Try reopening the app.")) }
  }

  func setRotation(_ angle: CGFloat) {
    queue.async { [weak self] in
      guard let self else { return }
      self.angle = angle
      if !self.movies.isRecording { self.orientConnections() }
    }
  }

  private func orientConnections() {
    for output in [photos as AVCaptureOutput, movies, frames] {
      guard let connection = output.connection(with: .video) else { continue }
      let rotation: CGFloat = output === frames ? 90 : angle
      if connection.isVideoRotationAngleSupported(rotation) {
        connection.videoRotationAngle = rotation
      }
      if connection.isVideoMirroringSupported {
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = input?.device.position == .front
      }
    }
  }

  func focus(_ point: CGPoint, locked: Bool) {
    queue.async { [weak self] in
      guard let device = self?.input?.device else { return }
      self?.focusGeneration += 1
      let generation = self?.focusGeneration
      do {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        if device.isFocusPointOfInterestSupported { device.focusPointOfInterest = point }
        if device.isExposurePointOfInterestSupported { device.exposurePointOfInterest = point }
        if device.isFocusModeSupported(.autoFocus) { device.focusMode = .autoFocus }
        if device.isExposureModeSupported(.autoExpose) { device.exposureMode = .autoExpose }
        device.isSubjectAreaChangeMonitoringEnabled = !locked
      } catch { self?.emit(.error("Unable to focus the camera.")) }
      if locked {
        self?.queue.asyncAfter(deadline: .now() + 0.7) { [weak self] in
          guard let self, self.focusGeneration == generation, let device = self.input?.device else {
            return
          }
          do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if device.isFocusModeSupported(.locked) { device.focusMode = .locked }
            if device.isExposureModeSupported(.locked) { device.exposureMode = .locked }
          } catch { self.emit(.error("Unable to focus the camera.")) }
        }
      }
    }
  }

  func zoom(_ value: CGFloat) {
    queue.async { [weak self] in
      guard let device = self?.input?.device else { return }
      do {
        try device.lockForConfiguration()
        device.videoZoomFactor = min(max(1, value), min(5, device.activeFormat.videoMaxZoomFactor))
        device.unlockForConfiguration()
      } catch { self?.emit(.error("Unable to change zoom.")) }
    }
  }

  func setTorch(_ enabled: Bool) { queue.async { [weak self] in self?.setTorchOnQueue(enabled) } }

  private func setTorchOnQueue(_ enabled: Bool) {
    guard let device = input?.device, device.hasTorch else { return }
    do {
      try device.lockForConfiguration()
      defer { device.unlockForConfiguration() }
      device.torchMode = enabled && device.isTorchAvailable ? .on : .off
    } catch { emit(.error("Flash is unavailable.")) }
  }

  func capture(settings: CameraSettings) {
    queue.async { [weak self] in
      guard let self, self.configured, self.session.isRunning, !self.photoBusy else { return }
      self.photoBusy = true
      self.emit(.busy(true))
      let useHDR =
        settings.hdr && self.mode == .photo && self.photos.maxBracketedCapturePhotoCount >= 3
      let configuration: AVCapturePhotoSettings
      if useHDR {
        let brackets = [-2.0, 0.0, 2.0].map {
          AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings(
            exposureTargetBias: Float($0))
        }
        let bracket = AVCapturePhotoBracketSettings(
          rawPixelFormatType: 0,
          processedFormat: [AVVideoCodecKey: AVVideoCodecType.jpeg], bracketedSettings: brackets)
        bracket.isLensStabilizationEnabled =
          self.photos.isLensStabilizationDuringBracketedCaptureSupported
        configuration = bracket
      } else {
        configuration = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        let flash: AVCaptureDevice.FlashMode =
          settings.flash == .on ? .on : settings.flash == .auto ? .auto : .off
        if self.mode == .photo, self.photos.supportedFlashModes.contains(flash) {
          configuration.flashMode = flash
        }
        configuration.photoQualityPrioritization = self.movies.isRecording ? .speed : .quality
      }
      let delegate = PhotoDelegate(hdr: useHDR) { [weak self] result in
        guard let self else { return }
        self.processing.async {
          switch result {
          case .success(let photos):
            do {
              guard
                let normal = photos.first(where: { abs($0.bias) < 0.01 })?.data
                  ?? photos.first?.data
              else {
                throw ImageProcessingError.invalidImage
              }
              let data =
                useHDR
                ? try ImageProcessing.fuseExposures(photos.sorted { $0.bias < $1.bias }.map(\.data))
                : normal
              self.emit(
                .photo(data, hdr: useHDR, normal: useHDR && settings.keepNormal ? normal : nil))
            } catch { self.emit(.error("The photo could not be processed. Please try again.")) }
          case .failure: self.emit(.error("The photo could not be captured. Please try again."))
          }
          self.queue.async {
            self.delegates.removeValue(forKey: configuration.uniqueID)
            self.photoBusy = false
            self.emit(.busy(false))
          }
        }
      }
      self.delegates[configuration.uniqueID] = delegate
      self.photos.capturePhoto(with: configuration, delegate: delegate)
    }
  }

  func toggleRecording() {
    queue.async { [weak self] in
      guard let self, self.session.isRunning, self.mode == .video else { return }
      if self.movies.isRecording {
        self.movies.stopRecording()
      } else {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
          UUID().uuidString + ".mov")
        self.movies.startRecording(to: url, recordingDelegate: self)
      }
    }
  }

  func fileOutput(
    _ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL,
    from connections: [AVCaptureConnection]
  ) { emit(.recording(true)) }

  func fileOutput(
    _ output: AVCaptureFileOutput, didFinishRecordingTo fileURL: URL,
    from connections: [AVCaptureConnection], error: Error?
  ) {
    emit(.recording(false))
    let nsError = error as NSError?
    if error == nil || nsError?.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool == true {
      emit(.movie(fileURL))
    } else {
      if let error { diagnostic?("Recording: \(error as NSError)") }
      emit(.error("The video could not be recorded. Please try again."))
    }
  }

  func beginPanorama(direction: Double) {
    queue.async { [weak self] in
      guard let self, self.session.isRunning, self.panorama == nil else { return }
      guard self.motion.isDeviceMotionAvailable else {
        self.emit(.error("Panorama requires motion sensors."))
        return
      }
      self.panorama = PanoramaBuilder()
      self.panoDirection = direction
      self.previousYaw = nil
      self.accumulatedYaw = 0
      self.capturedYaw = -10
      self.lastFrameTime = 0
      self.motion.deviceMotionUpdateInterval = 1 / 30
      self.motion.startDeviceMotionUpdates(using: .xArbitraryZVertical)
    }
  }

  func finishPanorama() { queue.async { [weak self] in self?.finishPanoramaOnQueue() } }

  private func finishPanoramaOnQueue() {
    guard let panorama else { return }
    self.panorama = nil
    motion.stopDeviceMotionUpdates()
    emit(.busy(true))
    processing.async { [weak self] in
      do { self?.emit(.panorama(try panorama.finish())) } catch {
        self?.emit(.error("Panorama could not be aligned. Pan slowly across a detailed scene."))
      }
      self?.emit(.busy(false))
    }
  }

  func captureOutput(
    _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    if pendingSwitch != nil {
      pendingSwitch?.framesReceived += 1
      if (pendingSwitch?.framesReceived ?? 0) >= 3 { completeCameraSwitch(succeeded: true) }
      return
    }
    guard let panorama, let attitude = motion.deviceMotion?.attitude else { return }
    let yaw = attitude.yaw
    if let previousYaw {
      var difference = yaw - previousYaw
      if difference > .pi { difference -= 2 * .pi }
      if difference < -.pi { difference += 2 * .pi }
      accumulatedYaw += difference * -panoDirection
    }
    previousYaw = yaw
    let progress = max(0, accumulatedYaw / (2 * .pi / 3))
    let level = attitude.roll
    emit(.panoramaProgress(min(1, progress), level))
    if progress >= 1 || panorama.count >= 30 {
      finishPanoramaOnQueue()
      return
    }
    let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
    guard accumulatedYaw - capturedYaw > 0.07, time - lastFrameTime > 0.22,
      let buffer = CMSampleBufferGetImageBuffer(sampleBuffer)
    else { return }
    let ciImage = CIImage(cvPixelBuffer: buffer)
    let scale = 960 / max(ciImage.extent.width, ciImage.extent.height)
    let resized = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    guard let image = ImageProcessing.context.createCGImage(resized, from: resized.extent) else {
      return
    }
    do {
      try panorama.append(UIImage(cgImage: image))
      capturedYaw = accumulatedYaw
      lastFrameTime = time
    } catch { lastFrameTime = time }
  }
}

private struct BracketPhoto {
  let data: Data
  let bias: Float
}

private final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate {
  let hdr: Bool
  let completion: (Result<[BracketPhoto], Error>) -> Void
  private var results: [BracketPhoto] = []
  private var error: Error?

  init(hdr: Bool, completion: @escaping (Result<[BracketPhoto], Error>) -> Void) {
    self.hdr = hdr
    self.completion = completion
  }

  func photoOutput(
    _ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?
  ) {
    if let error {
      self.error = error
      return
    }
    guard let data = photo.fileDataRepresentation() else {
      self.error = ImageProcessingError.invalidImage
      return
    }
    let bias =
      (photo.bracketSettings as? AVCaptureAutoExposureBracketedStillImageSettings)?
      .exposureTargetBias ?? 0
    results.append(BracketPhoto(data: data, bias: bias))
  }

  func photoOutput(
    _ output: AVCapturePhotoOutput,
    didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
    error: Error?
  ) {
    if let error = error ?? self.error {
      completion(.failure(error))
    } else {
      completion(.success(results))
    }
  }
}
