import XCTest

final class CompassSixUITests: XCTestCase {
  private let app = XCUIApplication()

  override func setUp() {
    super.setUp()
    continueAfterFailure = false
    XCUIDevice.shared.orientation = .portrait
  }

  override func tearDown() {
    XCUIDevice.shared.orientation = .portrait
    app.terminate()
    super.tearDown()
  }

  private func launch(_ language: String = "en", extra: [String] = []) {
    app.launchArguments =
      [
        "--uitesting", "-AppleLanguages", "(\(language))", "-AppleLocale",
        language.hasPrefix("zh") ? "zh_CN" : "en_US",
      ] + extra
    app.launch()
    XCTAssertTrue(app.buttons["compass-settings"].waitForExistence(timeout: 10))
  }

  private var heading: XCUIElement { app.staticTexts["heading-readout"] }

  private func capture(_ name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  func testEnglishPreviewRotationAndNorthSettingsReturnAndReopen() {
    launch()
    XCTAssertEqual(heading.value as? String, "222° SW")
    XCTAssertEqual(app.staticTexts["coordinates"].value as? String, "37°19′19″ N, 122°1′41″ W")
    XCTAssertFalse(app.buttons["open-maps"].isEnabled)
    capture("en-portrait")
    app.buttons["preview-right"].tap()
    XCTAssertEqual(heading.value as? String, "237° SW")
    app.buttons["compass-settings"].tap()
    XCTAssertTrue(app.buttons["north-trueNorth"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.buttons["north-magnetic"].value as? String, "Selected")
    app.buttons["north-trueNorth"].tap()
    XCTAssertEqual(app.buttons["north-trueNorth"].value as? String, "Selected")
    capture("en-settings")
    app.buttons["settings-done"].tap()
    XCTAssertTrue(heading.waitForExistence(timeout: 3))
    XCTAssertEqual(heading.value as? String, "250° W")
    XCTAssertTrue(app.buttons["preview-right"].isHittable)
    app.buttons["compass-settings"].tap()
    XCTAssertTrue(app.buttons["north-magnetic"].waitForExistence(timeout: 3))
    app.buttons["north-magnetic"].tap()
    app.buttons["settings-done"].tap()
    XCTAssertEqual(heading.value as? String, "237° SW")
  }

  func testChineseVariantsBothLandscapeDirectionsAndControlGeometry() {
    launch("zh-Hant")
    XCTAssertEqual(heading.label, "方位角")
    XCTAssertEqual(heading.value as? String, "222° 西南")
    XCTAssertEqual(app.buttons["compass-settings"].label, "指南针设置")
    capture("zh-portrait")
    for orientation in [UIDeviceOrientation.landscapeLeft, .landscapeRight] {
      XCUIDevice.shared.orientation = orientation
      XCTAssertTrue(heading.waitForExistence(timeout: 4))
      for identifier in ["compass-settings", "open-maps", "preview-left", "preview-right"] {
        let control = app.buttons[identifier]
        XCTAssertTrue(app.frame.contains(control.frame), identifier)
        // Accessibility frames may round a 44-point edge slightly below 44.
        XCTAssertGreaterThanOrEqual(control.frame.height + 0.000001, 44, identifier)
        XCTAssertGreaterThanOrEqual(control.frame.width + 0.000001, 44, identifier)
      }
      capture(orientation == .landscapeLeft ? "zh-landscape-left" : "zh-landscape-right")
      let dial = app.descendants(matching: .any)["compass-dial"]
      XCTAssertTrue(dial.exists, app.debugDescription)
      XCTAssertTrue(app.frame.contains(dial.frame), "Dial: \(dial.frame); App: \(app.frame)")
    }
    app.buttons["compass-settings"].tap()
    XCTAssertTrue(app.buttons["north-trueNorth"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.buttons["north-trueNorth"].label, "真北")
    capture("zh-landscape-settings")
  }

  func testDeniedLocationKeepsMagneticHeadingAndTrueNorthUnavailable() {
    launch("zh-Hans", extra: ["--denied"])
    XCTAssertEqual(heading.value as? String, "222° 西南")
    XCTAssertTrue(app.buttons["location-unavailable"].exists)
    XCTAssertFalse(app.buttons["open-maps"].isEnabled)
    app.buttons["compass-settings"].tap()
    XCTAssertTrue(app.buttons["open-settings"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.buttons["open-settings"].label, "打开设置")
    app.buttons["north-trueNorth"].tap()
    app.buttons["settings-done"].tap()
    XCTAssertEqual(heading.value as? String, "不可用")
    XCTAssertTrue(app.staticTexts["heading-status"].label.contains("真北需要"))
    capture("zh-denied-true-north")
    app.buttons["compass-help"].tap()
    app.buttons["north-magnetic"].tap()
    app.buttons["settings-done"].tap()
    XCTAssertEqual(heading.value as? String, "222° 西南")
  }

  func testInvalidHeadingShowsCalibrationHelp() {
    launch("en", extra: ["--invalid"])
    XCTAssertEqual(heading.value as? String, "Unavailable")
    XCTAssertTrue(app.staticTexts["heading-status"].label.contains("calibrate"))
    capture("en-calibration")
    app.buttons["compass-help"].tap()
    XCTAssertTrue(app.buttons["settings-done"].waitForExistence(timeout: 3))
    app.buttons["settings-done"].tap()
    XCTAssertTrue(app.buttons["compass-help"].isHittable)
  }

  func testFallbackLargeTextAndPersistentNorthPreference() {
    launch(
      "fr",
      extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
    XCTAssertEqual(heading.label, "Heading")
    app.buttons["compass-settings"].tap()
    app.buttons["north-trueNorth"].tap()
    capture("fallback-large-text-settings")
    app.buttons["settings-done"].tap()
    app.terminate()
    launch("en", extra: ["--preserve-preferences"])
    XCTAssertEqual(heading.value as? String, "235° SW")
    app.buttons["compass-settings"].tap()
    XCTAssertEqual(app.buttons["north-trueNorth"].value as? String, "Selected")
  }
}
