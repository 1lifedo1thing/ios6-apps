import XCTest

final class PhotosSixUITests: XCTestCase {
  private func launch(_ language: String = "en", demo: Bool = true) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments =
      (demo ? ["--ui-testing"] : []) + [
        "-AppleLanguages", "(\(language))", "-AppleLocale",
        language.hasPrefix("zh") ? "zh_CN" : "en_US",
      ]
    app.launch()
    return app
  }
  private func capture(_ name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
  private func openRoll(_ app: XCUIApplication) {
    XCTAssertTrue(app.buttons["album-roll"].waitForExistence(timeout: 10))
    app.buttons["album-roll"].tap()
    let grid = app.scrollViews["photo-grid"]
    XCTAssertTrue(grid.waitForExistence(timeout: 10))
    grid.swipeDown()
    XCTAssertTrue(app.buttons["photo-demo-0"].waitForExistence(timeout: 10))
  }
  func testEnglishBrowseEditingSlideshowAndShare() {
    let app = launch()
    capture("english-albums")
    openRoll(app)
    capture("english-grid")
    app.buttons["photo-demo-0"].tap()
    XCTAssertTrue(app.buttons["next-photo"].waitForExistence(timeout: 8))
    capture("english-viewer")
    app.buttons["next-photo"].tap()
    app.buttons["previous-photo"].tap()
    app.buttons["edit-photo"].tap()
    XCTAssertTrue(app.buttons["editor-Rotate"].waitForExistence(timeout: 10))
    app.buttons["editor-Rotate"].tap()
    app.buttons["editor-Crop"].tap()
    capture("photo-editor")
    app.buttons["save-edit"].tap()
    XCTAssertTrue(app.buttons["slideshow"].waitForExistence(timeout: 15))
    app.buttons["slideshow"].tap()
    app.buttons["start-slideshow"].tap()
    XCTAssertTrue(app.buttons["Stop Slideshow"].waitForExistence(timeout: 10))
    app.buttons["Stop Slideshow"].tap()
    app.buttons["share-photo"].tap()
    capture("classic-share")
    app.buttons["Cancel"].tap()
    app.buttons["viewer-back"].tap()
    XCTAssertTrue(app.buttons["photo-demo-0"].waitForExistence(timeout: 5))
  }
  func testCreateAlbumSelectRenameAndDelete() {
    let app = launch()
    app.buttons["new-album"].tap()
    let field = app.textFields["album-name"]
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.tap()
    field.typeText("Test Trip")
    app.buttons["save-album"].tap()
    XCTAssertTrue(app.buttons["photo-demo-0"].waitForExistence(timeout: 10))
    app.buttons["photo-demo-0"].tap()
    app.buttons["edit-done"].tap()
    XCTAssertTrue(app.buttons["photo-demo-0"].waitForExistence(timeout: 10))
    capture("new-album-selected")
    app.buttons["albums-back"].tap()
    XCTAssertTrue(app.staticTexts["Test Trip"].waitForExistence(timeout: 10))
    app.buttons["edit-done"].tap()
    app.staticTexts["Test Trip"].tap()
    XCTAssertTrue(app.textFields["album-name"].waitForExistence(timeout: 5))
    app.buttons["Cancel"].tap()
    app.buttons["edit-done"].tap()
  }
  func testChinesePlacesSettingsAndLandscape() {
    let app = launch("zh-Hant-TW")
    XCTAssertTrue(app.staticTexts["相机胶卷"].waitForExistence(timeout: 10))
    capture("chinese-albums")
    app.buttons["tab-Places"].tap()
    capture("chinese-places")
    app.buttons["photo-settings"].tap()
    XCTAssertTrue(app.buttons["打开相机"].waitForExistence(timeout: 5))
    let settingsTitle = app.staticTexts["photo-settings-title"]
    XCTAssertTrue(settingsTitle.exists)
    XCTAssertEqual(settingsTitle.frame.midX, app.frame.midX, accuracy: 1)
    XCTAssertGreaterThan(app.buttons["photo-settings-done"].frame.minX, settingsTitle.frame.maxX)
    capture("chinese-settings")
    app.buttons["完成"].tap()
    app.buttons["tab-Albums"].tap()
    openRoll(app)
    XCUIDevice.shared.orientation = .landscapeLeft
    capture("chinese-landscape-grid")
    XCTAssertTrue(app.buttons["photo-demo-0"].exists)
    XCUIDevice.shared.orientation = .portrait
  }
  func testVideoPlaybackAndTrim() {
    let app = launch()
    app.buttons["album-videos"].tap()
    app.buttons["photo-demo-video"].tap()
    XCTAssertTrue(app.buttons["edit-photo"].waitForExistence(timeout: 10))
    capture("video-viewer")
    app.buttons["edit-photo"].tap()
    XCTAssertTrue(app.sliders["trim-start"].waitForExistence(timeout: 10))
    app.sliders["trim-start"].adjust(toNormalizedSliderPosition: 0.2)
    app.sliders["trim-end"].adjust(toNormalizedSliderPosition: 0.75)
    capture("video-trim")
    app.buttons["save-edit"].tap()
    XCTAssertTrue(app.buttons["viewer-back"].waitForExistence(timeout: 20))
  }
}
