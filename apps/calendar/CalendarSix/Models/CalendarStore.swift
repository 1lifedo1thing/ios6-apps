import EventKit
import Foundation
import Observation

struct CalendarSnapshot: Codable {
  var version = 1
  var calendars: [CalendarSource]
  var events: [CalendarEvent]
  var preferences: CalendarPreferences
}

@MainActor @Observable
final class CalendarStore {
  private(set) var calendars: [CalendarSource] = []
  private(set) var events: [CalendarEvent] = []
  private(set) var systemCalendars: [CalendarSource] = []
  private(set) var systemEvents: [CalendarEvent] = []
  var preferences = CalendarPreferences()
  var error: String?
  var notificationStatus = "Not Enabled"
  var connecting = false
  private(set) var canWrite = true
  let testing: Bool
  let demo: Bool
  let now: Date
  @ObservationIgnored private let fileURL: URL?
  @ObservationIgnored private let systemService = SystemCalendarService()
  @ObservationIgnored private let reminders = CalendarReminders()
  @ObservationIgnored private var reminderTask: Task<Void, Never>?
  @ObservationIgnored private var loadedRange: DateInterval?

  init(fileURL: URL?, testing: Bool = false, demo: Bool = false, now: Date = .now) {
    self.fileURL = fileURL
    self.testing = testing
    self.demo = demo
    self.now = now
    calendars = [
      CalendarSource(id: "home", title: "Home", color: .blue, builtIn: true),
      CalendarSource(id: "work", title: "Work", color: .green, builtIn: true),
    ]
    if let fileURL, FileManager.default.fileExists(atPath: fileURL.path) {
      do {
        let snapshot = try JSONDecoder().decode(
          CalendarSnapshot.self, from: Data(contentsOf: fileURL))
        guard snapshot.version == 1, !snapshot.calendars.isEmpty,
          Set(snapshot.calendars.map(\.id)).count == snapshot.calendars.count,
          Set(snapshot.events.map(\.id)).count == snapshot.events.count,
          snapshot.events.allSatisfy({ $0.end > $0.start && $0.systemID == nil }),
          snapshot.events.allSatisfy({ item in
            snapshot.calendars.contains { $0.id == item.calendarID }
          })
        else {
          throw CalendarFailure.missing
        }
        calendars = snapshot.calendars
        events = snapshot.events
        preferences = snapshot.preferences
      } catch {
        canWrite = false
        self.error = L10n.text(
          "Calendar data could not be read. The original file has been preserved.")
      }
    }
    if demo { events = Self.samples(now: now, calendar: calendar) }
  }

  var calendar: Calendar { CalendarMath.gregorian(mondayFirst: preferences.mondayFirst) }
  var allCalendars: [CalendarSource] { calendars + systemCalendars }
  var writableCalendars: [CalendarSource] { allCalendars.filter(\.writable) }
  var defaultCalendar: CalendarSource {
    writableCalendars.first { $0.id == preferences.defaultCalendarID } ?? calendars[0]
  }
  var pendingInvitations: [CalendarEvent] { systemEvents.filter(\.pendingInvitation) }
  func source(_ id: String) -> CalendarSource? { allCalendars.first { $0.id == id } }
  func isVisible(_ id: String) -> Bool { !preferences.hiddenCalendarIDs.contains(id) }
  func toggle(_ id: String) {
    if isVisible(id) {
      preferences.hiddenCalendarIDs.insert(id)
    } else {
      preferences.hiddenCalendarIDs.remove(id)
    }
    persist()
  }
  func showAll(_ show: Bool) {
    preferences.hiddenCalendarIDs = show ? [] : Set(allCalendars.map(\.id))
    persist()
  }

  func occurrences(in range: DateInterval, query: String = "") -> [EventOccurrence] {
    let local = events.filter { isVisible($0.calendarID) }.flatMap {
      CalendarMath.occurrences(of: $0, in: range, calendar: calendar)
    }
    let system = systemEvents.filter {
      isVisible($0.calendarID) && CalendarMath.overlaps(start: $0.start, end: $0.end, range: range)
    }.map { EventOccurrence(event: $0, start: $0.start, end: $0.end) }
    return (local + system).filter {
      query.isEmpty
        || [$0.event.title, $0.event.location, $0.event.notes].contains {
          $0.localizedStandardContains(query)
        }
    }.sorted {
      if $0.start != $1.start { return $0.start < $1.start }
      if $0.event.allDay != $1.event.allDay { return $0.event.allDay }
      return $0.event.title.localizedStandardCompare($1.event.title) == .orderedAscending
    }
  }
  func occurrences(on date: Date) -> [EventOccurrence] {
    guard let range = calendar.dateInterval(of: .day, for: date) else { return [] }
    return occurrences(in: range)
  }

