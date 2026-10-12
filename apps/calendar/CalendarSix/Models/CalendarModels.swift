import Foundation

enum CalendarMode: String, CaseIterable, Codable {
  case list = "List"
  case day = "Day"
  case month = "Month"
}
enum RepeatRule: String, CaseIterable, Codable {
  case never = "Never"
  case daily = "Every Day"
  case weekly = "Every Week"
  case fortnightly = "Every 2 Weeks"
  case monthly = "Every Month"
  case yearly = "Every Year"
  var component: Calendar.Component {
    switch self {
    case .never, .daily: return .day
    case .weekly, .fortnightly: return .weekOfYear
    case .monthly: return .month
    case .yearly: return .year
    }
  }
  var interval: Int { self == .fortnightly ? 2 : 1 }
}
enum SeriesScope: String, CaseIterable {
  case thisEvent = "Only This Event"
  case future = "All Future Events"
  case all = "All Events"
}
enum EventColor: String, CaseIterable, Codable { case blue, green, red, orange, purple, brown }

struct CalendarSource: Identifiable, Codable, Equatable {
  var id: String = UUID().uuidString
  var title: String
  var color: EventColor
  var builtIn = false
  var system = false
  var writable = true
  var account = "On My iPhone"
  var displayTitle: String { builtIn ? L10n.text(title) : title }
}

struct CalendarEvent: Identifiable, Codable, Equatable {
  var id: String = UUID().uuidString
  var title = ""
  var location = ""
  var start: Date
  var end: Date
  var allDay = false
  var calendarID: String
  var repeatRule: RepeatRule = .never
  var repeatUntil: Date?
  var excludedDates: [Date] = []
  var alertMinutes: [Int] = []
  var notes = ""
  var url = ""
  var timeZoneID: String = TimeZone.current.identifier
  var busy = true
  var systemID: String?
  var systemOccurrence: Date?
  var hasRecurrence = false
  var attendees: [String] = []
  var pendingInvitation = false
  var complexRecurrence = false
  var isRecurring: Bool { repeatRule != .never || hasRecurrence }
}

struct EventOccurrence: Identifiable, Equatable {
  let event: CalendarEvent
  let start: Date
  let end: Date
  var id: String { event.id + ":" + String(start.timeIntervalSince1970) }
}

struct CalendarPreferences: Codable, Equatable {
  var hiddenCalendarIDs: Set<String> = []
  var defaultCalendarID = "home"
  var mondayFirst = false
  var mode: CalendarMode = .month
  var systemEnabled = false
}

enum CalendarMath {
  static func gregorian(timeZone: TimeZone = .current, mondayFirst: Bool = false) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    calendar.firstWeekday = mondayFirst ? 2 : 1
    return calendar
  }

  static func monthDays(containing date: Date, calendar: Calendar) -> [Date] {
    guard let month = calendar.dateInterval(of: .month, for: date) else { return [] }
    let offset = (calendar.component(.weekday, from: month.start) - calendar.firstWeekday + 7) % 7
    let count = calendar.range(of: .day, in: .month, for: date)?.count ?? 30
    let cells = ((count + offset + 6) / 7) * 7
    guard let first = calendar.date(byAdding: .day, value: -offset, to: month.start) else {
      return []
    }
    return (0..<cells).compactMap { calendar.date(byAdding: .day, value: $0, to: first) }
  }

  static func overlaps(start: Date, end: Date, range: DateInterval) -> Bool {
    start < range.end && end > range.start
  }

  static func occurrences(of event: CalendarEvent, in range: DateInterval, calendar input: Calendar)
    -> [EventOccurrence]
  {
    var calendar = input
    calendar.timeZone = TimeZone(identifier: event.timeZoneID) ?? input.timeZone
    if event.repeatRule == .never {
      return overlaps(start: event.start, end: event.end, range: range)
        ? [EventOccurrence(event: event, start: event.start, end: event.end)] : []
    }
    let component = event.repeatRule.component
    let duration = event.end.timeIntervalSince(event.start)
    let distance =
      calendar.dateComponents([component], from: event.start, to: range.start).value(for: component)
      ?? 0
    var index = max(0, distance / event.repeatRule.interval - 2)
    var result: [EventOccurrence] = []
    // Derive each date from the series anchor so month-end clamping never drifts.
    while index < 200_000 {
      guard
        let start = calendar.date(
          byAdding: component, value: index * event.repeatRule.interval, to: event.start),
        start < range.end
      else { break }
      if let until = event.repeatUntil, start > until { break }
      let anchorDay = calendar.component(.day, from: event.start)
      let validDay =
        event.repeatRule != .monthly && event.repeatRule != .yearly
        || calendar.component(.day, from: start) == anchorDay
      let end: Date
      if event.allDay {
        let days = max(
          1, calendar.dateComponents([.day], from: event.start, to: event.end).day ?? 1)
        end =
          calendar.date(byAdding: .day, value: days, to: start)
          ?? start.addingTimeInterval(duration)
      } else {
        end = start.addingTimeInterval(duration)
      }
      if validDay, overlaps(start: start, end: end, range: range),
        !event.excludedDates.contains(where: { abs($0.timeIntervalSince(start)) < 1 })
      {
        result.append(EventOccurrence(event: event, start: start, end: end))
      }
      index += 1
    }
    return result
  }

  static func normalized(_ event: CalendarEvent, calendar: Calendar) -> CalendarEvent {
    var value = event
    value.title = value.title.trimmingCharacters(in: .whitespacesAndNewlines)
    if value.allDay {
      var zoneCalendar = calendar
      zoneCalendar.timeZone = TimeZone(identifier: value.timeZoneID) ?? calendar.timeZone
      value.start = zoneCalendar.startOfDay(for: value.start)
      value.end = zoneCalendar.startOfDay(for: value.end)
      if value.end <= value.start {
        value.end = zoneCalendar.date(byAdding: .day, value: 1, to: value.start)!
      }
    } else if value.end <= value.start {
      value.end = value.start.addingTimeInterval(3600)
    }
    return value
  }
}

enum CalendarFormat {
  static func date(
    _ date: Date, template: String, language: AppLanguage = .current, timeZone: TimeZone = .current
  ) -> String {
    let formatter = DateFormatter()
    formatter.locale = language.locale
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = timeZone
    formatter.setLocalizedDateFormatFromTemplate(template)
    return formatter.string(from: date)
  }
  static func time(_ date: Date, language: AppLanguage = .current, timeZone: TimeZone = .current)
    -> String
  {
    self.date(
      date, template: language == .chinese ? "HHmm" : "hm", language: language, timeZone: timeZone)
  }
  static func alert(_ minutes: Int) -> String {
    switch minutes {
    case 0: return L10n.text("At time of event")
    case 1440: return L10n.text("1 day before")
    case 2880: return L10n.text("2 days before")
    case 10080: return L10n.text("1 week before")
    default: return L10n.format("%d minutes before", minutes)
    }
  }
  static func dayID(_ date: Date, calendar: Calendar) -> String {
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
  }
}
