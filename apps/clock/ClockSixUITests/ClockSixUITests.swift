import UIKit
import XCTest

@MainActor
final class ClockSixUITests: XCTestCase {
  private var app: XCUIApplication!
  override func setUp() {
    continueAfterFailure = false
    XCUIDevice.shared.orientation = .portrait
    app = XCUIApplication()
  }
  override func tearDown() {
    app.terminate()
    XCUIDevice.shared.orientation = .portrait
  }
  private func launch(_ language: String = "en", reset: Bool = true, extra: [String] = []) {
    app.launchArguments =
      [
        "--uitesting", "-AppleLanguages", "(\(language))", "-AppleLocale",
        language.hasPrefix("zh") ? "zh_CN" : "en_US", "-UIPreferredContentSizeCategoryName",
        "UICTContentSizeCategoryM",
      ] + (reset ? ["--reset"] : []) + extra
    app.launch()
    XCTAssertTrue(app.buttons["tab-world"].waitForExistence(timeout: 8))
  }
  private func capture(_ name: String) {
    let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    shot.name = name
    shot.lifetime = .keepAlways
    add(shot)
  }
  private func openAlarm() {
    app.buttons["tab-alarm"].tap()
    app.buttons["nav-right"].tap()
    XCTAssertTrue(app.buttons["alarm-repeat"].waitForExistence(timeout: 3))
  }
  func testWorldClocksEnglishSearchAddReorderDeleteAndEmpty() {
    launch()
    XCTAssertEqual(app.buttons["tab-world"].label, "World Clock")
    XCTAssertTrue(app.staticTexts["city-London"].exists)
    capture("en-world-clock")
    app.buttons["nav-right"].tap()
    app.textFields["city-search"].tap()
    app.textFields["city-search"].typeText("Sydney")
    app.buttons["search-city-Sydney"].tap()
    app.buttons["nav-left"].tap()
    let list = app.scrollViews["world-list"]
    if !app.buttons["delete-city-Sydney"].isHittable { list.swipeUp() }
    XCTAssertTrue(app.buttons["delete-city-Sydney"].waitForExistence(timeout: 3))
    app.buttons["Move up Sydney"].tap()
    app.buttons["delete-city-Sydney"].tap()
    for name in ["Tokyo", "Beijing", "New York", "London"] {
      let button = app.buttons["delete-city-" + name]
      if !button.isHittable { list.swipeUp() }
      button.tap()
    }
    XCTAssertTrue(app.staticTexts["No World Clocks"].exists)
    capture("en-world-empty")
    app.buttons["nav-right"].tap()
    app.buttons["nav-right"].tap()
    XCTAssertTrue(app.buttons["tab-world"].isHittable)
  }
  func testAlarmEditorRepeatSoundLabelSaveToggleReopenDelete() {
    launch()
    openAlarm()
    app.buttons["alarm-repeat"].tap()
    app.buttons["weekday-2"].tap()
    app.buttons["weekday-6"].tap()
    capture("en-alarm-repeat")
    app.buttons["nav-left"].tap()
    app.buttons["alarm-sound"].tap()
    app.buttons["sound-Bell Tower"].tap()
    app.buttons["nav-left"].tap()
    app.buttons["alarm-label"].tap()
    app.textFields["alarm-label-field"].tap()
    app.textFields["alarm-label-field"].typeText("Morning class")
    app.buttons["nav-right"].tap()
    app.pickerWheels.element(boundBy: 0).adjust(toPickerWheelValue: "8")
    app.pickerWheels.element(boundBy: 1).adjust(toPickerWheelValue: "30")
    capture("en-alarm-editor")
    app.buttons["nav-right"].tap()
    let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'alarm-row-'"))
      .firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 3))
    XCTAssertTrue(row.label.contains("Morning class"))
    XCTAssertLessThan(row.frame.height, 150)
    XCTAssertLessThan(row.frame.minY - app.buttons["nav-right"].frame.maxY, 50)
    let toggle = app.switches.firstMatch
    XCTAssertTrue(toggle.exists)
    toggle.tap()
    capture("en-alarms")
    row.tap()
    XCTAssertTrue(app.buttons["alarm-repeat"].label.contains("Mon"))
    XCTAssertTrue(app.buttons["alarm-sound"].label.contains("Bell Tower"))
    app.buttons["nav-left"].tap()
    app.buttons["nav-left"].tap()
    app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'delete-alarm-'")).firstMatch
      .tap()
    XCTAssertTrue(app.staticTexts["No Alarms"].exists)
  }
  func testChineseVariantsCitiesLabelsAndPersistenceAcrossLanguageChange() {
    launch("zh-Hant")
    XCTAssertEqual(app.buttons["tab-world"].label, "世界时钟")
    XCTAssertTrue(app.staticTexts["city-Beijing"].label.contains("北京"))
    capture("zh-world-clock")
    app.buttons["nav-right"].tap()
    app.textFields["city-search"].tap()
    app.textFields["city-search"].typeText("悉尼")
    app.buttons["search-city-Sydney"].tap()
    openAlarm()
    XCTAssertEqual(app.buttons["nav-right"].label, "存储")
    app.buttons["alarm-label"].tap()
    app.textFields["alarm-label-field"].tap()
    app.textFields["alarm-label-field"].typeText("保留我的标签")
    app.buttons["nav-right"].tap()
    capture("zh-alarm-editor")
    app.buttons["nav-right"].tap()
    app.terminate()
    launch("en", reset: false)
    app.buttons["tab-alarm"].tap()
    let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'alarm-row-'"))
      .firstMatch
    XCTAssertTrue(row.label.contains("保留我的标签"))
    app.buttons["tab-world"].tap()
    app.scrollViews["world-list"].swipeUp()
    XCTAssertTrue(app.staticTexts["city-Sydney"].label.contains("Sydney"))
  }
  func testStopwatchLapsPauseResumeResetAndProcessRestore() {
    launch()
    app.buttons["tab-stopwatch"].tap()
    XCTAssertFalse(app.buttons["stopwatch-lap"].isEnabled)
    capture("en-stopwatch-reset")
    app.buttons["stopwatch-start"].tap()
    app.buttons["stopwatch-lap"].tap()
    XCTAssertTrue(
      app.descendants(matching: .any)["lap-1"].waitForExistence(timeout: 3)
        || app.staticTexts["Lap 1"].exists)
    app.buttons["stopwatch-start"].tap()
    let paused = app.staticTexts["stopwatch-display"].value as? String
    app.terminate()
    launch(reset: false)
    app.buttons["tab-stopwatch"].tap()
    XCTAssertEqual(app.staticTexts["stopwatch-display"].value as? String, paused)
    capture("en-stopwatch-laps")
    app.buttons["stopwatch-start"].tap()
    app.buttons["stopwatch-start"].tap()
    app.buttons["stopwatch-lap"].tap()
    XCTAssertEqual(app.staticTexts["stopwatch-display"].value as? String, "00:00.0")
  }
  func testTimerSoundPauseResumeCancelAndZeroDuration() {
    launch("zh-Hans")
    app.buttons["tab-timer"].tap()
    capture("zh-timer-picker")
    app.buttons["timer-sound"].tap()
    app.buttons["sound-Digital"].tap()
    capture("zh-timer-sounds")
    app.buttons["nav-left"].tap()
    XCTAssertTrue(app.buttons["timer-start"].isEnabled)
    app.buttons["timer-start"].tap()
    XCTAssertEqual(app.buttons["timer-start"].label, "暂停")
    XCTAssertFalse(app.buttons["timer-sound"].isEnabled)
    app.buttons["timer-start"].tap()
    XCTAssertEqual(app.buttons["timer-start"].label, "继续")
    capture("zh-timer-paused")
    app.buttons["timer-start"].tap()
    app.buttons["timer-cancel"].tap()
    app.pickerWheels.element(boundBy: 1).adjust(toPickerWheelValue: "00 分")
    XCTAssertFalse(app.buttons["timer-start"].isEnabled)
  }
  func testTimerExpiryDismissAndReopen() {
    launch(extra: ["--short-timer"])
    app.buttons["tab-timer"].tap()
    XCTAssertTrue(app.buttons["timer-start"].isEnabled)
    app.buttons["timer-start"].tap()
    XCTAssertTrue(app.buttons["ring-stop"].waitForExistence(timeout: 6))
    capture("en-timer-finished")
    app.buttons["ring-stop"].tap()
    XCTAssertTrue(app.buttons["timer-start"].isEnabled)
    app.buttons["timer-start"].tap()
    XCTAssertEqual(app.buttons["timer-start"].label, "Pause")
    XCTAssertTrue(app.buttons["ring-stop"].waitForExistence(timeout: 6))
    app.buttons["ring-stop"].tap()
  }
  func testTimerWheelsBilingualSelection() {
    for language in ["en", "zh-Hans"] {
      launch(language)
      app.buttons["tab-timer"].tap()
      let chinese = language.hasPrefix("zh")
      app.pickerWheels.element(boundBy: 0).adjust(
        toPickerWheelValue: chinese ? "2 小时" : "2 hours")
      app.pickerWheels.element(boundBy: 1).adjust(
        toPickerWheelValue: chinese ? "35 分" : "35 min")
      XCTAssertEqual(app.buttons["timer-start"].value as? String, "02:35:00")
      app.buttons["timer-start"].tap()
      XCTAssertEqual(app.buttons["timer-start"].label, chinese ? "暂停" : "Pause")
      app.buttons["timer-cancel"].tap()
      XCTAssertEqual(app.buttons["timer-start"].value as? String, "02:35:00")
      XCTAssertEqual(
        app.pickerWheels.element(boundBy: 1).value as? String, chinese ? "35 分" : "35 min")
      capture(chinese ? "zh-timer-picker-selected" : "en-timer-picker-selected")
    }
  }
  func testCompactLandscapeChineseAndUnsupportedLanguageFallback() {
    launch("fr")
    XCTAssertEqual(app.buttons["tab-alarm"].label, "Alarm")
    launch("zh-Hans")
    for tab in ["world", "alarm", "stopwatch", "timer"] {
      app.buttons["tab-" + tab].tap()
      XCUIDevice.shared.orientation = .landscapeLeft
      XCTAssertTrue(app.buttons["tab-world"].waitForExistence(timeout: 3))
      let settled = NSPredicate { object, _ in
        guard let element = object as? XCUIElement else { return false }
        return element.frame.height >= 44 && element.frame.width > element.frame.height
      }
      expectation(for: settled, evaluatedWith: app.buttons["tab-world"])
      waitForExpectations(timeout: 5)
      for item in ["world", "alarm", "stopwatch", "timer"] {
        let button = app.buttons["tab-" + item]
        XCTAssertTrue(button.isHittable)
        XCTAssertGreaterThanOrEqual(button.frame.height, 44)
        XCTAssertTrue(app.frame.contains(button.frame))
      }
      capture("zh-landscape-" + tab)
      XCUIDevice.shared.orientation = .portrait
    }
  }
  func testLargeTextAlarmCancelAndReopen() {
    launch(
      "zh-Hans",
      extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
    openAlarm()
    capture("zh-large-text-alarm")
    app.buttons["nav-left"].tap()
    XCTAssertTrue(app.buttons["tab-alarm"].isHittable)
    app.buttons["nav-right"].tap()
    XCTAssertTrue(app.buttons["alarm-repeat"].waitForExistence(timeout: 3))
    app.buttons["nav-left"].tap()
  }
  func testMusicPickerSimulatorRecoveryAndSoundSelection() {
    launch("zh-Hans")
    openAlarm()
    app.buttons["alarm-sound"].tap()
    app.buttons["pick-song"].tap()
    XCTAssertTrue(app.buttons["ring-stop"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["选取音乐需要使用已下载歌曲的真实 iPhone。"].exists)
    capture("zh-music-simulator-recovery")
    app.buttons["ring-stop"].tap()
    app.buttons["sound-Digital"].tap()
    app.buttons["nav-left"].tap()
    XCTAssertTrue(app.buttons["alarm-sound"].label.contains("数码"))
    app.buttons["nav-left"].tap()
    XCTAssertTrue(app.buttons["tab-alarm"].isHittable)
  }
  func testBackgroundTimerDeliversSystemNotification() {
    launch(extra: ["--real-reminders", "--integration-timer"])
    app.buttons["tab-timer"].tap()
    XCTAssertTrue(app.buttons["timer-start"].isEnabled)
    app.buttons["timer-start"].tap()
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let permission = springboard.alerts.firstMatch
    if permission.waitForExistence(timeout: 2) {
      let allow =
        permission.buttons["Allow"].exists ? permission.buttons["Allow"] : permission.buttons["允许"]
      XCTAssertTrue(allow.exists)
      allow.tap()
    }
    XCUIDevice.shared.press(.home)
    let banner = springboard.descendants(matching: .any)
      .matching(NSPredicate(format: "label CONTAINS %@", "Timer finished")).firstMatch
    let visibleBanner = NSPredicate { object, _ in
      guard let element = object as? XCUIElement else { return false }
      return element.exists && element.frame.minY >= 0 && element.frame.height > 0
    }
    expectation(for: visibleBanner, evaluatedWith: banner)
    waitForExpectations(timeout: 14)
    capture("en-background-timer-notification")
    app.activate()
    XCTAssertTrue(app.buttons["ring-stop"].waitForExistence(timeout: 4))
    app.buttons["ring-stop"].tap()
    XCTAssertTrue(app.buttons["timer-start"].isEnabled)
  }
}
