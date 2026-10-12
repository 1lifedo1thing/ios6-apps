import EventKit
import XCTest

@testable import CalendarSix

@MainActor
final class SystemCalendarIntegrationTests: XCTestCase {
  func testSystemCalendarReadCreateEditRecurringDelete() async throws {
    #if targetEnvironment(simulator)
      guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
        throw XCTSkip(
          "Grant calendar-full access to CalendarSix on the simulator before running this integration test."
        )
      }
      let eventStore = EKEventStore()
      let source = try XCTUnwrap(eventStore.sources.first { $0.sourceType == .local })
      let fixture = EKCalendar(for: .event, eventStore: eventStore)
      fixture.title = "CalendarSix Integration " + UUID().uuidString
      fixture.source = source
      try eventStore.saveCalendar(fixture, commit: true)
      defer { try? eventStore.removeCalendar(fixture, commit: true) }

      let service = SystemCalendarService()
      let start = ISO8601DateFormatter().date(from: "2026-10-12T09:00:00Z")!
      let range = DateInterval(
        start: start.addingTimeInterval(-3600), end: start.addingTimeInterval(22 * 86400))
      var draft = CalendarEvent(
        title: "Integration fixture", start: start, end: start.addingTimeInterval(3600),
        calendarID: "system:" + fixture.calendarIdentifier)
      draft.repeatRule = .weekly
      draft.alertMinutes = [15]
      try service.save(draft, original: nil, scope: .all)
      var result = service.load(in: range)
      XCTAssertTrue(result.sources.contains { $0.id == draft.calendarID && $0.writable })
      var occurrences = result.events.filter { $0.calendarID == draft.calendarID }
      XCTAssertEqual(occurrences.count, 4)
      let original = try XCTUnwrap(occurrences.first)
      XCTAssertTrue(original.hasRecurrence)
      XCTAssertEqual(original.alertMinutes, [15])
      var edited = original
      edited.title = "Edited one occurrence"
      try service.save(edited, original: original, scope: .thisEvent)
      result = service.load(in: range)
      occurrences = result.events.filter { $0.calendarID == draft.calendarID }
      XCTAssertEqual(occurrences.filter { $0.title == edited.title }.count, 1)
      XCTAssertEqual(occurrences.filter { $0.title == draft.title }.count, 3)
      let changed = try XCTUnwrap(occurrences.first { $0.title == edited.title })
      try service.delete(changed, scope: .thisEvent)
      result = service.load(in: range)
      XCTAssertEqual(result.events.filter { $0.calendarID == draft.calendarID }.count, 3)
      let future = try XCTUnwrap(result.events.first { $0.calendarID == draft.calendarID })
      try service.delete(future, scope: .future)
      XCTAssertTrue(
        service.load(in: range).events.filter { $0.calendarID == draft.calendarID }.isEmpty)
      let fixtureID = fixture.calendarIdentifier
      try eventStore.removeCalendar(fixture, commit: true)
      eventStore.reset()
      XCTAssertNil(eventStore.calendar(withIdentifier: fixtureID))
    #else
      throw XCTSkip("The integration fixture is only created in the simulator.")
    #endif
  }
}
