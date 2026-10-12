import XCTest

final class CalendarSixUITests: XCTestCase {
  private var app: XCUIApplication!
  override func setUpWithError() throws {
    continueAfterFailure = false
    XCUIDevice.shared.orientation = .portrait
    app = XCUIApplication()
  }
  override func tearDownWithError() throws { XCUIDevice.shared.orientation = .portrait }
  private func launch(_ language: String = "en", demo: Bool = true, reset: Bool = true) {
    app.launchArguments = [
      "--uitesting", "-AppleLanguages", "(\(language))", "-AppleLocale",
      language.hasPrefix("zh") ? "zh_CN" : "en_US",
    ]
    if reset { app.launchArguments += ["--reset"] }
    if demo { app.launchArguments += ["--demo"] }
    app.launch()
    XCTAssertTrue(app.buttons["add-event"].waitForExistence(timeout: 6))
  }
  private func capture(_ name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
  private func tap(_ id: String) {
    let button = app.buttons[id]
    XCTAssertTrue(button.waitForExistence(timeout: 4), id)
    if !button.isHittable {
      let scroll = app.scrollViews.firstMatch
      for _ in 0..<5 {
        if button.isHittable { break }
        scroll.swipeUp()
      }
    }
    button.tap()
  }
  private func type(_ id: String, _ text: String) {
    let field = app.textFields[id]
    XCTAssertTrue(field.waitForExistence(timeout: 3))
    field.tap()
    if id == "search-events" {
      XCTAssertFalse(app.otherElements["week-view"].exists)
      capture("search-focused")
    }
    field.typeText(text)
  }
  private func firstEvent(containing title: String) -> XCUIElement {
    app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH 'event-' AND label CONTAINS %@", title)
    ).firstMatch
  }
  func testDynamicIconDatesLanguagesAndPrimaryRestoration() {
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    func dismissIconNotice() {
      if springboard.alerts.firstMatch.waitForExistence(timeout: 3) {
        springboard.alerts.firstMatch.buttons.firstMatch.tap()
      } else if app.alerts.firstMatch.exists {
        app.alerts.firstMatch.buttons.firstMatch.tap()
      }
    }
    for (language, date, label, name) in [
      ("en", "2026-10-12T12:00:00Z", "Monday 12", "en-monday-12"),
      ("en", "2026-10-13T12:00:00Z", "Tuesday 13", "en-tuesday-13"),
      ("zh-Hans", "2026-10-13T12:00:00Z", "星期二 13", "zh-tuesday-13"),
    ] {
      app.terminate()
      app.launchArguments = [
        "--uitesting", "--demo", "--reset", "--icon-testing", "--icon-date", date,
        "-AppleLanguages", "(\(language))", "-AppleLocale",
        language == "en" ? "en_US" : "zh_CN",
      ]
      app.launchEnvironment["TZ"] = "UTC"
      app.launch()
      dismissIconNotice()
      tap("calendars")
      tap("calendar-settings")
      XCTAssertTrue(app.staticTexts[label].waitForExistence(timeout: 5))
      capture(name + "-settings")
    }
    let toggle = app.switches["dynamic-date-icon"]
    XCTAssertTrue(toggle.waitForExistence(timeout: 4))
    toggle.tap()
    dismissIconNotice()
    XCTAssertTrue(app.staticTexts["原始图标"].waitForExistence(timeout: 5))
    toggle.tap()
    dismissIconNotice()
    XCTAssertTrue(app.staticTexts["星期二 13"].waitForExistence(timeout: 5))
    capture("zh-dynamic-icon-restored")
  }
  func testMonthSelectionNavigationDayListSearchAndInbox() {
    launch()
    XCTAssertTrue(app.staticTexts["October 2026"].exists)
    capture("en-month")
    tap("next-period")
    XCTAssertTrue(app.staticTexts["November 2026"].exists)
    tap("today")
    tap("date-2026-10-14")
    XCTAssertTrue(firstEvent(containing: "Alex’s Birthday").exists)
    tap("today")
    tap("mode-day")
    XCTAssertTrue(app.buttons["timeline-event-demo-meeting"].waitForExistence(timeout: 3))
    capture("en-day")
    tap("mode-list")
    type("search-events", "Lunch")
    XCTAssertTrue(firstEvent(containing: "Lunch").exists)
    XCTAssertFalse(firstEvent(containing: "Design Meeting").exists)
    capture("en-search")
    tap("clear-search")
    app.buttons["Cancel"].tap()
    tap("inbox")
    XCTAssertTrue(app.staticTexts["No Invitations"].exists)
    capture("en-inbox")
    tap("inbox-done")
  }
  func testCreatePersistEditDeleteAndCancel() {
    launch(demo: false)
    tap("add-event")
    XCTAssertFalse(app.buttons["editor-save"].isEnabled)
    type("event-title", "Persistent appointment")
    type("event-location", "London")
    tap("edit-repeat")
    tap("choice-Every Week")
    tap("edit-alert")
    tap("choice-15 minutes before")
    capture("en-editor")
    tap("editor-save")
    XCTAssertTrue(firstEvent(containing: "Persistent appointment").waitForExistence(timeout: 3))
    app.terminate()
    launch(demo: false, reset: false)
    XCTAssertTrue(firstEvent(containing: "Persistent appointment").exists)
    firstEvent(containing: "Persistent appointment").tap()
    XCTAssertTrue(app.buttons["Open Location in Maps: London"].exists)
    capture("en-detail")
    tap("edit-event")
    let field = app.textFields["event-title"]
    field.tap()
    field.typeText(
      String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Persistent appointment".count)
        + "Updated appointment")
    tap("editor-save")
    tap("scope-Only This Event")
    XCTAssertTrue(firstEvent(containing: "Updated appointment").exists)
    firstEvent(containing: "Updated appointment").tap()
    tap("delete-event")
    tap("scope-Delete Event")
    XCTAssertFalse(firstEvent(containing: "Updated appointment").exists)
    tap("add-event")
    type("event-title", "Discarded")
    tap("editor-cancel")
    XCTAssertFalse(firstEvent(containing: "Discarded").exists)
  }
  func testRepeatedEventDeleteScopeKeepsFutureOccurrences() {
    launch()
    tap("event-demo-meeting")
    tap("delete-event")
    capture("en-delete-series")
    tap("scope-Only This Event")
    XCTAssertFalse(app.buttons["event-demo-meeting"].exists)
    tap("date-2026-10-19")
    XCTAssertTrue(app.buttons["event-demo-meeting"].exists)
    tap("event-demo-meeting")
    tap("delete-event")
    tap("scope-All Events")
    XCTAssertFalse(app.buttons["event-demo-meeting"].exists)
  }
  func testAllDayWheelCalendarAndAvailability() {
    launch(demo: false)
    tap("add-event")
    type("event-title", "All day holiday")
    app.switches["all-day-toggle"].tap()
    tap("edit-starts")
    XCTAssertTrue(app.otherElements["wheel-month"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.otherElements["wheel-year"].exists)
    XCTAssertTrue(app.otherElements["wheel-day"].exists)
    capture("en-date-wheel")
    XCUIDevice.shared.orientation = .landscapeLeft
    let month = app.otherElements["wheel-month"]
    let landscape = NSPredicate { _, _ in
      self.app.frame.width > self.app.frame.height
        && month.frame.minX > self.app.buttons["picker-starts"].frame.maxX
    }
    let layout = XCTNSPredicateExpectation(predicate: landscape, object: app)
    XCTAssertEqual(XCTWaiter.wait(for: [layout], timeout: 5), .completed)
    XCTAssertTrue(month.isHittable)
    XCTAssertTrue(app.buttons["option-back"].isHittable)
    let originalMonth = month.value as? String
    month.swipeUp()
    XCTAssertNotEqual(month.value as? String, originalMonth)
    capture("en-landscape-date-wheel")
    XCUIDevice.shared.orientation = .portrait
    tap("option-back")
    tap("edit-calendar")
    tap("choose-calendar-work")
    tap("edit-availability")
    tap("choice-Free")
    tap("editor-save")
    firstEvent(containing: "All day holiday").tap()
    XCTAssertTrue(
      app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'All-day'")).firstMatch.exists)
    XCTAssertTrue(app.staticTexts["Free"].exists)
    XCTAssertTrue(app.staticTexts["Work"].exists)
  }
  func testClassicDateWheelsUpdateAndKeepValuesInBothLanguages() {
    for language in ["en", "zh-Hans"] {
      launch(language, demo: false)
      tap("add-event")
      type("event-title", "Wheel appointment")
      tap("edit-starts")
      let hour = app.otherElements["wheel-hour"]
      let minute = app.otherElements["wheel-minute"]
      let date = app.otherElements["wheel-date"]
      XCTAssertTrue(hour.waitForExistence(timeout: 3))
      XCTAssertTrue(minute.exists && date.exists)
      XCTAssertEqual(app.otherElements["wheel-period"].exists, language == "en")
      let originalHour = hour.value as? String
      let originalDate = date.value as? String
      let originalMinute = minute.value as? String
      hour.swipeUp()
      date.swipeUp()
      minute.swipeUp()
      if language == "en" {
        let period = app.otherElements["wheel-period"]
        let originalPeriod = period.value as? String
        period.swipeUp()
        XCTAssertNotEqual(period.value as? String, originalPeriod)
      }
      let hourValue = hour.value as? String
      let minuteValue = minute.value as? String
      let dateValue = date.value as? String
      let periodValue = language == "en" ? app.otherElements["wheel-period"].value as? String : nil
      XCTAssertNotEqual(hourValue, originalHour)
      XCTAssertNotEqual(minuteValue, originalMinute)
      XCTAssertNotEqual(dateValue, originalDate)
      capture(language == "en" ? "en-classic-time-wheel" : "zh-classic-time-wheel")
      tap("picker-ends")
      XCTAssertTrue(app.otherElements["wheel-hour"].exists)
      tap("picker-starts")
      XCTAssertEqual(app.otherElements["wheel-hour"].value as? String, hourValue)
      XCTAssertEqual(app.otherElements["wheel-minute"].value as? String, minuteValue)
      XCTAssertEqual(app.otherElements["wheel-date"].value as? String, dateValue)
      if language == "en" {
        XCTAssertEqual(app.otherElements["wheel-period"].value as? String, periodValue)
      }
      tap("option-back")
      tap("editor-save")
      XCTAssertTrue(firstEvent(containing: "Wheel appointment").waitForExistence(timeout: 3))
      app.terminate()
      launch(language, demo: false, reset: false)
      tap("mode-list")
      XCTAssertTrue(firstEvent(containing: "Wheel appointment").waitForExistence(timeout: 3))
      firstEvent(containing: "Wheel appointment").tap()
      tap("edit-event")
      tap("edit-starts")
      XCTAssertEqual(app.otherElements["wheel-hour"].value as? String, hourValue)
      XCTAssertEqual(app.otherElements["wheel-minute"].value as? String, minuteValue)
      XCTAssertEqual(app.otherElements["wheel-date"].value as? String, dateValue)
      if language == "en" {
        XCTAssertEqual(app.otherElements["wheel-period"].value as? String, periodValue)
      }
      tap("option-back")
      tap("editor-cancel")
    }
  }
  func testClassicRepeatEndWheelClampsBeforeStart() {
    launch(demo: false)
    tap("add-event")
    type("event-title", "Repeat deadline")
    tap("edit-repeat")
    tap("choice-Every Week")
    tap("edit-end-repeat")
    tap("choice-On Date")
    let month = app.otherElements["wheel-month"]
    XCTAssertTrue(month.waitForExistence(timeout: 3))
    month.swipeDown()
    XCTAssertEqual(month.value as? String, "October")
    XCTAssertEqual(app.otherElements["wheel-day"].value as? String, "12")
    XCTAssertEqual(app.otherElements["wheel-year"].value as? String, "2026")
    capture("en-classic-repeat-end-wheel")
    tap("option-back")
    tap("editor-save")
    XCTAssertTrue(firstEvent(containing: "Repeat deadline").waitForExistence(timeout: 3))
  }
  func testCalendarFilteringCreationColorDefaultAndDeletion() {
    launch()
    tap("calendars")
    tap("calendar-work")
    tap("calendars-done")
    XCTAssertFalse(app.buttons["event-demo-meeting"].exists)
    XCTAssertTrue(app.buttons["event-demo-lunch"].exists)
    tap("calendars")
    tap("toggle-all-calendars")
    tap("edit-calendars")
    tap("add-calendar")
    type("calendar-name", "Research")
    tap("color-purple")
    tap("save-calendar")
    XCTAssertTrue(
      app.buttons.matching(NSPredicate(format: "label CONTAINS 'Research'")).firstMatch.exists)
    tap("edit-calendars")
    tap("calendar-settings")
    tap("default-calendar")
    app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH 'default-' AND label CONTAINS 'Research'")
    ).firstMatch.tap()
    XCTAssertTrue(app.buttons["default-calendar"].label.contains("Research"))
    app.switches["monday-first"].tap()
    capture("en-settings")
    tap("settings-back")
    tap("edit-calendars")
    app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH 'calendar-' AND label CONTAINS 'Research'")
    ).firstMatch.tap()
    tap("delete-calendar")
    tap("scope-Delete Calendar")
    XCTAssertFalse(
      app.buttons.matching(NSPredicate(format: "label CONTAINS 'Research'")).firstMatch.exists)
    tap("calendars-done")
    XCTAssertTrue(app.buttons["date-2026-09-28"].exists)
  }
  func testChineseLocalizationAcrossPrimaryScreens() {
    launch("zh-Hans")
    XCTAssertEqual(app.buttons["calendars"].label, "日历")
    XCTAssertEqual(app.buttons["add-event"].label, "添加事件")
    XCTAssertTrue(app.staticTexts["2026年10月"].exists)
    capture("zh-month")
    tap("event-demo-lunch")
    XCTAssertTrue(app.staticTexts["事件详情"].exists)
    capture("zh-detail")
    tap("edit-event")
    XCTAssertTrue(app.textFields["event-title"].exists)
    tap("edit-repeat")
    XCTAssertTrue(app.buttons["choice-Every Month"].label.contains("每月"))
    capture("zh-repeat")
    tap("option-back")
    tap("editor-cancel")
    tap("detail-back")
    tap("mode-day")
    capture("zh-day")
    tap("mode-list")
    type("search-events", "设计")
    XCTAssertTrue(app.buttons["event-demo-meeting"].exists)
    capture("zh-search")
    tap("clear-search")
    app.buttons["取消"].tap()
    tap("calendars")
    tap("calendar-settings")
    XCTAssertTrue(app.staticTexts["设置"].exists)
    capture("zh-settings")
    tap("settings-back")
    tap("calendars-done")
    tap("inbox")
    XCTAssertTrue(app.staticTexts["没有邀请"].exists)
    tap("inbox-done")
  }
  func testUnsupportedLanguageFallsBackToEnglishAndUserTextIsPreserved() {
    launch("fr", demo: false)
    XCTAssertEqual(app.buttons["add-event"].label, "Add Event")
    tap("add-event")
    type("event-title", "Bonjour 你好")
    tap("editor-save")
    XCTAssertTrue(firstEvent(containing: "Bonjour 你好").exists)
  }
  func testDemoPermissionNoticeBlocksUnderlyingControlsAndRecovers() {
    launch()
    tap("calendars")
    tap("calendar-settings")
    tap("connect-system-calendars")
    XCTAssertTrue(app.staticTexts["System calendars are disabled in the isolated demo."].exists)
    XCTAssertFalse(app.buttons["settings-back"].isHittable)
    capture("en-permission-notice")
    tap("notice-ok")
    XCTAssertTrue(app.buttons["settings-back"].exists)
    tap("enable-reminders")
    XCTAssertTrue(app.staticTexts["Reminders are disabled in the isolated demo."].exists)
    tap("notice-ok")
    tap("settings-back")
    tap("calendars-done")
  }
  func testLandscapeWeekAndReturnToMonthSafeArea() {
    launch("zh-Hans")
    XCUIDevice.shared.orientation = .landscapeLeft
    XCTAssertTrue(app.otherElements["week-view"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["today"].isHittable)
    XCTAssertTrue(app.buttons["add-event"].isHittable)
    capture("zh-landscape-week")
    XCUIDevice.shared.orientation = .portrait
    XCTAssertTrue(app.buttons["date-2026-10-12"].waitForExistence(timeout: 5))
    let top = app.buttons["calendars"]
    let footer = app.buttons["today"]
    XCTAssertGreaterThanOrEqual(top.frame.minY, 20)
    XCTAssertLessThan(footer.frame.maxY, app.frame.maxY)
    capture("zh-portrait-safe-areas")
  }
}