  func draft(on date: Date) -> CalendarEvent {
    let start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
    return CalendarEvent(
      start: start, end: start.addingTimeInterval(3600), calendarID: defaultCalendar.id)
  }

  @discardableResult
  func save(_ input: CalendarEvent, occurrence: EventOccurrence? = nil, scope: SeriesScope = .all)
    -> Bool
  {
    guard canWrite else { return false }
    let value = CalendarMath.normalized(input, calendar: calendar)
    guard !value.title.isEmpty else {
      error = CalendarFailure.invalidTitle.localizedDescription
      return false
    }
    if !value.url.isEmpty {
      guard let url = URL(string: value.url),
        ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
        url.host != nil
      else {
        error = CalendarFailure.invalidURL.localizedDescription
        return false
      }
    }
    guard source(value.calendarID)?.writable == true else {
      error = CalendarFailure.readOnly.localizedDescription
      return false
    }
    if value.calendarID.hasPrefix("system:") || occurrence?.event.systemID != nil {
      guard value.calendarID.hasPrefix("system:") else {
        error = CalendarFailure.readOnly.localizedDescription
        return false
      }
      do {
        try systemService.save(value, original: occurrence?.event, scope: scope)
        refreshSystem()
        return true
      } catch {
        self.error = error.localizedDescription
        return false
      }
    }
    let previous = events
    var updated = value
    if let occurrence, occurrence.event.isRecurring, scope == .all {
      let shift = calendar.dateComponents(
        [.day, .hour, .minute, .second], from: occurrence.start, to: value.start)
      updated.start =
        calendar.date(byAdding: shift, to: occurrence.event.start) ?? occurrence.event.start
      updated.end = updated.start.addingTimeInterval(value.end.timeIntervalSince(value.start))
      updated.excludedDates = occurrence.event.excludedDates.compactMap {
        calendar.date(byAdding: shift, to: $0)
      }
    }
    if let occurrence, occurrence.event.isRecurring, scope != .all,
      let index = events.firstIndex(where: { $0.id == occurrence.event.id })
    {
      if scope == .thisEvent {
        events[index].excludedDates.append(occurrence.start)
        updated.repeatRule = .never
        updated.repeatUntil = nil
      } else {
        events[index].repeatUntil = occurrence.start.addingTimeInterval(-1)
      }
      updated.id = UUID().uuidString
      updated.excludedDates = []
      events.append(updated)
    } else if let index = events.firstIndex(where: { $0.id == value.id }) {
      events[index] = updated
    } else {
      events.append(updated)
    }
    guard persist() else {
      events = previous
      return false
    }
    scheduleReminders()
    return true
  }

  @discardableResult
  func delete(_ occurrence: EventOccurrence, scope: SeriesScope = .all) -> Bool {
    guard canWrite else { return false }
    if occurrence.event.systemID != nil {
      do {
        try systemService.delete(occurrence.event, scope: scope)
        refreshSystem()
        return true
      } catch {
        self.error = error.localizedDescription
        return false
      }
    }
    let previous = events
    if let index = events.firstIndex(where: { $0.id == occurrence.event.id }) {
      if scope == .thisEvent, events[index].isRecurring {
        events[index].excludedDates.append(occurrence.start)
      } else if scope == .future, events[index].isRecurring {
        events[index].repeatUntil = occurrence.start.addingTimeInterval(-1)
      } else {
        events.remove(at: index)
      }
    }
    guard persist() else {
      events = previous
      return false
    }
    scheduleReminders()
    return true
  }

