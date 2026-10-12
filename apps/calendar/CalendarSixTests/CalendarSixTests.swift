import XCTest

@testable import CalendarSix

final class CalendarMathTests: XCTestCase {
  private let utc = CalendarMath.gregorian(timeZone: TimeZone(secondsFromGMT: 0)!)
  private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
  private func event(_ start: String, _ end: String) -> CalendarEvent {
    CalendarEvent(
      title: "Original user text", start: date(start), end: date(end), calendarID: "home",
      timeZoneID: "GMT")
  }
  func testMonthGridLeapYearAndWeekStart() {
    let february = date("2024-02-15T12:00:00Z")
    let days = CalendarMath.monthDays(containing: february, calendar: utc)
    XCTAssertEqual(days.count, 35)
    XCTAssertEqual(days.first, date("2024-01-28T00:00:00Z"))
    XCTAssertTrue(days.contains(date("2024-02-29T00:00:00Z")))
    var monday = utc
    monday.firstWeekday = 2
    XCTAssertEqual(
      CalendarMath.monthDays(containing: february, calendar: monday).first,
      date("2024-01-29T00:00:00Z"))
    XCTAssertEqual(
      CalendarMath.monthDays(containing: date("2026-05-10T00:00:00Z"), calendar: utc).count, 42)
  }
  func testMonthlySeriesSkipsMissingDatesWithoutDrifting() {
    var item = event("2026-01-31T10:00:00Z", "2026-01-31T11:00:00Z")
    item.repeatRule = .monthly
    let values = CalendarMath.occurrences(
      of: item,
      in: DateInterval(start: date("2026-01-01T00:00:00Z"), end: date("2026-06-01T00:00:00Z")),
      calendar: utc)
    XCTAssertEqual(
      values.map(\.start),
      [date("2026-01-31T10:00:00Z"), date("2026-03-31T10:00:00Z"), date("2026-05-31T10:00:00Z")])
  }
  func testLeapDayYearlySeries() {
    var item = event("2024-02-29T10:00:00Z", "2024-02-29T11:00:00Z")
    item.repeatRule = .yearly
    let values = CalendarMath.occurrences(
      of: item,
      in: DateInterval(start: date("2024-01-01T00:00:00Z"), end: date("2029-01-01T00:00:00Z")),
      calendar: utc)
    XCTAssertEqual(values.map { utc.component(.year, from: $0.start) }, [2024, 2028])
  }
  func testDailySeriesKeepsLocalTimeAcrossDST() {
    let london = CalendarMath.gregorian(timeZone: TimeZone(identifier: "Europe/London")!)
    var item = event("2026-03-28T09:00:00Z", "2026-03-28T10:00:00Z")
    item.timeZoneID = "Europe/London"
    item.repeatRule = .daily
    let values = CalendarMath.occurrences(
      of: item,
      in: DateInterval(start: date("2026-03-28T00:00:00Z"), end: date("2026-03-31T00:00:00Z")),
      calendar: london)
    XCTAssertEqual(values.count, 3)
    XCTAssertEqual(values.map { london.component(.hour, from: $0.start) }, [9, 9, 9])
    XCTAssertEqual(values[1].start, date("2026-03-29T08:00:00Z"))
  }
  func testRepeatEndAndExceptionAreInclusiveAndExact() {
    var item = event("2026-10-12T09:00:00Z", "2026-10-12T10:00:00Z")
    item.repeatRule = .daily
    item.repeatUntil = date("2026-10-15T09:00:00Z")
    item.excludedDates = [date("2026-10-13T09:00:00Z")]
    let values = CalendarMath.occurrences(
      of: item,
      in: DateInterval(start: date("2026-10-12T00:00:00Z"), end: date("2026-10-20T00:00:00Z")),
      calendar: utc)
    XCTAssertEqual(values.map { utc.component(.day, from: $0.start) }, [12, 14, 15])
  }
  func testAllDayMultiDayAndExclusiveEnd() {
    var item = event("2026-10-12T00:00:00Z", "2026-10-14T00:00:00Z")
    item.allDay = true
    for day in [12, 13] {
      let range = utc.dateInterval(of: .day, for: date("2026-10-\(day)T12:00:00Z"))!
      XCTAssertEqual(CalendarMath.occurrences(of: item, in: range, calendar: utc).count, 1)
    }
    let range = utc.dateInterval(of: .day, for: date("2026-10-14T12:00:00Z"))!
    XCTAssertTrue(CalendarMath.occurrences(of: item, in: range, calendar: utc).isEmpty)
  }
  func testAllDayRecurrencePreservesDayLengthAcrossDST() {
    let london = CalendarMath.gregorian(timeZone: TimeZone(identifier: "Europe/London")!)
    var item = event("2026-03-28T00:00:00Z", "2026-03-29T00:00:00Z")
    item.allDay = true
    item.timeZoneID = "Europe/London"
    item.repeatRule = .daily
    let values = CalendarMath.occurrences(
      of: item,
      in: DateInterval(start: date("2026-03-29T00:00:00Z"), end: date("2026-03-29T23:00:00Z")),
      calendar: london)
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values[0].end.timeIntervalSince(values[0].start), 23 * 3600)
  }
  func testFortnightlyAndAncientSeriesUseCorrectAnchor() {
    var item = event("1990-01-01T09:00:00Z", "1990-01-01T10:00:00Z")
    item.repeatRule = .fortnightly
    let values = CalendarMath.occurrences(
      of: item,
      in: DateInterval(start: date("2026-10-01T00:00:00Z"), end: date("2026-11-01T00:00:00Z")),
      calendar: utc)
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values[1].start.timeIntervalSince(values[0].start), 14 * 86400)
  }
  func testTimelineOverlappingGroupsAndMidnightClipping() {
    let a = event("2026-10-12T09:00:00Z", "2026-10-12T11:00:00Z")
    let b = event("2026-10-12T10:00:00Z", "2026-10-12T12:00:00Z")
    let c = event("2026-10-12T13:00:00Z", "2026-10-12T14:00:00Z")
    let items = [a, b, c].map { EventOccurrence(event: $0, start: $0.start, end: $0.end) }
    let values = TimelineLayout.placements(items, on: a.start, calendar: utc)
    XCTAssertEqual(values.map(\.column), [0, 1, 0])
    XCTAssertEqual(values.map(\.columns), [2, 2, 1])
    let cross = event("2026-10-11T23:00:00Z", "2026-10-12T01:00:00Z")
    let clipped = TimelineLayout.placements(
      [EventOccurrence(event: cross, start: cross.start, end: cross.end)], on: a.start,
      calendar: utc)
    XCTAssertEqual(clipped[0].startMinute, 0)
    XCTAssertEqual(clipped[0].endMinute, 60)
  }
  func testLanguageSelectionAndDateFormatting() {
    XCTAssertEqual(AppLanguage.preferred(["zh-Hant-TW", "en"]), .chinese)
    XCTAssertEqual(AppLanguage.preferred(["fr-FR", "zh"]), .english)
    XCTAssertEqual(AppLanguage.preferred([]), .english)
    let date = date("2026-10-12T09:00:00Z")
    XCTAssertTrue(
      CalendarFormat.date(date, template: "MMMM yyyy", language: .chinese).contains("10月"))
    XCTAssertTrue(
      CalendarFormat.date(date, template: "MMMM yyyy", language: .english).contains("October"))
  }
}

