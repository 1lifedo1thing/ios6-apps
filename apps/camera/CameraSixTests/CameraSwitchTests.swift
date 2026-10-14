import SwiftUI
import XCTest

@testable import CameraSix

final class CameraSwitchTests: XCTestCase {
  func testIrisCoversEveryPointWhenClosedAndLeavesPreviewClearWhenOpen() {
    for size in [CGSize(width: 375, height: 500), CGSize(width: 560, height: 420)] {
      for closure in [0.0, 1.0] {
        let geometry = IrisGeometry(size: size, closure: closure)
        for x in stride(from: 2.0, to: size.width, by: 13) {
          for y in stride(from: 2.0, to: size.height, by: 13) {
            let covered = (0..<IrisGeometry.bladeCount).contains {
              geometry.blade($0).contains(CGPoint(x: x, y: y))
            }
            XCTAssertEqual(covered, closure == 1, "Iris coverage at \(x),\(y), closure \(closure)")
          }
        }
      }
    }
  }

  @MainActor
  func testSwitchDoesNotChangeCameraUntilClosedAndRejectsRepeatedRequests() async throws {
    #if !targetEnvironment(simulator)
      throw XCTSkip("Deterministic demo transition test")
    #endif
    let camera = CameraStore()
    await camera.activate()
    camera.switchCamera()
    XCTAssertEqual(camera.switchPhase, .closing)
    XCTAssertFalse(camera.front)
    XCTAssertFalse(camera.canCapture)
    camera.switchCamera()
    await camera.commitCameraSwitch()
    XCTAssertEqual(camera.switchPhase, .opening)
    XCTAssertTrue(camera.front)
    XCTAssertFalse(camera.canCapture)
    camera.finishCameraSwitch()
    XCTAssertEqual(camera.switchPhase, .idle)
    XCTAssertTrue(camera.canCapture)
    camera.switchCamera()
    camera.deactivate()
    await camera.commitCameraSwitch()
    XCTAssertEqual(camera.switchPhase, .idle)
    XCTAssertTrue(camera.front)
    await camera.activate()
    camera.switchCamera()
    let changing = Task { await camera.commitCameraSwitch() }
    await Task.yield()
    camera.deactivate()
    await changing.value
    XCTAssertEqual(camera.switchPhase, .idle)
    XCTAssertTrue(camera.front)
    await camera.activate()
    XCTAssertTrue(camera.canCapture)
  }

  @MainActor
  func testRenderIrisPhasesForVisualInspection() throws {
    for closure in [0.0, 0.25, 0.5, 0.75, 1.0] {
      let preview = ZStack {
        Color(red: 0.17, green: 0.48, blue: 0.62)
        IrisShutter(closure: closure)
      }.frame(width: 300, height: 400)
      let renderer = ImageRenderer(content: preview)
      renderer.scale = 2
      let image = try XCTUnwrap(renderer.uiImage)
      let attachment = XCTAttachment(image: image)
      attachment.name = "iris-\(Int(closure * 100))"
      attachment.lifetime = .keepAlways
      add(attachment)
    }
  }
}
