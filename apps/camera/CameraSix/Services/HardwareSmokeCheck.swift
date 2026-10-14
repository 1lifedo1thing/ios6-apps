#if DEBUG
  import AVFoundation
  import Foundation
  import UIKit

  @MainActor
  enum HardwareSmokeCheck {
    static func run(_ camera: CameraStore) async {
      guard !camera.isDemo else { return }
      UIApplication.shared.isIdleTimerDisabled = true
      let folder = camera.library.directory
      var report: [String: String] = [
        "device": UIDevice.current.model, "system": UIDevice.current.systemVersion,
        "startedAt": ISO8601DateFormatter().string(from: .now),
      ]
      func write() {
        if let data = try? JSONSerialization.data(
          withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        {
          try? data.write(to: folder.appendingPathComponent("report.json"), options: .atomic)
        }
      }
      write()
      do {
        try await wait(camera) { camera.canCapture }
        let before = camera.library.items.count
        camera.shutter()
        try await wait(camera) { camera.library.items.count > before && camera.canCapture }
        guard let photo = camera.library.items.first,
          let image = UIImage(contentsOfFile: camera.library.url(for: photo).path),
          image.size.width > 500, image.size.height > 500
        else { throw SmokeError.failed("Invalid real camera JPEG") }
        report["photo"] = "passed: \(Int(image.size.width))x\(Int(image.size.height)) JPEG"
        write()
        await camera.setMode(.video)
        try await wait(camera) { camera.mode == .video && camera.canCapture }
        if camera.capabilities.switchCamera {
          camera.switchCamera()
          try await wait(camera) { camera.canCapture }
          guard camera.front else {
            throw SmokeError.failed("Video camera did not switch to front")
          }
          camera.switchCamera()
          try await wait(camera) { camera.canCapture }
          guard !camera.front else {
            throw SmokeError.failed("Video camera did not switch to rear")
          }
          report["videoCameraSwitch"] = "passed: front/rear frames ready; movie output restored"
          write()
        }
        camera.shutter()
        try await wait(camera) { camera.recording }
        let snapshotCount = camera.library.items.count
        camera.videoSnapshot()
        try await wait(camera) { camera.library.items.count > snapshotCount && camera.canCapture }
        report["videoSnapshot"] = "passed: real still captured while recording"
        try await Task.sleep(for: .seconds(3))
        let movieCount = camera.library.items.count
        camera.shutter()
        try await wait(camera) {
          !camera.recording && camera.library.items.count > movieCount && camera.canCapture
        }
        guard let movie = camera.library.items.first(where: { $0.kind == .video }) else {
          throw SmokeError.failed("Missing movie")
        }
        let asset = AVURLAsset(url: camera.library.url(for: movie))
        let duration = try await asset.load(.duration)
        let video = try await asset.loadTracks(withMediaType: .video)
        let audio = try await asset.loadTracks(withMediaType: .audio)
        guard duration.seconds >= 2, video.count == 1, audio.count == 1 else {
          throw SmokeError.failed("Movie lacks video/audio tracks")
        }
        report["video"] = "passed: \(duration.seconds) seconds, one video track and one audio track"
        write()
        await camera.setMode(.photo)
        try await wait(camera) { camera.mode == .photo && camera.canCapture }
        if camera.capabilities.switchCamera {
          camera.switchCamera()
          try await wait(camera) { camera.canCapture }
          let frontCount = camera.library.items.count
          camera.shutter()
          try await wait(camera) { camera.library.items.count > frontCount && camera.canCapture }
          report["frontCamera"] = "passed: front camera JPEG captured"
          camera.switchCamera()
          try await wait(camera) { camera.canCapture }
        }
        if camera.capabilities.hdr {
          camera.updateSettings { $0.setHDR(true) }
          let hdrCount = camera.library.items.count
          camera.shutter()
          try await wait(camera, timeout: 25) {
            camera.library.items.count >= hdrCount + 2 && camera.canCapture
          }
          guard camera.library.items.first?.isHDR == true else {
            throw SmokeError.failed("Missing fused HDR")
          }
          report["hdr"] = "passed: three-exposure capture fused; HDR and normal JPEGs saved"
          camera.updateSettings { $0.setHDR(false) }
        } else {
          report["hdr"] = "unavailable on active camera configuration"
        }
        if camera.capabilities.switchCamera {
          camera.switchCamera()
          try await wait(camera) { camera.switchPhase == .changing }
          camera.deactivate()
          await camera.activate()
          try await wait(camera) { camera.canCapture }
          guard camera.switchPhase == .idle else {
            throw SmokeError.failed("Cancelled switch left the iris active")
          }
          report["switchCancellation"] = "passed: cancel during input replacement; session resumed"
        }
        camera.deactivate()
        try await Task.sleep(for: .milliseconds(500))
        await camera.activate()
        try await wait(camera) { camera.canCapture }
        let resumedCount = camera.library.items.count
        camera.shutter()
        try await wait(camera) { camera.library.items.count > resumedCount && camera.canCapture }
        report["sessionRecovery"] = "passed: stop/start followed by real capture"
        report["result"] = "passed"
      } catch {
        report["result"] = "failed"
        report["error"] = String(describing: error)
      }
      report["finishedAt"] = ISO8601DateFormatter().string(from: .now)
      write()
    }

    private static func wait(
      _ camera: CameraStore, timeout: TimeInterval = 20,
      until predicate: () -> Bool
    ) async throws {
      let deadline = Date.now.addingTimeInterval(timeout)
      while !predicate() {
        if let error = camera.message ?? camera.unavailable { throw SmokeError.failed(error) }
        guard Date.now < deadline else { throw SmokeError.failed("Timed out waiting for capture") }
        try await Task.sleep(for: .milliseconds(100))
      }
    }

    private enum SmokeError: Error { case failed(String) }
  }
#endif
