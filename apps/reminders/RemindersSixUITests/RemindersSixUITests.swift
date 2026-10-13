import XCTest

@MainActor
final class RemindersSixUITests: XCTestCase {
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
  private func launch(_ language: String = "en", demo: Bool = false, extra: [String] = []) {
    app.launchArguments =
      [
        "--uitesting", "-AppleLanguages", "(\(language))", "-AppleLocale",
        language.hasPrefix("zh") ? "zh_CN" : "en_US",
      ] + (demo ? ["--demo"] : []) + extra
    app.launch()
    XCTAssertTrue(app.buttons["Lists"].waitForExistence(timeout: 8))
  }
  private func capture(_ name: String) {
    Thread.sleep(forTimeInterval: 0.35)
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
  private func element(_ identifier: String) -> XCUIElement {
    app.descendants(matching: .any).matching(identifier: identifier).firstMatch
  }
  private func add(_ title: String) {
    app.buttons["Add Reminder"].tap()
    let field = element("Reminder title")
    XCTAssertTrue(field.waitForExistence(timeout: 3))
    field.tap()
    field.typeText(title)
    app.buttons["Save Reminder"].tap()
    XCTAssertTrue(app.buttons[title].waitForExistence(timeout: 4))
  }
  private func open(_ title: String) {
    app.buttons.matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND (label == %@ OR label BEGINSWITH %@)", "reminder-",
        title, title)
    ).firstMatch.tap()
  }

  func testCreateEditCompleteUndoAndDeleteEnglish() {
    launch()
    XCTAssertTrue(app.staticTexts["No Reminders"].exists)
    add("Buy fresh bread")
    capture("en-created-reminder")
    app.buttons["Complete Buy fresh bread"].tap()
    XCTAssertTrue(app.buttons["Mark Buy fresh bread incomplete"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["Buy fresh bread"].exists)
    XCTAssertFalse(app.staticTexts["No Reminders"].exists)
    capture("en-completed-in-place")
    app.buttons["Mark Buy fresh bread incomplete"].tap()
    XCTAssertTrue(app.buttons["Complete Buy fresh bread"].waitForExistence(timeout: 3))
    app.buttons["Complete Buy fresh bread"].tap()
    app.buttons["Lists"].tap()
    app.buttons.containing(.staticText, identifier: "Completed").firstMatch.tap()
    XCTAssertTrue(app.buttons["Buy fresh bread"].waitForExistence(timeout: 3))
    capture("en-completed")
    app.buttons["Mark Buy fresh bread incomplete"].tap()
    XCTAssertTrue(app.staticTexts["No Completed Reminders"].waitForExistence(timeout: 3))
    app.buttons["Lists"].tap()
    app.buttons["list-Reminders"].tap()
    open("Buy fresh bread")
    capture("en-details")
    app.buttons["Delete Reminder"].tap()
    app.alerts.buttons["Delete"].tap()
    XCTAssertTrue(app.staticTexts["No Reminders"].waitForExistence(timeout: 3))
    app.buttons["Add Reminder"].tap()
    app.buttons["Save Reminder"].tap()
    XCTAssertTrue(app.buttons["Add Reminder"].isHittable)
  }
  func testListsSearchRenameMoveAndCancel() {
    launch()
    app.buttons["Lists"].tap()
    app.buttons["Accounts"].tap()
    XCTAssertTrue(app.buttons["Connect System Reminders"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["Open Settings"].exists)
    capture("en-accounts")
    app.buttons["Close Accounts"].tap()
    XCTAssertTrue(app.buttons["Create New List"].waitForExistence(timeout: 3))
    app.buttons["Create New List"].tap()
    let name = app.textFields["List Name"]
    XCTAssertTrue(name.waitForExistence(timeout: 3))
    name.tap()
    name.typeText("Shopping")
    app.buttons["Save List"].tap()
    Thread.sleep(forTimeInterval: 0.35)
    app.buttons["Close Lists"].tap()
    XCTAssertTrue(element("List title").waitForExistence(timeout: 4))
    XCTAssertEqual(element("List title").label, "Shopping")
    add("Milk")
    app.buttons["Lists"].tap()
    capture("en-lists-before-search")
    app.textFields["Search"].tap()
    app.textFields["Search"].typeText("Milk")
    XCTAssertTrue(app.buttons["Search result"].waitForExistence(timeout: 3))
    capture("en-search")
    app.buttons["Search result"].tap()
    XCTAssertTrue(app.buttons["Save Reminder"].waitForExistence(timeout: 4))
    app.buttons["List"].tap()
    app.buttons["Reminders"].tap()
    app.buttons["Save Reminder"].tap()
    app.buttons["Lists"].tap()
    app.buttons["list-Reminders"].tap()
    XCTAssertTrue(app.buttons["Milk"].waitForExistence(timeout: 3))
    app.buttons["Lists"].tap()
    app.buttons["Edit Lists"].tap()
    app.buttons["list-Shopping"].tap()
    let rename = app.textFields["List Name"]
    rename.tap()
    rename.typeText(" list")
    app.buttons["Save List"].tap()
    XCTAssertTrue(app.buttons["list-Shopping list"].waitForExistence(timeout: 3))
    capture("en-lists")
    app.buttons["Close Lists"].tap()
  }

  func testListRowsOpenFromCountAndDisclosure() {
    for language in ["en", "zh-Hant"] {
      launch(language, demo: true)
      let names = language == "en" ? ["Reminders", "Shopping", "Work"] : ["提醒事项", "购物清单", "工作"]
      for name in names {
        for offset in [0.88, 0.96] {
          app.buttons["Lists"].tap()
          let row = app.buttons["list-\(name)"]
          XCTAssertTrue(row.waitForExistence(timeout: 3))
          Thread.sleep(forTimeInterval: 0.35)
          row.coordinate(withNormalizedOffset: CGVector(dx: offset, dy: 0.5)).tap()
          let title = element("List title")
          let expected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", name), object: title)
          XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 3), .completed)
          XCTAssertFalse(app.buttons["Close Lists"].exists)
        }
      }
      capture("\(language)-right-edge-list-navigation")
      app.buttons["Lists"].tap()
      XCTAssertTrue(app.buttons["Edit Lists"].waitForExistence(timeout: 3))
      Thread.sleep(forTimeInterval: 0.35)
      app.buttons["Edit Lists"].tap()
      let row = app.buttons["list-\(names[2])"]
      row.coordinate(withNormalizedOffset: CGVector(dx: 0.96, dy: 0.5)).tap()
      XCTAssertTrue(app.textFields["List Name"].waitForExistence(timeout: 3))
      XCTAssertEqual(app.textFields["List Name"].value as? String, names[2])
      app.buttons[language == "en" ? "Cancel" : "取消"].tap()
      XCTAssertTrue(app.buttons["list-\(names[2])"].waitForExistence(timeout: 3))
      Thread.sleep(forTimeInterval: 0.35)
      app.buttons["Edit Lists"].tap()
      app.buttons[language == "en" ? "Delete Work" : "删除工作"].tap()
      XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 3))
      app.alerts.buttons[language == "en" ? "Cancel" : "取消"].tap()
      XCTAssertTrue(app.buttons["list-\(names[2])"].exists)
      capture("\(language)-separate-list-edit-controls")
    }
  }
  func testDateRepeatPriorityNotesAndLocationCancellation() {
    launch()
    add("Weekly reading")
    open("Weekly reading")
    app.buttons["Remind Me On a Day"].tap()
    app.buttons["Due date"].tap()
    XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 3))
    capture("en-date-wheel")
    app.buttons["Due date"].tap()
    app.buttons["Repeat"].tap()
    app.buttons["Every Week"].tap()
    let scroll = app.scrollViews.firstMatch
    if !app.buttons["Priority"].isHittable { scroll.swipeUp() }
    app.buttons["Priority"].tap()
    app.buttons["High"].tap()
    if !app.buttons["Notes"].isHittable { scroll.swipeUp() }
    app.buttons["Notes"].tap()
    app.textViews["Reminder notes"].tap()
    app.textViews["Reminder notes"].typeText("Chapter one")
    app.buttons["Back"].tap()
    if !app.buttons["Remind Me At a Location"].isHittable { app.scrollViews.firstMatch.swipeDown() }
    app.buttons["Remind Me At a Location"].tap()
    XCTAssertTrue(app.textFields["Location address"].waitForExistence(timeout: 3))
    capture("en-location")
    app.buttons["Back"].tap()
    app.buttons["Save Reminder"].tap()
    XCTAssertTrue(app.buttons["Weekly reading"].waitForExistence(timeout: 3))
    XCTAssertTrue((app.buttons["Weekly reading"].value as? String)?.contains("Chapter one") == true)
    capture("en-repeating-with-notes")
    open("Weekly reading")
    capture("en-configured-details")
    app.buttons["Cancel Details"].tap()
  }
  func testChineseVariantLandscapeLargeTextAndCompleted() {
    launch("zh-Hant", demo: true)
    XCTAssertEqual(app.buttons["Lists"].label, "列表")
    XCTAssertEqual(element("List title").label, "提醒事项")
    capture("zh-main")
    app.buttons["将读一本好书标记为已完成"].tap()
    XCTAssertTrue(app.buttons["将读一本好书标记为未完成"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["读一本好书"].exists)
    capture("zh-completed-in-place")
    open("准备明天的会议")
    capture("zh-details")
    app.buttons["Cancel Details"].tap()
    app.buttons["Lists"].tap()
    capture("zh-lists")
    app.buttons["Accounts"].tap()
    XCTAssertTrue(app.buttons["Connect System Reminders"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.buttons["Connect System Reminders"].label, "连接系统提醒事项")
    capture("zh-accounts")
    XCUIDevice.shared.orientation = .landscapeLeft
    XCTAssertTrue(app.buttons["Close Accounts"].isHittable)
    capture("zh-accounts-landscape")
    XCUIDevice.shared.orientation = .portrait
    app.buttons["Close Accounts"].tap()
    app.buttons.containing(.staticText, identifier: "今天").firstMatch.tap()
    XCTAssertTrue(element("Date ribbon").exists)
    app.buttons["将出去散步标记为已完成"].tap()
    XCTAssertTrue(app.buttons["将出去散步标记为未完成"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["出去散步"].exists)
    capture("zh-today")
    app.buttons["将出去散步标记为未完成"].tap()
    XCTAssertTrue(app.buttons["将出去散步标记为已完成"].waitForExistence(timeout: 3))
    XCUIDevice.shared.orientation = .landscapeLeft
    XCTAssertTrue(app.buttons["Lists"].isHittable)
    capture("zh-landscape")
    XCUIDevice.shared.orientation = .portrait
    launch(
      "zh-Hans", demo: true,
      extra: [
        "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL",
        "-UIAccessibilityReduceMotionEnabled", "YES",
      ])
    XCTAssertTrue(app.buttons["Lists"].isHittable)
    capture("zh-large-text")
  }
  func testUnsupportedLanguageFallbackAndPersistentRelaunch() {
    let file = NSTemporaryDirectory() + "reminders-ui-" + UUID().uuidString + ".json"
    launch("fr-FR", extra: ["--test-store", file])
    XCTAssertEqual(app.buttons["Lists"].label, "Lists")
    add("Preserve my text 中文")
    app.buttons["Complete Preserve my text 中文"].tap()
    XCTAssertTrue(app.buttons["Mark Preserve my text 中文 incomplete"].waitForExistence(timeout: 3))
    app.terminate()
    launch("zh-Hans", extra: ["--test-store", file])
    XCTAssertTrue(app.buttons["Preserve my text 中文"].exists)
    XCTAssertTrue(app.buttons["将Preserve my text 中文标记为未完成"].exists)
    XCTAssertEqual(app.buttons["Lists"].label, "列表")
    capture("zh-persistent-user-text")
  }

  func testQuickEntryDetailsCancelPreservesDraft() {
    launch()
    app.buttons["Add Reminder"].tap()
    let title = element("Reminder title")
    XCTAssertTrue(title.waitForExistence(timeout: 3))
    title.tap()
    title.typeText("Keep this draft")
    capture("en-quick-entry")
    app.buttons["Quick Details"].tap()
    XCTAssertTrue(app.buttons["Cancel Details"].waitForExistence(timeout: 3))
    app.buttons["Cancel Details"].tap()
    XCTAssertTrue(app.buttons["Quick Details"].waitForExistence(timeout: 3))
    XCTAssertEqual(element("Reminder title").value as? String, "Keep this draft")
    app.buttons["Save Reminder"].tap()
    XCTAssertTrue(app.buttons["Keep this draft"].waitForExistence(timeout: 3))
  }

  func testTitlePagingDragOrderingAndSwipeDelete() {
    launch(demo: true)
    element("List title").swipeLeft()
    XCTAssertEqual(element("List title").label, "Shopping")
    element("List title").swipeRight()
    XCTAssertEqual(element("List title").label, "Reminders")
    launch()
    add("First task")
    add("Second task")
    app.buttons["Edit"].tap()
    app.buttons["Second task"].press(forDuration: 0.8, thenDragTo: app.buttons["First task"])
    let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "reminder-"))
    XCTAssertEqual(rows.firstMatch.label, "Second task")
    capture("en-reordered")
    app.buttons["Edit"].tap()
    app.buttons["Second task"].swipeLeft()
    XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 3))
    app.buttons["Delete"].tap()
    XCTAssertFalse(app.buttons["Second task"].exists)
    XCTAssertTrue(app.buttons["First task"].exists)
  }

  func testLiveAddressSearchAndDepartureSelection() {
    launch()
    add("Location task")
    open("Location task")
    app.buttons["Remind Me At a Location"].tap()
    let address = app.textFields["Location address"]
    XCTAssertTrue(address.waitForExistence(timeout: 3))
    address.tap()
    address.typeText("London")
    app.buttons["Search Address"].tap()
    let result = app.buttons["Place result"].firstMatch
    XCTAssertTrue(result.waitForExistence(timeout: 20))
    capture("en-location-search")
    result.tap()
    XCTAssertTrue(app.buttons["When I Leave"].waitForExistence(timeout: 3))
    app.buttons["When I Leave"].tap()
    capture("en-departure")
    app.buttons["Save Reminder"].tap()
    XCTAssertTrue(app.buttons["Location task"].waitForExistence(timeout: 3))
    XCTAssertTrue((app.buttons["Location task"].value as? String)?.contains("Leaving") == true)
  }
}
