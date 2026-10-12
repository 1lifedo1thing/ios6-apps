import XCTest

@testable import CalendarSix

final class CalendarPickerDateTests: XCTestCase {
  private let utc = CalendarMath.gregorian(timeZone: TimeZone(secondsFromGMT: 0)!)
  private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }

  func testMonthAndYearChangesClampMissingDays() {
    let january = date("2024-01-31T15:42:00Z")
    let february = CalendarPickerDate.replacing(.month, with: 2, in: january, calendar: utc)
    XCTAssertEqual(february, date("2024-02-29T15:42:00Z"))
    XCTAssertEqual(
      CalendarPickerDate.replacing(.year, with: 2025, in: february, calendar: utc),
      date("2025-02-28T15:42:00Z"))
    XCTAssertEqual(
      CalendarPickerDate.range(.day, date: february, calendar: utc, twelveHour: false), 1..<30)
  }
  func testTwelveHourMidnightNoonAndPeriodChanges() {
    let morning = date("2026-10-12T09:17:00Z")
    let midnight = CalendarPickerDate.replacing(
      .hour, with: 12, in: morning, calendar: utc, twelveHour: true)
    XCTAssertEqual(midnight, date("2026-10-12T00:17:00Z"))
    let noon = CalendarPickerDate.replacing(
      .period, with: 1, in: midnight, calendar: utc, twelveHour: true)
    XCTAssertEqual(noon, date("2026-10-12T12:17:00Z"))
    XCTAssertEqual(CalendarPickerDate.value(.hour, in: noon, calendar: utc, twelveHour: true), 12)
    XCTAssertEqual(CalendarPickerDate.value(.period, in: noon, calendar: utc, twelveHour: true), 1)
  }
  func testChangingMinuteAndTwentyFourHourRetainsDate() {
    let start = date("2026-10-12T23:59:00Z")
    let changed = CalendarPickerDate.replacing(.minute, with: 0, in: start, calendar: utc)
    XCTAssertEqual(changed, date("2026-10-12T23:00:00Z"))
    XCTAssertEqual(
      CalendarPickerDate.replacing(.hour, with: 0, in: changed, calendar: utc),
      date("2026-10-12T00:00:00Z"))
  }
  func testDateWheelKeepsLocalTimeAcrossDSTAndNormalizesMissingHour() {
    let london = CalendarMath.gregorian(timeZone: TimeZone(identifier: "Europe/London")!)
    let start = date("2026-03-28T09:30:00Z")
    let index = CalendarPickerDate.value(.date, in: start, calendar: london, twelveHour: false)
    XCTAssertEqual(
      CalendarPickerDate.replacing(.date, with: index + 1, in: start, calendar: london),
      date("2026-03-29T08:30:00Z"))
    let missing = CalendarPickerDate.replacing(
      .hour, with: 1, in: date("2026-03-29T00:30:00Z"), calendar: london)
    XCTAssertEqual(london.component(.day, from: missing), 29)
    XCTAssertEqual(london.component(.hour, from: missing), 2)
  }
  func testRepeatEndMinimumAndDistantDateRoundTrip() {
    let start = date("2026-10-12T09:00:00Z")
    XCTAssertEqual(
      CalendarPickerDate.replacing(.day, with: 1, in: start, calendar: utc, minimum: start), start)
    for value in ["1900-01-01T12:34:00Z", "2400-02-29T12:34:00Z"] {
      let input = date(value)
      let index = CalendarPickerDate.value(.date, in: input, calendar: utc, twelveHour: false)
      XCTAssertEqual(
        CalendarPickerDate.replacing(.date, with: index, in: input, calendar: utc), input)
    }
  }
}