@MainActor
final class CalendarStoreTests: XCTestCase {
  private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
  private func makeStore(file: URL? = nil) -> CalendarStore {
    CalendarStore(fileURL: file, testing: true, now: date("2026-10-12T08:00:00Z"))
  }
  private func weekly(_ store: CalendarStore) -> CalendarEvent {
    var item = store.draft(on: store.now)
    item.title = "User-written 会议"
    item.repeatRule = .weekly
    XCTAssertTrue(store.save(item))
    return item
  }
  func testPersistentRoundTripKeepsUserTextAndFilters() throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString + ".json")
    defer { try? FileManager.default.removeItem(at: file) }
    let store = makeStore(file: file)
    let item = weekly(store)
    store.toggle("work")
    let reopened = makeStore(file: file)
    XCTAssertEqual(reopened.events.first?.title, item.title)
    XCTAssertEqual(reopened.events.first?.repeatRule, .weekly)
    XCTAssertFalse(reopened.isVisible("work"))
    XCTAssertTrue(reopened.canWrite)
  }
  func testEditSingleOccurrenceKeepsSeries() {
    let store = makeStore()
    let item = weekly(store)
    let day = store.calendar.date(byAdding: .weekOfYear, value: 1, to: item.start)!
    let occurrence = store.occurrences(on: day)[0]
    var edit = occurrence.event
    edit.start = occurrence.start
    edit.end = occurrence.end
    edit.title = "One exception"
    XCTAssertTrue(store.save(edit, occurrence: occurrence, scope: .thisEvent))
    XCTAssertEqual(store.occurrences(on: day).map { $0.event.title }, ["One exception"])
    XCTAssertEqual(store.occurrences(on: item.start).map { $0.event.title }, [item.title])
    XCTAssertEqual(store.events.count, 2)
  }
  func testEditAllFromLaterOccurrencePreservesEarlierAnchor() {
    let store = makeStore()
    let item = weekly(store)
    let day = store.calendar.date(byAdding: .weekOfYear, value: 2, to: item.start)!
    let occurrence = store.occurrences(on: day)[0]
    var edit = occurrence.event
    edit.start = occurrence.start.addingTimeInterval(3600)
    edit.end = occurrence.end.addingTimeInterval(3600)
    edit.title = "Entire series"
    XCTAssertTrue(store.save(edit, occurrence: occurrence, scope: .all))
    XCTAssertEqual(store.events.count, 1)
    XCTAssertEqual(store.events[0].start, item.start.addingTimeInterval(3600))
    XCTAssertEqual(store.occurrences(on: item.start).first?.event.title, "Entire series")
  }
  func testFutureEditSplitsSeriesAndFutureDeleteTruncates() {
    let store = makeStore()
    let item = weekly(store)
    let day = store.calendar.date(byAdding: .weekOfYear, value: 1, to: item.start)!
    let occurrence = store.occurrences(on: day)[0]
    var edit = occurrence.event
    edit.start = occurrence.start
    edit.end = occurrence.end
    edit.title = "Future series"
    XCTAssertTrue(store.save(edit, occurrence: occurrence, scope: .future))
    XCTAssertEqual(store.occurrences(on: item.start).first?.event.title, item.title)
    XCTAssertEqual(store.occurrences(on: day).map { $0.event.title }, ["Future series"])
    let future = store.occurrences(on: day)[0]
    XCTAssertTrue(store.delete(future, scope: .future))
    XCTAssertTrue(store.occurrences(on: day).isEmpty)
    XCTAssertEqual(store.occurrences(on: item.start).count, 1)
  }
  func testDeleteSingleAndAllOccurrences() {
    let store = makeStore()
    let item = weekly(store)
    XCTAssertTrue(store.delete(store.occurrences(on: item.start)[0], scope: .thisEvent))
    XCTAssertTrue(store.occurrences(on: item.start).isEmpty)
    let next = store.calendar.date(byAdding: .weekOfYear, value: 1, to: item.start)!
    XCTAssertTrue(store.delete(store.occurrences(on: next)[0], scope: .all))
    XCTAssertTrue(store.events.isEmpty)
  }
  func testCalendarFilteringSearchAndCascadeDelete() {
    let store = makeStore()
    _ = weekly(store)
    XCTAssertEqual(store.occurrences(on: store.now).count, 1)
    store.toggle("home")
    XCTAssertTrue(store.occurrences(on: store.now).isEmpty)
    store.showAll(true)
    let range = store.calendar.dateInterval(of: .day, for: store.now)!
    XCTAssertEqual(store.occurrences(in: range, query: "会议").count, 1)
    XCTAssertTrue(store.occurrences(in: range, query: "not present").isEmpty)
    XCTAssertTrue(store.deleteCalendar("home"))
    XCTAssertTrue(store.events.isEmpty)
    XCTAssertEqual(store.defaultCalendar.id, "work")
    XCTAssertFalse(store.deleteCalendar("work"))
  }
  func testInvalidInputsDoNotCreateEvents() {
    let store = makeStore()
    var item = store.draft(on: store.now)
    XCTAssertFalse(store.save(item))
    item.title = "Event"
    item.url = "javascript:alert(1)"
    XCTAssertFalse(store.save(item))
    XCTAssertTrue(store.events.isEmpty)
    item.url = "https://example.com"
    XCTAssertTrue(store.save(item))
  }
  func testCorruptDataIsPreservedAndWritesAreBlocked() throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString + ".json")
    defer { try? FileManager.default.removeItem(at: file) }
    let original = Data("corrupt evidence".utf8)
    try original.write(to: file)
    let store = makeStore(file: file)
    XCTAssertFalse(store.canWrite)
    XCTAssertNotNil(store.error)
    var item = store.draft(on: store.now)
    item.title = "Must not overwrite"
    XCTAssertFalse(store.save(item))
    XCTAssertEqual(try Data(contentsOf: file), original)
  }
  func testReminderPlanRespectsExclusionsAndCapsNearestAlerts() {
    let store = makeStore()
    var item = store.draft(on: store.now)
    item.title = "Reminder"
    item.repeatRule = .daily
    item.alertMinutes = [0, 15]
    item.excludedDates = [item.start]
    let plan = CalendarReminders.upcoming(events: [item], now: store.now, calendar: store.calendar)
    XCTAssertEqual(plan.count, 60)
    XCTAssertEqual(plan.map { $0.1 }, plan.map { $0.1 }.sorted())
    XCTAssertTrue(
      plan.allSatisfy { $0.1 > store.now && !store.calendar.isDate($0.1, inSameDayAs: item.start) })
    XCTAssertEqual(Set(plan.map { $0.0 }).count, plan.count)
  }
  func testPersistenceFailureRollsBackEventMutation() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("calendar.json")
    let store = makeStore(file: file)
    try FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)
    var event = store.draft(on: store.now)
    event.title = "Cannot save"
    XCTAssertFalse(store.save(event))
    XCTAssertTrue(store.events.isEmpty)
    XCTAssertNotNil(store.error)
  }
}
