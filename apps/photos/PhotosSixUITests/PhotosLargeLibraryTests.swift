import XCTest

final class PhotosLargeLibraryTests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  private func launch(_ language: String, preserve: Bool = false) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = [
      "--ui-testing", "--large-library", "-AppleLanguages", "(\(language))", "-AppleLocale",
      language.hasPrefix("zh") ? "zh_CN" : "en_US",
    ]
    if preserve { app.launchArguments.append("--preserve-demo") }
    app.launch()
    XCTAssertTrue(app.buttons["album-roll"].waitForExistence(timeout: 15))
    app.buttons["album-roll"].tap()
    return app
  }

  private func capture(_ name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  private func assertNavigation(_ app: XCUIApplication) {
    let title = app.staticTexts["viewer-counter"]
    let back = app.buttons["viewer-back"]
    let edit = app.buttons["edit-photo"]
    XCTAssertTrue(title.waitForExistence(timeout: 10))
    XCTAssertLessThanOrEqual(back.frame.maxX, title.frame.minX)
    XCTAssertLessThanOrEqual(title.frame.maxX, edit.frame.minX)
    XCTAssertTrue(back.isHittable)
    XCTAssertTrue(edit.isHittable)
  }

  private func waitUntilHittable(_ element: XCUIElement) {
    let ready = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "hittable == true"), object: element)
    XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 8), .completed)
  }

  func testChineseLargeLibraryPositionReturnDeletionAndRelaunch() {
    let app = launch("zh-Hant-TW")
    XCTAssertTrue(app.buttons["photo-demo-6623"].waitForExistence(timeout: 15))
    XCTAssertTrue(app.buttons["photo-demo-6623"].isHittable)
    capture("large-latest-grid")
    let grid = app.scrollViews["photo-grid"]
    grid.swipeDown()
    grid.swipeDown()
    let visible = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'photo-demo-'"))
      .allElementsBoundByIndex.filter { $0.isHittable && $0.frame.height > 10 }
    XCTAssertFalse(visible.isEmpty)
    guard let marker = visible.dropFirst(visible.count / 2).first else { return }
    let id = marker.identifier
    let originalY = marker.frame.midY
    marker.tap()
    assertNavigation(app)
    capture("large-chinese-viewer")
    app.buttons["viewer-back"].tap()
    XCTAssertTrue(app.buttons[id].waitForExistence(timeout: 5))
    XCTAssertEqual(app.buttons[id].frame.midY, originalY, accuracy: 3)
    app.buttons["albums-back"].tap()
    app.buttons["album-roll"].tap()
    let restored = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'photo-demo-'"))
      .allElementsBoundByIndex.filter { $0.isHittable }.map { "\($0.identifier): \($0.frame)" }
    let diagnostic = XCTAttachment(
      string: "Expected \(id) at \(app.buttons[id].frame)\n" + restored.joined(separator: "\n"))
    diagnostic.name = "restored-position-details"
    diagnostic.lifetime = .keepAlways
    add(diagnostic)
    capture("large-reopened-grid")
    waitUntilHittable(app.buttons[id])
    app.buttons[id].tap()
    app.buttons["delete-photo"].tap()
    app.buttons["photo-alert-confirm"].tap()
    XCTAssertTrue(app.buttons["albums-back"].waitForExistence(timeout: 10))
    let index = Int(id.replacingOccurrences(of: "photo-demo-", with: ""))!
    let neighbor = "photo-demo-\(index + 1)"
    waitUntilHittable(app.buttons[neighbor])
    XCTAssertFalse(app.buttons[id].exists)
    capture("large-after-delete")
    app.terminate()
    let reopened = launch("zh-Hans", preserve: true)
    XCTAssertTrue(reopened.buttons[neighbor].waitForExistence(timeout: 10))
    waitUntilHittable(reopened.buttons[neighbor])
    capture("large-restored-grid")
  }

  func testEnglishLargeCounterAndReturnFromNextPhoto() {
    let app = launch("en")
    let lastPhoto = app.buttons["photo-demo-6623"]
    XCTAssertTrue(lastPhoto.waitForExistence(timeout: 15))
    lastPhoto.tap()
    assertNavigation(app)
    app.buttons["next-photo"].tap()
    assertNavigation(app)
    capture("large-english-last-viewer")
    app.buttons["viewer-back"].tap()
    XCTAssertTrue(app.buttons["photo-demo-video"].isHittable)
    XCUIDevice.shared.orientation = .landscapeLeft
    XCTAssertTrue(app.buttons["albums-back"].waitForExistence(timeout: 5))
    capture("large-landscape-grid")
    XCUIDevice.shared.orientation = .portrait
  }
}
