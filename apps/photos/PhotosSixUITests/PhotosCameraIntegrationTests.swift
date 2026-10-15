import XCTest

final class PhotosCameraIntegrationTests: XCTestCase {
  func testCaptureSaveOpenExactAssetAndReturnToCamera() throws {
    guard ProcessInfo.processInfo.environment["RUN_CAMERA_INTEGRATION"] == "1" else {
      throw XCTSkip(
        "Opt in after installing CameraSix and granting Photos permissions on the test simulator.")
    }
    continueAfterFailure = false
    let photos = XCUIApplication()
    photos.launchArguments = ["--demo", "-AppleLanguages", "(en)"]
    photos.launch()
    if photos.buttons["allow-library"].waitForExistence(timeout: 2) {
      photos.buttons["allow-library"].tap()
      let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
      let allow = springboard.buttons.matching(
        NSPredicate(
          format:
            "label CONTAINS[c] 'Full Access' OR label CONTAINS '完全访问' OR label CONTAINS '所有照片'")
      ).firstMatch
      if allow.waitForExistence(timeout: 5) { allow.tap() }
    }
    XCTAssertTrue(photos.buttons["album-roll"].waitForExistence(timeout: 10))
    let camera = XCUIApplication(bundleIdentifier: "com.yinyueyang.camerasix")
    camera.launchArguments = ["--ui-testing", "-AppleLanguages", "(en)"]
    camera.launch()
    XCTAssertTrue(camera.buttons["shutter"].waitForExistence(timeout: 10))
    let ready = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "enabled == true"), object: camera.buttons["shutter"])
    XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
    camera.buttons["shutter"].tap()
    camera.buttons["camera-roll"].tap()
    let thumbnail = camera.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'media-'"))
      .firstMatch
    XCTAssertTrue(thumbnail.waitForExistence(timeout: 10))
    thumbnail.tap()
    camera.buttons["open-photos"].tap()
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let allowSave = springboard.buttons.matching(
      NSPredicate(
        format:
          "label == 'Allow' OR label == '允许' OR label CONTAINS 'Add Photos' OR label CONTAINS '添加照片'"
      )
    ).firstMatch
    if allowSave.waitForExistence(timeout: 2) { allowSave.tap() }
    XCTAssertTrue(photos.buttons["viewer-back"].waitForExistence(timeout: 20))
    XCTAssertTrue(photos.buttons["edit-photo"].exists)
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = "camera-capture-in-photos"
    attachment.lifetime = .keepAlways
    add(attachment)
    photos.buttons["viewer-back"].tap()
    XCTAssertEqual(
      photos.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'photo-demo-'")).count, 0)
    photos.buttons["albums-back"].tap()
    photos.buttons["open-camera"].tap()
    XCTAssertTrue(camera.buttons["shutter"].waitForExistence(timeout: 10))
    XCTAssertTrue(camera.buttons["shutter"].isEnabled)
  }
}
