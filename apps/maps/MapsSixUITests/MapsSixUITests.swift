import XCTest

final class MapsSixUITests: XCTestCase {
  override func tearDown() {
    XCUIDevice.shared.orientation = .portrait
    super.tearDown()
  }
  private func launch(_ language: String = "en", fixture: Bool = true) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments =
      (fixture ? ["--ui-testing"] : []) + ["--skip-initial-location"] + [
        "-AppleLanguages", "(\(language))", "-AppleLocale",
        language.hasPrefix("zh") ? "zh_CN" : "en_US",
      ]
    app.launch()
    XCTAssertTrue(app.buttons["map-options"].waitForExistence(timeout: 15))
    return app
  }
  private func capture(_ name: String) {
    RunLoop.current.run(until: Date().addingTimeInterval(0.6))
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
  private func landmark(_ app: XCUIApplication, id: String = "ferry") {
    app.buttons["bookmarks"].tap()
    waitForPanel(app)
    app.buttons["bookmarks-tab-2"].tap()
    XCTAssertTrue(app.buttons["place-\(id)"].waitForExistence(timeout: 5))
    app.buttons["place-\(id)"].tap()
    XCTAssertTrue(app.buttons["place-info"].waitForExistence(timeout: 5))
  }
  private func waitForPanel(_ app: XCUIApplication) {
    let title = app.staticTexts["panel-title"]
    let centered = NSPredicate { _, _ in title.exists && abs(title.frame.midX - app.frame.midX) < 2
    }
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [XCTNSPredicateExpectation(predicate: centered, object: nil)], timeout: 5), .completed)
    RunLoop.current.run(until: Date().addingTimeInterval(0.4))
  }
  func testBookmarkChromeSelectionAndDismissal() {
    for language in ["en", "zh-Hant-TW"] {
      let app = launch(language)
      let chinese = language.hasPrefix("zh")
      app.buttons["bookmarks"].tap()
      waitForPanel(app)
      let title = app.staticTexts["panel-title"]
      let firstTab = app.buttons["bookmarks-tab-0"]
      let done = app.buttons["panel-done"]
      XCTAssertEqual(title.label, chinese ? "书签" : "Bookmarks")
      XCTAssertTrue(firstTab.isSelected)
      XCTAssertTrue(done.isHittable)
      XCTAssertGreaterThan(firstTab.frame.minY, app.frame.midY)
      capture("\(language)-bookmarks-chrome")

      app.buttons["bookmarks-tab-2"].tap()
      XCTAssertEqual(title.label, chinese ? "地标" : "Landmarks")
      XCTAssertTrue(app.buttons["bookmarks-tab-2"].isSelected)
      XCTAssertFalse(firstTab.isSelected)
      capture("\(language)-landmarks-chrome")
      XCUIDevice.shared.orientation = .landscapeLeft
      waitForPanel(app)
      XCTAssertTrue(done.isHittable)
      XCTAssertTrue(app.buttons["bookmarks-tab-2"].isHittable)
      XCTAssertGreaterThan(firstTab.frame.minY, title.frame.maxY)
      capture("\(language)-bookmarks-landscape")
      XCUIDevice.shared.orientation = .portrait
      waitForPanel(app)
      app.buttons["place-ferry"].tap()
      XCTAssertTrue(app.buttons["place-info"].waitForExistence(timeout: 5))

      app.buttons["bookmarks"].tap()
      waitForPanel(app)
      app.buttons["bookmarks-tab-1"].tap()
      XCTAssertEqual(title.label, chinese ? "最近记录" : "Recents")
      XCTAssertTrue(app.buttons["clear-recents"].isEnabled)
      capture("\(language)-recents-chrome")
      app.buttons["clear-recents"].tap()
      XCTAssertFalse(app.buttons["clear-recents"].isEnabled)
      XCTAssertTrue(app.staticTexts[chinese ? "没有最近记录" : "No Recent Searches"].exists)
      done.tap()
      XCTAssertTrue(app.buttons["bookmarks"].waitForExistence(timeout: 5))
      app.buttons["bookmarks"].tap()
      waitForPanel(app)
      XCTAssertTrue(firstTab.isSelected)
      done.tap()
      app.terminate()
    }
  }
  func testSearchHidesControlsAndRestoresTheirPosition() {
    for language in ["en", "zh-Hant-TW"] {
      let app = launch(language)
      let locate = app.buttons["locate"]
      let threeD = app.buttons["three-d"]
      let corner = app.buttons["map-options"]
      let field = app.textFields["map-search"]
      let cancel = app.buttons["cancel-search"]
      let keyboard = app.keyboards.firstMatch

      func checkMapControls(bottom: CGFloat? = nil) {
        let ready = NSPredicate { _, _ in
          locate.isHittable && threeD.isHittable && corner.isHittable
            && (bottom.map { abs(locate.frame.maxY - $0) < 2 } ?? true)
        }
        XCTAssertEqual(
          XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: ready, object: nil)], timeout: 5),
          .completed)
        XCTAssertEqual(locate.frame.maxY, threeD.frame.maxY, accuracy: 1)
        XCTAssertEqual(corner.frame.maxX, app.frame.maxX, accuracy: 1)
        XCTAssertEqual(corner.frame.maxY, app.frame.maxY, accuracy: 1)
      }
      func checkSearchControls() {
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        XCTAssertFalse(locate.exists)
        XCTAssertFalse(threeD.exists)
        XCTAssertFalse(corner.exists)
      }

      checkMapControls()
      let portraitBottom = locate.frame.maxY
      capture("\(language)-complete-corner")
      field.tap()
      checkSearchControls()
      let firstResult = app.buttons["place-ferry"]
      XCTAssertTrue(firstResult.isHittable)
      capture("\(language)-search-empty-keyboard")
      field.typeText("Ferry")
      checkSearchControls()
      XCTAssertTrue(app.buttons["submit-search"].isHittable)
      XCTAssertTrue(firstResult.isHittable)
      capture("\(language)-search-first-result")
      firstResult.tap()
      XCTAssertTrue(app.buttons["place-info"].waitForExistence(timeout: 5))
      checkMapControls(bottom: portraitBottom)
      capture("\(language)-search-selection-restored")

      for orientation in [UIDeviceOrientation.landscapeLeft, .landscapeRight] {
        XCUIDevice.shared.orientation = orientation
        checkMapControls()
        let landscapeBottom = locate.frame.maxY
        field.tap()
        checkSearchControls()
        capture("\(language)-search-\(orientation.rawValue)")
        cancel.tap()
        checkMapControls(bottom: landscapeBottom)
      }
      XCUIDevice.shared.orientation = .portrait
      checkMapControls(bottom: portraitBottom)
      app.terminate()
    }
  }
  func testEnglishBookmarkDetailsAndPersistence() {
    let app = launch()
    capture("english-map")
    landmark(app)
    capture("english-pin-bubble")
    app.buttons["place-info"].tap()
    waitForPanel(app)
    XCTAssertEqual(app.staticTexts["place-title"].label, "Ferry Building")
    app.buttons["toggle-bookmark"].tap()
    XCTAssertTrue(app.buttons["Remove Bookmark"].waitForExistence(timeout: 5))
    capture("english-place-details")
    app.buttons["Back"].tap()
    RunLoop.current.run(until: Date().addingTimeInterval(0.4))
    app.buttons["bookmarks"].tap()
    waitForPanel(app)
    XCTAssertTrue(app.buttons["place-ferry"].waitForExistence(timeout: 5))
    app.terminate()
    app.launchArguments += ["--preserve-preferences"]
    app.launch()
    app.buttons["bookmarks"].tap()
    waitForPanel(app)
    XCTAssertTrue(app.buttons["place-ferry"].waitForExistence(timeout: 5))
  }
  func testOptionsModesDropPinAndSettings() {
    let app = launch()
    app.buttons["map-options"].tap()
    XCTAssertTrue(app.buttons["drop-pin"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.buttons["map-options"].label, "Close Map Options")
    XCTAssertTrue(app.buttons["drop-pin"].isHittable)
    capture("english-page-curl")
    app.buttons["style-Satellite"].tap()
    app.buttons["style-Hybrid"].tap()
    app.buttons["traffic"].tap()
    XCTAssertEqual(app.buttons["traffic"].label, "Hide Traffic")
    app.buttons["map-settings"].tap()
    app.buttons["units-Miles"].tap()
    XCTAssertTrue(app.buttons["units-Miles"].isSelected)
    app.buttons["voice-navigation"].tap()
    XCTAssertEqual(app.buttons["voice-navigation"].value as? String, "Off")
    capture("english-settings")
    app.buttons["Back"].tap()
    XCTAssertTrue(app.buttons["bookmarks"].waitForExistence(timeout: 5))
    RunLoop.current.run(until: Date().addingTimeInterval(0.4))
    app.buttons["map-options"].tap()
    XCTAssertTrue(app.buttons["drop-pin"].waitForExistence(timeout: 5))
    app.buttons["drop-pin"].tap()
    XCTAssertTrue(app.buttons["place-info"].waitForExistence(timeout: 5))
    app.buttons["place-info"].tap()
    XCTAssertTrue(app.buttons["Remove Pin"].waitForExistence(timeout: 5))
    app.buttons["Remove Pin"].tap()
    XCTAssertTrue(app.buttons["map-options"].waitForExistence(timeout: 5))
  }
  func testFullScreenMapInteractionAndModes() {
    let app = launch()
    let map = app.descendants(matching: .any)["classic-map"]
    XCTAssertTrue(map.waitForExistence(timeout: 5))
    XCTAssertEqual(map.frame.minY, app.frame.minY, accuracy: 1)
    XCTAssertEqual(map.frame.maxY, app.frame.maxY, accuracy: 1)
    capture("full-screen-standard-map")
    map.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.55))
      .press(forDuration: 1.2)
    XCTAssertTrue(app.buttons["place-info"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Dropped Pin"].exists)

    for style in ["Satellite", "Hybrid", "Standard"] {
      app.buttons["map-options"].tap()
      XCTAssertTrue(app.buttons["style-\(style)"].waitForExistence(timeout: 5))
      app.buttons["style-\(style)"].tap()
      XCTAssertTrue(app.buttons["style-\(style)"].isSelected)
      app.buttons["map-options"].tap()
      XCTAssertTrue(app.buttons["bookmarks"].waitForExistence(timeout: 5))
      RunLoop.current.run(until: Date().addingTimeInterval(1))
      capture("full-screen-\(style)-map")
    }
    XCUIDevice.shared.orientation = .landscapeRight
    let bookmarkReady = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "hittable == true"), object: app.buttons["bookmarks"])
    XCTAssertEqual(XCTWaiter.wait(for: [bookmarkReady], timeout: 5), .completed)
    capture("full-screen-landscape-map")
    app.buttons["bookmarks"].tap()
    waitForPanel(app)
    XCTAssertTrue(app.buttons["panel-done"].isHittable)
    app.buttons["panel-done"].tap()
  }
  func testDirectionsNavigationStepsAndReopen() {
    let app = launch()
    landmark(app, id: "coit")
    app.buttons["bubble-directions"].tap()
    XCTAssertFalse(app.buttons["bookmarks"].isHittable)
    capture("english-directions")
    app.buttons["calculate-route"].tap()
    XCTAssertTrue(app.buttons["start-navigation"].waitForExistence(timeout: 10))
    capture("english-route")
    app.buttons["route-list"].tap()
    XCTAssertTrue(app.staticTexts["Turn left onto Broadway"].exists)
    app.buttons["Back"].tap()
    app.buttons["start-navigation"].tap()
    XCTAssertTrue(app.buttons["end-navigation"].waitForExistence(timeout: 5))
    capture("english-navigation")
    app.buttons["next-step"].tap()
    app.buttons["end-navigation"].tap()
    XCTAssertTrue(app.buttons["start-navigation"].waitForExistence(timeout: 5))
  }
  func testChineseVariantSearchAndLandscape() {
    let app = launch("zh-Hant-TW")
    XCTAssertEqual(app.textFields["map-search"].placeholderValue, "搜索或地址")
    landmark(app)
    XCTAssertTrue(app.staticTexts["渡轮大厦"].exists)
    capture("chinese-place")
    app.buttons["map-options"].tap()
    capture("chinese-page-curl")
    XCUIDevice.shared.orientation = .landscapeLeft
    XCTAssertTrue(app.buttons["style-Standard"].waitForExistence(timeout: 5))
    capture("chinese-landscape-options")
    app.buttons["map-options"].tap()
    app.buttons["three-d"].tap()
    capture("chinese-landscape-map")
    XCUIDevice.shared.orientation = .portrait
    capture("chinese-portrait-after-rotation")
    app.textFields["map-search"].tap()
    if !app.buttons["cancel-search"].waitForExistence(timeout: 2) {
      app.textFields["map-search"].tap()
    }
    XCTAssertTrue(app.buttons["cancel-search"].waitForExistence(timeout: 5))
    app.textFields["map-search"].typeText("zzzznoresults")
    app.buttons["submit-search"].tap()
    XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
    app.alerts.buttons["好"].tap()
    app.buttons["cancel-search"].tap()
    XCTAssertTrue(app.buttons["bookmarks"].waitForExistence(timeout: 5))
  }
  func testLiveAppleSearchAndWalkingRoute() {
    let app = launch("en", fixture: false)
    let field = app.textFields["map-search"]
    field.tap()
    field.typeText("Ferry Building San Francisco")
    app.buttons["submit-search"].tap()
    XCTAssertTrue(app.buttons["place-info"].waitForExistence(timeout: 35))
    capture("live-apple-search")
    app.buttons["bubble-directions"].tap()
    let origin = app.textFields["route-origin"]
    origin.tap()
    origin.typeText("Coit Tower San Francisco\n")
    app.buttons["transport-walking"].tap()
    app.buttons["calculate-route"].tap()
    XCTAssertTrue(app.buttons["start-navigation"].waitForExistence(timeout: 45))
    capture("live-apple-walking-route")
  }
}
