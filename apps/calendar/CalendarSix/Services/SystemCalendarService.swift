import EventKit
import Foundation

@MainActor
final class SystemCalendarService {
  private let store = EKEventStore()
  private var fetched: [String: EKEvent] = [:]
  var authorized: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }

  func requestAccess() async throws -> Bool {
    let granted = try await store.requestFullAccessToEvents()
    if granted { store.reset() }
    return granted
  }

  func load(in range: DateInterval) -> (sources: [CalendarSource], events: [CalendarEvent]) {
    guard authorized else {
      fetched = [:]
      return ([], [])
    }
    let calendars = store.calendars(for: .event)
    let sources = calendars.map { source in
      CalendarSource(
        id: "system:" + source.calendarIdentifier, title: source.title,
        color: Self.color(source.cgColor), system: true,
        writable: source.allowsContentModifications,
        account: source.source.title)
    }
    let predicate = store.predicateForEvents(
      withStart: range.start, end: range.end, calendars: calendars)
    fetched = [:]
    let events = store.events(matching: predicate).compactMap { event -> CalendarEvent? in
      guard let identifier = event.eventIdentifier, let calendar = event.calendar else {
        return nil
      }
      let key = "system:" + identifier + ":" + String(event.startDate.timeIntervalSince1970)
      fetched[key] = event
      let rule = event.recurrenceRules?.first
      var repeatRule: RepeatRule = .never
      if let rule {
        switch rule.frequency {
        case .daily: repeatRule = .daily
        case .weekly: repeatRule = rule.interval == 2 ? .fortnightly : .weekly
        case .monthly: repeatRule = .monthly
        case .yearly: repeatRule = .yearly
        @unknown default: break
        }
      }
      let complex =
        rule.map {
          ![1, 2].contains($0.interval) || ($0.interval == 2 && $0.frequency != .weekly)
            || !($0.daysOfTheWeek ?? []).isEmpty || !($0.daysOfTheMonth ?? []).isEmpty
            || !($0.monthsOfTheYear ?? []).isEmpty || !($0.weeksOfTheYear ?? []).isEmpty
            || !($0.daysOfTheYear ?? []).isEmpty || !($0.setPositions ?? []).isEmpty
            || $0.recurrenceEnd?.occurrenceCount ?? 0 > 0
        } ?? false
      var item = CalendarEvent(
        id: key, title: event.title ?? L10n.text("Untitled Event"),
        location: event.location ?? "", start: event.startDate, end: event.endDate,
        allDay: event.isAllDay, calendarID: "system:" + calendar.calendarIdentifier)
      item.repeatRule = repeatRule
      item.repeatUntil = rule?.recurrenceEnd?.endDate
      item.alertMinutes = (event.alarms ?? []).filter { $0.absoluteDate == nil }.map {
        Int(-$0.relativeOffset / 60)
      }
      item.notes = event.notes ?? ""
      item.url = event.url?.absoluteString ?? ""
      item.timeZoneID = event.timeZone?.identifier ?? TimeZone.current.identifier
      item.busy = event.availability != .free
      item.systemID = identifier
      item.systemOccurrence = event.occurrenceDate ?? event.startDate
      item.hasRecurrence = event.hasRecurrenceRules
      item.complexRecurrence = complex
      item.attendees = (event.attendees ?? []).map { $0.name ?? $0.url.absoluteString }
      item.pendingInvitation =
        event.attendees?.contains(where: { $0.isCurrentUser && $0.participantStatus == .pending })
        ?? false
      return item
    }
    return (sources, events)
  }

  func save(_ value: CalendarEvent, original: CalendarEvent?, scope: SeriesScope) throws {
    guard authorized else { throw CalendarFailure.permission }
    let identifier = String(value.calendarID.dropFirst("system:".count))
    guard let calendar = store.calendar(withIdentifier: identifier),
      calendar.allowsContentModifications
    else {
      throw CalendarFailure.readOnly
    }
    let event: EKEvent
    if let original {
      guard let cached = fetched[original.id] else { throw CalendarFailure.missing }
      event = cached
    } else {
      event = EKEvent(eventStore: store)
    }
    event.calendar = calendar
    event.title = value.title
    event.location = value.location
    event.startDate = value.start
    event.endDate = value.end
    event.isAllDay = value.allDay
    if original == nil || original?.timeZoneID != value.timeZoneID {
      event.timeZone = TimeZone(identifier: value.timeZoneID)
    }
    event.notes = value.notes
    event.url = value.url.isEmpty ? nil : URL(string: value.url)
    if event.availability != .notSupported { event.availability = value.busy ? .busy : .free }
    // Preserve provider-specific recurrence and alarms unless the user changes them.
    if original == nil || original?.repeatRule != value.repeatRule
      || original?.repeatUntil != value.repeatUntil
    {
      if value.repeatRule == .never {
        event.recurrenceRules = nil
      } else {
        let frequency: EKRecurrenceFrequency
        switch value.repeatRule {
        case .daily, .never: frequency = .daily
        case .weekly, .fortnightly: frequency = .weekly
        case .monthly: frequency = .monthly
        case .yearly: frequency = .yearly
        }
        event.recurrenceRules = [
          EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: value.repeatRule.interval,
            end: value.repeatUntil.map { EKRecurrenceEnd(end: $0) })
        ]
      }
    }
    if original == nil || original?.alertMinutes != value.alertMinutes {
      event.alarms = value.alertMinutes.map { EKAlarm(relativeOffset: TimeInterval(-$0 * 60)) }
    }
    try store.save(event, span: scope == .thisEvent ? .thisEvent : .futureEvents, commit: true)
  }

  func delete(_ value: CalendarEvent, scope: SeriesScope) throws {
    guard authorized else { throw CalendarFailure.permission }
    guard let event = fetched[value.id] else { throw CalendarFailure.missing }
    guard event.calendar.allowsContentModifications else { throw CalendarFailure.readOnly }
    try store.remove(event, span: scope == .thisEvent ? .thisEvent : .futureEvents, commit: true)
  }

  private static func color(_ cgColor: CGColor?) -> EventColor {
    guard let parts = cgColor?.components, parts.count >= 3 else { return .blue }
    let r = parts[0]
    let g = parts[1]
    let b = parts[2]
    if r > 0.6 && g < 0.4 { return .red }
    if r > 0.7 && g > 0.4 && b < 0.4 { return .orange }
    if g > r && g > b { return .green }
    if r > 0.4 && b > 0.4 { return .purple }
    return .blue
  }
}

enum CalendarFailure: LocalizedError {
  case permission, readOnly, missing, invalidTitle, invalidURL
  var errorDescription: String? {
    switch self {
    case .permission: return L10n.text("Calendar access is unavailable. Enable access in Settings.")
    case .readOnly: return L10n.text("This calendar is read-only.")
    case .missing: return L10n.text("This event has changed. Please reopen it.")
    case .invalidTitle: return L10n.text("Enter a title for this event.")
    case .invalidURL: return L10n.text("Enter a valid http or https URL.")
    }
  }
}
