import XCTest

final class CameraSixUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  @MainActor
  private func launch(
    _ language: String = "en", preserve: Bool = false, reduceMotion: Bool = false
  ) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = [
      "--ui-testing", "-AppleLanguages", "(\(language))", "-AppleLocale",
      language == "en" ? "en_US" : "zh_CN",
    ]
    if preserve { app.launchArguments.append("--preserve-test-roll") }
    if reduceMotion { app.launchArguments.append("--reduce-motion") }
    app.launch()
    XCTAssertTrue(app.buttons["shutter"].waitForExistence(timeout: 15))
    return app
  }

  @MainActor
  func testSwitchRoundTripsInPhotoAndVideoIncludingReduceMotion() throws {
    #if !targetEnvironment(simulator)
      throw XCTSkip("Deterministic demo workflow; physical switching is checked separately.")
    #endif
    for reduceMotion in [false, true] {
      let app = launch(reduceMotion: reduceMotion)
      func switchTo(_ camera: String) {
        app.buttons["switch-camera"].tap()
        let predicate = NSPredicate(format: "value == %@ AND enabled == true", camera)
        let expectation = XCTNSPredicateExpectation(
          predicate: predicate, object: app.buttons["switch-camera"])
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
        XCTAssertTrue(app.buttons["shutter"].isEnabled)
        if app.buttons["options-button"].exists {
          XCTAssertTrue(app.buttons["options-button"].isEnabled)
        }
      }
      switchTo("Front camera")
      app.buttons["shutter"].tap()
      switchTo("Back camera")
      app.buttons["shutter"].tap()
      app.buttons["video-mode"].tap()
      switchTo("Front camera")
      switchTo("Back camera")
      app.buttons["shutter"].tap()
      XCTAssertTrue(app.buttons["video-snapshot"].waitForExistence(timeout: 5))
      XCTAssertFalse(app.buttons["switch-camera"].isEnabled)
      app.buttons["shutter"].tap()
      app.buttons["camera-roll"].tap()
      XCTAssertTrue(app.staticTexts["3 items"].waitForExistence(timeout: 8))
      app.terminate()
    }
  }

  @MainActor
  func testPhotoOptionsHDRGalleryEditingAndPersistence() throws {
    #if !targetEnvironment(simulator)
      throw XCTSkip("Simulator workflow; hardware capture is covered separately.")
    #endif
    let app = launch()
    app.buttons["options-button"].tap()
    app.buttons["grid-switch"].tap()
    app.buttons["hdr-switch"].tap()
    XCTAssertEqual(app.buttons["hdr-switch"].value as? String, "On")
    app.buttons["options-button"].tap()
    app.buttons["shutter"].tap()
    app.buttons["camera-roll"].tap()
    XCTAssertTrue(app.staticTexts["2 items"].waitForExistence(timeout: 8))
    capture("roll-english-grid")
    app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'media-'")).firstMatch.tap()
    XCTAssertTrue(app.images["photo-detail"].waitForExistence(timeout: 5))
    capture("roll-english-viewer")
    app.buttons["edit-photo"].tap()
    capture("roll-english-editor")
    app.buttons["editor-rotate"].tap()
    app.buttons["editor-crop 4:3"].tap()
    app.buttons["Save"].tap()
    XCTAssertTrue(app.buttons["edit-photo"].waitForExistence(timeout: 5))
    app.buttons["navigation-back"].tap()
    XCTAssertTrue(app.staticTexts["3 items"].waitForExistence(timeout: 5))
    app.terminate()
    let reopened = launch(preserve: true)
    reopened.buttons["camera-roll"].tap()
    XCTAssertTrue(reopened.staticTexts["3 items"].waitForExistence(timeout: 5))
    reopened.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'media-'")).firstMatch
      .tap()
    reopened.buttons["delete-media"].tap()
    reopened.buttons["Cancel"].tap()
    XCTAssertTrue(reopened.buttons["delete-media"].exists)
    reopened.buttons["delete-media"].tap()
    reopened.buttons["alert-confirm"].tap()
    XCTAssertTrue(reopened.staticTexts["2 items"].waitForExistence(timeout: 5))
  }

  @MainActor
  func testChineseVideoSnapshotAndPanorama() throws {
    #if !targetEnvironment(simulator)
      throw XCTSkip("Simulator workflow; hardware capture is covered separately.")
    #endif
    let app = launch("zh-Hant")
    XCTAssertEqual(app.buttons["shutter"].label, "拍照")
    app.buttons["video-mode"].tap()
    XCTAssertTrue(app.buttons["shutter"].waitForExistence(timeout: 5))
    app.buttons["shutter"].tap()
    XCTAssertTrue(app.buttons["video-snapshot"].waitForExistence(timeout: 5))
    app.buttons["video-snapshot"].tap()
    XCTAssertTrue(app.buttons["shutter"].isEnabled)
    app.buttons["shutter"].tap()
    XCTAssertTrue(app.buttons["photo-mode"].waitForExistence(timeout: 8))
    app.buttons["photo-mode"].tap()
    app.buttons["options-button"].tap()
    app.buttons["panorama-button"].tap()
    XCTAssertTrue(app.buttons["panorama-direction"].waitForExistence(timeout: 5))
    app.buttons["panorama-direction"].tap()
    XCTAssertEqual(app.buttons["panorama-direction"].value as? String, "从右向左")
    app.buttons["shutter"].tap()
    app.buttons["shutter"].tap()
    XCTAssertTrue(app.buttons["camera-roll"].isEnabled)
    app.buttons["camera-roll"].tap()
    XCTAssertTrue(app.staticTexts["3 个项目"].waitForExistence(timeout: 8))
    capture("roll-chinese-grid")
    XCUIDevice.shared.orientation = .landscapeLeft
    let photosReady = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "hittable == true"), object: app.buttons["open-photos"])
    XCTAssertEqual(XCTWaiter.wait(for: [photosReady], timeout: 5), .completed)
    XCTAssertTrue(app.buttons["navigation-back"].isHittable)
    capture("roll-chinese-landscape")
    XCUIDevice.shared.orientation = .portrait
    app.buttons["navigation-back"].tap()
    XCTAssertTrue(app.buttons["shutter"].waitForExistence(timeout: 5))
  }

  @MainActor
  func testFocusLockSwitchCameraSettingsAndBothLandscapeDirections() throws {
    #if !targetEnvironment(simulator)
      throw XCTSkip("Simulator workflow; hardware capture is covered separately.")
    #endif
    let app = launch("zh-Hans")
    let viewfinder = app.otherElements["viewfinder"]
    XCTAssertTrue(viewfinder.waitForExistence(timeout: 5))
    viewfinder.press(forDuration: 0.8)
    XCTAssertTrue(app.staticTexts["focus-lock"].waitForExistence(timeout: 5))
    viewfinder.tap()
    XCTAssertFalse(app.staticTexts["focus-lock"].exists)
    viewfinder.pinch(withScale: 2, velocity: 1)
    XCTAssertTrue(app.sliders["zoom-slider"].waitForExistence(timeout: 5))
    app.buttons["switch-camera"].tap()
    let switched = NSPredicate(format: "value == %@ AND enabled == true", "前置摄像头")
    XCTAssertTrue(
      XCTWaiter.wait(
        for: [
          XCTNSPredicateExpectation(
            predicate: switched,
            object: app.buttons["switch-camera"])
        ], timeout: 5) == .completed)
    XCUIDevice.shared.orientation = .landscapeLeft
    XCTAssertTrue(app.buttons["shutter"].isHittable)
    capture("zh-landscape-left")
    XCUIDevice.shared.orientation = .landscapeRight
    XCTAssertTrue(app.buttons["shutter"].isHittable)
    capture("zh-landscape-right")
    XCUIDevice.shared.orientation = .portrait
    app.buttons["options-button"].tap()
    app.buttons["camera-settings"].tap()
    XCTAssertTrue(app.buttons["keep-normal-photo-switch"].waitForExistence(timeout: 5))
    capture("zh-settings")
    app.buttons["完成"].tap()
    XCTAssertTrue(app.buttons["shutter"].waitForExistence(timeout: 5))
    capture("zh-photo")
    XCUIDevice.shared.press(.home)
    app.activate()
    XCTAssertTrue(app.buttons["shutter"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["shutter"].isEnabled)
    app.otherElements["viewfinder"].swipeRight()
    XCTAssertTrue(app.staticTexts["没有照片或视频"].waitForExistence(timeout: 5))
    capture("roll-chinese-empty")
    app.buttons["navigation-back"].tap()
    XCTAssertTrue(app.buttons["shutter"].waitForExistence(timeout: 5))
  }

  @MainActor
  func testPhysicalCameraPhotoVideoAndBackgroundRecovery() throws {
    #if targetEnvironment(simulator)
      throw XCTSkip("Requires a physical iPhone with camera and microphone.")
    #else
      addUIInterruptionMonitor(withDescription: "Camera and Microphone permissions") { alert in
        for label in ["Allow", "OK", "允许", "好"] {
          if alert.buttons[label].exists {
            alert.buttons[label].tap()
            return true
          }
        }
        return false
      }
      let app = launch()
      if !app.buttons["shutter"].isEnabled { app.tap() }
      XCTAssertTrue(app.buttons["shutter"].waitForExistence(timeout: 15))
      let ready = NSPredicate(format: "enabled == true")
      expectation(for: ready, evaluatedWith: app.buttons["shutter"])
      waitForExpectations(timeout: 15)
      capture("device-live-preview")
      app.buttons["shutter"].tap()
      app.buttons["camera-roll"].tap()
      XCTAssertTrue(app.staticTexts["1 item"].waitForExistence(timeout: 10))
      app.buttons["Camera"].tap()
      app.buttons["video-mode"].tap()
      app.tap()
      app.buttons["shutter"].tap()
      XCTAssertTrue(app.buttons["video-snapshot"].waitForExistence(timeout: 10))
      capture("device-recording")
      app.buttons["video-snapshot"].tap()
      sleep(2)
      app.buttons["shutter"].tap()
      XCTAssertTrue(app.buttons["photo-mode"].waitForExistence(timeout: 10))
      app.buttons["camera-roll"].tap()
      XCTAssertTrue(app.staticTexts["3 items"].waitForExistence(timeout: 10))
      capture("device-camera-roll")
      app.buttons["Camera"].tap()
      XCUIDevice.shared.press(.home)
      app.activate()
      XCTAssertTrue(app.buttons["shutter"].waitForExistence(timeout: 10))
    #endif
  }

  @MainActor
  private func capture(_ name: String) {
    Thread.sleep(forTimeInterval: 0.8)
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
