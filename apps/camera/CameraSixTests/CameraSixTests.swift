import AVFoundation
import UIKit
import Vision
import XCTest

@testable import CameraSix

final class CameraSixTests: XCTestCase {
  func testLanguageVariantsAndFallback() {
    for language in ["zh-Hans", "zh-Hant", "zh-TW", "zh-HK", "ZH-cn"] {
      XCTAssertEqual(AppLanguage.preferred([language]), .chinese)
    }
    for languages in [[], ["en-GB"], ["fr-FR", "zh-Hans"], ["ja-JP"]] {
      XCTAssertEqual(AppLanguage.preferred(languages), .english)
    }
    XCTAssertEqual(L10n.text("Camera Roll", language: .chinese), "相机胶卷")
    XCTAssertEqual(L10n.format("%d of %d", 1, 4, language: .chinese), "第 1 个，共 4 个")
    let preferred = Bundle.preferredLocalizations(
      from: Bundle.main.localizations, forPreferences: ["zh-Hant-TW"])
    XCTAssertTrue(preferred.first?.hasPrefix("zh") == true)
    for language in ["zh", "zh-Hans", "zh-Hant"] {
      let path = Bundle.main.path(forResource: language, ofType: "lproj")
      XCTAssertNotNil(path)
    }
  }

  func testFlashAndHDRMutualExclusionAndPersistence() throws {
    let name = "CameraSix-tests-\(UUID())"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    var settings = CameraSettings()
    settings.setHDR(true)
    XCTAssertEqual(settings.flash, .off)
    settings.setFlash(.auto)
    XCTAssertFalse(settings.hdr)
    settings.setHDR(true)
    settings.grid = true
    settings.keepNormal = false
    settings.save(defaults)
    XCTAssertEqual(CameraSettings.load(defaults), settings)
    defaults.set(Data([0xff]), forKey: CameraSettings.storageKey)
    XCTAssertEqual(CameraSettings.load(defaults), CameraSettings())
    XCTAssertEqual(CameraTiming.timecode(3661), "01:01:01")
  }

  @MainActor
  func testMediaSurvivesReopenAndLocalDeletion() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let library = MediaLibrary(directory: directory)
    let data = try XCTUnwrap(testImage().jpegData(compressionQuality: 0.95))
    let item = try await library.addPhoto(data, kind: .panorama, hdr: true)
    XCTAssertNotNil(library.thumbnail(for: item))
    let reopened = MediaLibrary(directory: directory)
    XCTAssertEqual(reopened.items.count, 1)
    XCTAssertEqual(reopened.items.first?.kind, .panorama)
    XCTAssertTrue(reopened.items.first?.isHDR ?? false)
    XCTAssertTrue(FileManager.default.fileExists(atPath: reopened.url(for: item).path))
    try reopened.removeLocal(item)
    XCTAssertTrue(MediaLibrary(directory: directory).items.isEmpty)
    XCTAssertFalse(FileManager.default.fileExists(atPath: reopened.url(for: item).path))
  }

  func testExposureFusionProducesUsableImageAndRejectsIncompleteBracket() throws {
    let image = testImage()
    let source = try XCTUnwrap(CIImage(image: image))
    let bracket: [Data] = try [-2.0, 0, 2.0].map { exposure in
      let output = source.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: exposure])
      let cgImage = try XCTUnwrap(
        ImageProcessing.context.createCGImage(output, from: source.extent))
      return try XCTUnwrap(UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.98))
    }
    let result = try XCTUnwrap(UIImage(data: ImageProcessing.fuseExposures(bracket)))
    XCTAssertEqual(result.size, image.size)
    XCTAssertGreaterThan(try XCTUnwrap(result.jpegData(compressionQuality: 0.9)).count, 500)
    XCTAssertThrowsError(try ImageProcessing.fuseExposures([bracket[0]]))
  }

  func testPanoramaRegistersOverlappingFramesAndRejectsSingleFrame() throws {
    let scene = try XCTUnwrap(testImage(width: 700, height: 220).cgImage)
    let left = try XCTUnwrap(scene.cropping(to: CGRect(x: 0, y: 0, width: 400, height: 220)))
    let right = try XCTUnwrap(scene.cropping(to: CGRect(x: 150, y: 0, width: 400, height: 220)))
    let request = VNTranslationalImageRegistrationRequest(targetedCGImage: right)
    try VNImageRequestHandler(cgImage: left).perform([request])
    let transform = try XCTUnwrap(request.results?.first?.alignmentTransform)
    XCTAssertEqual(abs(transform.tx), 150, accuracy: 25, "Measured transform: \(transform)")
    let panorama = PanoramaBuilder()
    try panorama.append(UIImage(cgImage: left))
    XCTAssertThrowsError(try panorama.finish())
    do { try panorama.append(UIImage(cgImage: right)) } catch {
      XCTFail("Append failed: \(error), measured transform: \(transform)")
      return
    }
    XCTAssertEqual(panorama.count, 2)
    let result: Data
    do { result = try panorama.finish() } catch {
      XCTFail("Finish failed: \(error), measured transform: \(transform), count: \(panorama.count)")
      return
    }
    let image = try XCTUnwrap(UIImage(data: result))
    XCTAssertGreaterThan(image.size.width, 500)
    XCTAssertLessThan(image.size.width, 590)
    XCTAssertGreaterThan(image.size.height, 200)
  }

  func testSimulatorVideoIsPlayable() async throws {
    let url = try await DemoMedia.video(image: testImage(), duration: 1)
    defer { try? FileManager.default.removeItem(at: url) }
    let asset = AVURLAsset(url: url)
    let duration = try await asset.load(.duration)
    let tracks = try await asset.loadTracks(withMediaType: .video)
    XCTAssertGreaterThan(duration.seconds, 0.8)
    XCTAssertEqual(tracks.count, 1)
  }

  private func testImage(width: Int = 320, height: Int = 240) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image
    { ctx in
      UIColor.darkGray.setFill()
      ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
      var state: UInt64 = 0xCa6e
      func next() -> Int {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return Int(state % UInt64(Int.max))
      }
      for index in 0..<180 {
        let x = next() % width
        let y = next() % height
        UIColor(
          hue: CGFloat(index % 17) / 17, saturation: 0.6, brightness: CGFloat(index % 7 + 2) / 9,
          alpha: 1
        ).setFill()
        ctx.fill(CGRect(x: x, y: y, width: 18 + index % 25, height: 13 + index % 17))
      }
    }
  }
}
