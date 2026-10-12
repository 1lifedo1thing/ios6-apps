import XCTest

@testable import CalendarSix

final class CalendarIconTests: XCTestCase {
  private let utc = TimeZone(secondsFromGMT: 0)!
  private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }

  func testWeekdayAndDateAdvanceTogether() {
    let monday = CalendarIconDate(
      date: date("2026-10-12T12:00:00Z"), language: .english, timeZone: utc)
    let tuesday = CalendarIconDate(
      date: date("2026-10-13T12:00:00Z"), language: .english, timeZone: utc)
    XCTAssertEqual(monday.iconName, "CalendarDate_en_w2_d12")
    XCTAssertEqual(tuesday.iconName, "CalendarDate_en_w3_d13")
    XCTAssertEqual(tuesday.label, "Tuesday 13")
    XCTAssertEqual(CalendarIconDate(iconName: tuesday.iconName), tuesday)
  }

  func testTimeZoneYearBoundaryAndLeapDay() {
    let instant = date("2026-12-31T23:30:00Z")
    XCTAssertEqual(
      CalendarIconDate(date: instant, language: .english, timeZone: utc).label, "Thursday 31")
    XCTAssertEqual(
      CalendarIconDate(
        date: instant, language: .chinese, timeZone: TimeZone(identifier: "Asia/Tokyo")!
      ).label,
      "星期五 1")
    XCTAssertEqual(
      CalendarIconDate(date: date("2024-02-29T12:00:00Z"), language: .chinese, timeZone: utc).label,
      "星期四 29")
    let midnight = date("2026-10-12T23:30:00Z")
    XCTAssertEqual(
      CalendarIconDate(
        date: midnight, language: .english, timeZone: TimeZone(identifier: "Europe/London")!
      ).day,
      13)
    XCTAssertEqual(
      CalendarIconDate(
        date: midnight, language: .english, timeZone: TimeZone(identifier: "America/New_York")!
      ).day,
      12)
  }

  func testEveryBilingualDateIconIsRegisteredInBuiltApp() throws {
    let icons = try XCTUnwrap(
      Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any])
    let alternates = try XCTUnwrap(icons["CFBundleAlternateIcons"] as? [String: [String: Any]])
    XCTAssertEqual(alternates.count, 434)
    for language in AppLanguage.allCases {
      for weekday in 1...7 {
        for day in 1...31 {
          let name = "CalendarDate_\(language.rawValue)_w\(weekday)_d\(day)"
          XCTAssertNotNil(CalendarIconDate(iconName: name))
          let registration = try XCTUnwrap(alternates[name], name)
          XCTAssertEqual(registration["CFBundleIconName"] as? String, name)
        }
      }
    }
    for invalid in [
      "", "Other_en_w2_d12", "CalendarDate_fr_w2_d12", "CalendarDate_en_w8_d12",
      "CalendarDate_en_w2_d32",
    ] {
      XCTAssertNil(CalendarIconDate(iconName: invalid))
    }
  }

  @MainActor
  func testForegroundRefreshDeduplicatesAndChangesAfterMidnightOrLanguageChange() async {
    let application = MockIconApplication()
    var currentDate = date("2026-10-12T12:00:00Z")
    var language = AppLanguage.english
    let controller = CalendarIconController(
      application: application, defaults: nil, now: { currentDate },
      language: { language }, timeZone: { self.utc })
    await controller.refresh()
    await controller.refresh()
    XCTAssertEqual(application.changes, ["CalendarDate_en_w2_d12"])
    currentDate = date("2026-10-13T12:00:00Z")
    await controller.refresh()
    XCTAssertEqual(controller.currentLabel, "Tuesday 13")
    language = .chinese
    await controller.refresh()
    XCTAssertEqual(
      application.changes,
      ["CalendarDate_en_w2_d12", "CalendarDate_en_w3_d13", "CalendarDate_zh-Hans_w3_d13"])
    XCTAssertEqual(controller.currentLabel, "星期二 13")
  }

  @MainActor
  func testBackgroundAndIsolatedModesNeverChangeSystemIcon() async {
    let application = MockIconApplication()
    application.active = false
    let controller = CalendarIconController(application: application, defaults: nil)
    await controller.refresh()
    XCTAssertTrue(application.changes.isEmpty)
    application.active = true
    let isolated = CalendarIconController(application: application, defaults: nil, isolated: true)
    await isolated.refresh()
    XCTAssertTrue(application.changes.isEmpty)
    await controller.refresh()
    XCTAssertEqual(application.changes.count, 1)
  }

  @MainActor
  func testPreferencePersistsAndDisablingRestoresPrimaryIcon() async throws {
    let suite = "CalendarSix-icon-test-\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let application = MockIconApplication()
    application.iconName = "CalendarDate_en_w2_d12"
    let controller = CalendarIconController(application: application, defaults: defaults)
    XCTAssertTrue(controller.enabled)
    await controller.setEnabled(false)
    XCTAssertNil(application.iconName)
    XCTAssertEqual(application.changes.count, 1)
    XCTAssertNil(application.changes[0])
    let relaunched = CalendarIconController(application: application, defaults: defaults)
    XCTAssertFalse(relaunched.enabled)
    await relaunched.refresh()
    XCTAssertEqual(application.changes.count, 1)
  }

  @MainActor
  func testFailedIconChangePreservesCurrentIconAndCanBeRetried() async {
    let application = MockIconApplication()
    application.iconName = "CalendarDate_en_w2_d12"
    application.shouldFail = true
    let controller = CalendarIconController(
      application: application, defaults: nil, now: { self.date("2026-10-13T12:00:00Z") },
      language: { .english }, timeZone: { self.utc })
    await controller.refresh()
    XCTAssertEqual(controller.currentLabel, "Monday 12")
    XCTAssertNotNil(controller.error)
    application.shouldFail = false
    await controller.refresh()
    XCTAssertEqual(controller.currentLabel, "Tuesday 13")
    XCTAssertNil(controller.error)
  }

  @MainActor
  func testTransientSystemBusyErrorRetriesWithoutDuplicateSuccessfulChange() async {
    let application = MockIconApplication()
    application.busyFailures = 1
    let controller = CalendarIconController(
      application: application, defaults: nil,
      now: { self.date("2026-10-13T12:00:00Z") }, language: { .english }, timeZone: { self.utc })
    await controller.refresh()
    XCTAssertEqual(application.changes.count, 2)
    XCTAssertEqual(controller.currentLabel, "Tuesday 13")
    XCTAssertNil(controller.error)
    await controller.refresh()
    XCTAssertEqual(application.changes.count, 2)
  }

  @MainActor
  func testUnsupportedDeviceDoesNotAttemptChange() async {
    let application = MockIconApplication()
    application.supported = false
    let controller = CalendarIconController(application: application, defaults: nil)
    await controller.refresh()
    XCTAssertNotNil(controller.error)
    XCTAssertTrue(application.changes.isEmpty)
  }

  @MainActor
  func testOverlappingRefreshUsesLatestDateWithoutConcurrentRequests() async {
    let application = MockIconApplication()
    application.suspendNext = true
    var currentDate = date("2026-10-12T12:00:00Z")
    let controller = CalendarIconController(
      application: application, defaults: nil, now: { currentDate },
      language: { .english }, timeZone: { self.utc })
    let first = Task { await controller.refresh() }
    for _ in 0..<10 {
      if application.continuation != nil { break }
      await Task.yield()
    }
    XCTAssertNotNil(application.continuation)
    currentDate = date("2026-10-13T12:00:00Z")
    await controller.refresh()
    XCTAssertEqual(application.changes.count, 1)
    application.continuation?.resume()
    application.continuation = nil
    await first.value
    XCTAssertEqual(application.changes, ["CalendarDate_en_w2_d12", "CalendarDate_en_w3_d13"])
    XCTAssertEqual(controller.currentLabel, "Tuesday 13")
    XCTAssertFalse(controller.updating)
  }
}

@MainActor
private final class MockIconApplication: CalendarIconApplication {
  var supported = true
  var active = true
  var iconName: String?
  var changes: [String?] = []
  var shouldFail = false
  var busyFailures = 0
  var suspendNext = false
  var continuation: CheckedContinuation<Void, Never>?

  func changeIcon(to name: String?) async throws {
    changes.append(name)
    if suspendNext {
      suspendNext = false
      await withCheckedContinuation { continuation = $0 }
    }
    if shouldFail { throw NSError(domain: "CalendarIconTest", code: 1) }
    if busyFailures > 0 {
      busyFailures -= 1
      throw NSError(domain: NSPOSIXErrorDomain, code: 35)
    }
    iconName = name
  }
}
