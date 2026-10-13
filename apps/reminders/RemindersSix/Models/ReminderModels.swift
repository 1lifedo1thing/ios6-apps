import Foundation

enum RepeatRule: String, Codable, CaseIterable, Identifiable {
  case never = "Never"
  case daily = "Every Day"
  case weekly = "Every Week"
  case fortnightly = "Every Two Weeks"
  case monthly = "Every Month"
  case yearly = "Every Year"
  var id: String { rawValue }

  func next(after date: Date, anchor: Date, calendar: Calendar = .current) -> Date? {
    switch self {
    case .never: return nil
    case .daily: return calendar.date(byAdding: .day, value: 1, to: date)
    case .weekly: return calendar.date(byAdding: .day, value: 7, to: date)
    case .fortnightly: return calendar.date(byAdding: .day, value: 14, to: date)
    case .monthly, .yearly:
      let component: Calendar.Component = self == .monthly ? .month : .year
      guard let shifted = calendar.date(byAdding: component, value: 1, to: date),
        let range = calendar.range(of: .day, in: .month, for: shifted)
      else { return nil }
      var parts = calendar.dateComponents([.year, .month, .hour, .minute], from: shifted)
      if self == .yearly { parts.month = calendar.component(.month, from: anchor) }
      let monthDate = calendar.date(from: parts) ?? shifted
      let days = calendar.range(of: .day, in: .month, for: monthDate) ?? range
      parts.day = min(calendar.component(.day, from: anchor), days.count)
      return calendar.date(from: parts)
    }
  }
}

enum ReminderPriority: Int, Codable, CaseIterable, Identifiable {
  case none = 0
  case low = 9
  case medium = 5
  case high = 1
  var id: Int { rawValue }
  var title: String {
    switch self {
    case .none: "None"
    case .low: "Low"
    case .medium: "Medium"
    case .high: "High"
    }
  }
  var mark: String {
    switch self {
    case .none: ""
    case .low: "!"
    case .medium: "!!"
    case .high: "!!!"
    }
  }
}

struct ReminderPlace: Codable, Equatable {
  var name: String
  var latitude: Double
  var longitude: Double
  var onArrival = true
  var radius: Double = 200
}

struct ReminderList: Identifiable, Codable, Equatable {
  var id = UUID()
  var name: String
  var builtIn = false
  var systemID: String?
  var account: String?
  var writable = true
  func displayName(language: AppLanguage = .current) -> String {
    builtIn ? L10n.text("Reminders", language: language) : name
  }
}

struct ReminderItem: Identifiable, Codable, Equatable {
  var id = UUID()
  var listID: UUID
  var title: String
  var notes = ""
  var due: Date?
  var recurrence: RepeatRule = .never
  var recurrenceAnchor: Date?
  var priority: ReminderPriority = .none
  var place: ReminderPlace?
  var completedAt: Date?
  var systemID: String?
  var predecessorID: UUID?
  var complexRecurrence = false
  var completed: Bool { completedAt != nil }

  func subtitle(language: AppLanguage = .current) -> String {
    var parts: [String] = []
    if let due {
      parts.append(
        due.formatted(.dateTime.year().month().day().hour().minute().locale(language.locale)))
    }
    if recurrence != .never { parts.append(L10n.text(recurrence.rawValue, language: language)) }
    if let place {
      parts.append(
        L10n.format(
          place.onArrival ? "Arriving at %@" : "Leaving %@", place.name, language: language))
    }
    return parts.joined(separator: " · ")
  }
}

struct ReminderArchive: Codable {
  var version = 1
  var lists: [ReminderList]
  var items: [ReminderItem]
  var selectedList: UUID
  var connected = false
}

enum ReminderPage: Equatable {
  case list(UUID)
  case completed
  case date(Date)
}

enum ReminderFailure: LocalizedError {
  case save, permission, readOnly, missing, lastList, capacity, location, unsupportedRepeat
  var errorDescription: String? {
    let key: String
    switch self {
    case .save: key = "Couldn't save reminders. Please try again."
    case .permission: key = "Access is unavailable. Enable it in Settings and try again."
    case .readOnly: key = "This list is read-only."
    case .missing: key = "This reminder or list is no longer available."
    case .lastList: key = "Keep at least one local list."
    case .capacity:
      key =
        "Some alerts could not be scheduled. Keep fewer than 60 date alerts and 20 location alerts."
    case .location: key = "Couldn't find this location. Try a more specific address."
    case .unsupportedRepeat:
      key =
        "This system reminder has an advanced repeat rule. Edit its date and repeat in Apple's Reminders."
    }
    return L10n.text(key)
  }
}