  @discardableResult
  func saveCalendar(_ source: CalendarSource) -> Bool {
    guard canWrite, !source.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return false
    }
    let old = calendars
    if let index = calendars.firstIndex(where: { $0.id == source.id }) {
      calendars[index] = source
    } else {
      calendars.append(source)
    }
    guard persist() else {
      calendars = old
      return false
    }
    return true
  }
  @discardableResult
  func deleteCalendar(_ id: String) -> Bool {
    guard canWrite, calendars.count > 1, calendars.contains(where: { $0.id == id }) else {
      return false
    }
    let oldCalendars = calendars
    let oldEvents = events
    let oldPreferences = preferences
    calendars.removeAll { $0.id == id }
    events.removeAll { $0.calendarID == id }
    preferences.hiddenCalendarIDs.remove(id)
    if preferences.defaultCalendarID == id { preferences.defaultCalendarID = calendars[0].id }
    guard persist() else {
      calendars = oldCalendars
      events = oldEvents
      preferences = oldPreferences
      return false
    }
    scheduleReminders()
    return true
  }

  @discardableResult
  func persist() -> Bool {
    guard canWrite else { return false }
    guard let fileURL else { return true }
    do {
      try FileManager.default.createDirectory(
        at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      let data = try JSONEncoder().encode(
        CalendarSnapshot(calendars: calendars, events: events, preferences: preferences))
      try data.write(to: fileURL, options: .atomic)
      return true
    } catch {
      self.error = L10n.text("Unable to save calendar data. Please try again.")
      return false
    }
  }

  func loadSystem(around date: Date) {
    let start = calendar.date(byAdding: .year, value: -1, to: date) ?? date
    let end = calendar.date(byAdding: .year, value: 1, to: date) ?? date
    loadedRange = DateInterval(start: start, end: end)
    refreshSystem()
  }
  func refreshSystem() {
    guard preferences.systemEnabled, !testing, !demo, let range = loadedRange else {
      systemCalendars = []
      systemEvents = []
      return
    }
    let result = systemService.load(in: range)
    systemCalendars = result.sources
    systemEvents = result.events
  }
  func connectSystem() async {
    guard !testing, !demo else {
      error = L10n.text("System calendars are disabled in the isolated demo.")
      return
    }
    connecting = true
    defer { connecting = false }
    do {
      guard try await systemService.requestAccess() else { throw CalendarFailure.permission }
      preferences.systemEnabled = true
      persist()
      refreshSystem()
    } catch { self.error = error.localizedDescription }
  }
  func disconnectSystem() {
    preferences.systemEnabled = false
    persist()
    refreshSystem()
  }
  func enableReminders() async {
    guard !testing, !demo else {
      error = L10n.text("Reminders are disabled in the isolated demo.")
      return
    }
    do {
      try await reminders.requestAccess()
      await refreshNotifications()
      scheduleReminders()
    } catch { self.error = error.localizedDescription }
  }
  func refreshNotifications() async {
    guard !testing, !demo else { return }
    notificationStatus = await reminders.status()
  }
  func scheduleReminders() {
    guard !testing, !demo else { return }
    let previous = reminderTask
    previous?.cancel()
    let items = events
    let calendar = calendar
    reminderTask = Task { [weak self] in
      await previous?.value
      guard !Task.isCancelled else { return }
      do { try await self?.reminders.schedule(events: items, calendar: calendar) } catch {
        if !Task.isCancelled {
          self?.error = L10n.text("Unable to schedule reminders. Please try again.")
        }
      }
    }
  }

  private static func samples(now: Date, calendar: Calendar) -> [CalendarEvent] {
    func time(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
      let date = calendar.date(byAdding: .day, value: day, to: now)!
      return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date)!
    }
    var meeting = CalendarEvent(
      id: "demo-meeting", title: L10n.text("Design Meeting"), location: L10n.text("Studio"),
      start: time(0, 10), end: time(0, 11), calendarID: "work")
    meeting.notes = L10n.text("Review the new calendar design.")
    meeting.repeatRule = .weekly
    var lunch = CalendarEvent(
      id: "demo-lunch", title: L10n.text("Lunch with friends"), location: L10n.text("Café"),
      start: time(0, 12, 30), end: time(0, 13, 30), calendarID: "home")
    lunch.alertMinutes = [15]
    let birthday = CalendarEvent(
      id: "demo-birthday", title: L10n.text("Alex’s Birthday"),
      start: calendar.startOfDay(for: time(2, 0)), end: calendar.startOfDay(for: time(3, 0)),
      allDay: true, calendarID: "home")
    let walk = CalendarEvent(
      id: "demo-walk", title: L10n.text("Evening Walk"),
      start: time(0, 18), end: time(0, 19), calendarID: "home")
    return [meeting, lunch, birthday, walk]
  }
}
