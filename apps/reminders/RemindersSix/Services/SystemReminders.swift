import CoreLocation
import EventKit
import Foundation

@MainActor
final class SystemReminders {
  private let store = EKEventStore()
  var authorized: Bool { EKEventStore.authorizationStatus(for: .reminder) == .fullAccess }
  func requestAccess() async throws -> Bool { try await store.requestFullAccessToReminders() }

  func load(existingLists: [ReminderList], existingItems: [ReminderItem]) async -> (
    lists: [ReminderList], items: [ReminderItem]
  ) {
    guard authorized else { return ([], []) }
    store.refreshSourcesIfNecessary()
    let calendars = store.calendars(for: .reminder)
    let lists = calendars.map { calendar in
      ReminderList(
        id: existingLists.first { $0.systemID == calendar.calendarIdentifier }?.id ?? UUID(),
        name: calendar.title, systemID: calendar.calendarIdentifier, account: calendar.source.title,
        writable: calendar.allowsContentModifications)
    }
    let predicate = store.predicateForReminders(in: calendars)
    let reminders: [EKReminder] = await withCheckedContinuation { continuation in
      store.fetchReminders(matching: predicate) { continuation.resume(returning: $0 ?? []) }
    }
    let items = reminders.compactMap { reminder -> ReminderItem? in
      guard let list = lists.first(where: { $0.systemID == reminder.calendar.calendarIdentifier })
      else { return nil }
      var item = ReminderItem(
        id: existingItems.first { $0.systemID == reminder.calendarItemIdentifier }?.id ?? UUID(),
        listID: list.id, title: reminder.title ?? "")
      item.notes = reminder.notes ?? ""
      if let components = reminder.dueDateComponents {
        item.due = (components.calendar ?? .current).date(from: components)
      }
      switch reminder.priority {
      case 1...4: item.priority = .high
      case 5: item.priority = .medium
      case 6...9: item.priority = .low
      default: item.priority = .none
      }
      item.completedAt = reminder.isCompleted ? reminder.completionDate ?? Date() : nil
      item.systemID = reminder.calendarItemIdentifier
      if let rule = reminder.recurrenceRules?.first {
        switch rule.frequency {
        case .daily: item.recurrence = .daily
        case .weekly: item.recurrence = rule.interval == 2 ? .fortnightly : .weekly
        case .monthly: item.recurrence = .monthly
        case .yearly: item.recurrence = .yearly
        @unknown default: break
        }
        item.complexRecurrence =
          (reminder.recurrenceRules?.count ?? 0) > 1
          || (rule.interval != 1 && !(rule.interval == 2 && rule.frequency == .weekly))
          || !(rule.daysOfTheWeek ?? []).isEmpty || !(rule.daysOfTheMonth ?? []).isEmpty
          || !(rule.monthsOfTheYear ?? []).isEmpty || !(rule.weeksOfTheYear ?? []).isEmpty
          || !(rule.daysOfTheYear ?? []).isEmpty || !(rule.setPositions ?? []).isEmpty
          || rule.recurrenceEnd != nil
      }
      if let alarm = reminder.alarms?.first(where: { $0.structuredLocation != nil }),
        let location = alarm.structuredLocation, let coordinate = location.geoLocation?.coordinate
      {
        item.place = ReminderPlace(
          name: location.title ?? L10n.text("Location"), latitude: coordinate.latitude,
          longitude: coordinate.longitude, onArrival: alarm.proximity != .leave,
          radius: location.radius)
      }
      return item
    }
    // Retain the user's local order while incorporating externally added reminders.
    let order = Dictionary(
      uniqueKeysWithValues: existingItems.enumerated().map { ($0.element.id, $0.offset) })
    let listOrder = Dictionary(
      uniqueKeysWithValues: existingLists.enumerated().map { ($0.element.id, $0.offset) })
    return (
      lists.sorted { (listOrder[$0.id] ?? Int.max) < (listOrder[$1.id] ?? Int.max) },
      items.sorted { (order[$0.id] ?? Int.max) < (order[$1.id] ?? Int.max) }
    )
  }

  func save(_ item: ReminderItem, list: ReminderList, original: ReminderItem?) throws -> String {
    guard authorized else { throw ReminderFailure.permission }
    guard let id = list.systemID, let calendar = store.calendar(withIdentifier: id),
      calendar.allowsContentModifications
    else { throw ReminderFailure.readOnly }
    let reminder: EKReminder
    if let id = item.systemID {
      guard let value = store.calendarItem(withIdentifier: id) as? EKReminder else {
        throw ReminderFailure.missing
      }
      reminder = value
    } else {
      reminder = EKReminder(eventStore: store)
    }
    reminder.calendar = calendar
    reminder.title = item.title
    reminder.notes = item.notes
    if original == nil || original?.priority != item.priority {
      reminder.priority = item.priority.rawValue
    }
    reminder.isCompleted = item.completed
    reminder.completionDate = item.completedAt
    if original?.due != item.due || original == nil {
      reminder.dueDateComponents = item.due.map {
        Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: $0)
      }
      reminder.startDateComponents = reminder.dueDateComponents
    }
    if original?.recurrence != item.recurrence || original == nil {
      let frequency: EKRecurrenceFrequency
      switch item.recurrence {
      case .never, .daily: frequency = .daily
      case .weekly, .fortnightly: frequency = .weekly
      case .monthly: frequency = .monthly
      case .yearly: frequency = .yearly
      }
      reminder.recurrenceRules =
        item.recurrence == .never
        ? nil
        : [
          EKRecurrenceRule(
            recurrenceWith: frequency, interval: item.recurrence == .fortnightly ? 2 : 1, end: nil)
        ]
    }
    if original == nil || original?.due != item.due || original?.place != item.place {
      var alarms: [EKAlarm] = item.due.map { [EKAlarm(absoluteDate: $0)] } ?? []
      if let place = item.place {
        let location = EKStructuredLocation(title: place.name)
        location.geoLocation = CLLocation(latitude: place.latitude, longitude: place.longitude)
        location.radius = place.radius
        let alarm = EKAlarm()
        alarm.structuredLocation = location
        alarm.proximity = place.onArrival ? .enter : .leave
        alarms.append(alarm)
      }
      reminder.alarms = alarms
    }
    try store.save(reminder, commit: true)
    return reminder.calendarItemIdentifier
  }

  func delete(_ item: ReminderItem) throws {
    guard authorized else { throw ReminderFailure.permission }
    guard let id = item.systemID,
      let reminder = store.calendarItem(withIdentifier: id) as? EKReminder
    else { throw ReminderFailure.missing }
    guard reminder.calendar.allowsContentModifications else { throw ReminderFailure.readOnly }
    try store.remove(reminder, commit: true)
  }

  func saveList(_ list: ReminderList) throws -> String {
    guard authorized else { throw ReminderFailure.permission }
    let calendar: EKCalendar
    if let id = list.systemID {
      guard let found = store.calendar(withIdentifier: id), found.allowsContentModifications else {
        throw ReminderFailure.readOnly
      }
      calendar = found
    } else {
      calendar = EKCalendar(for: .reminder, eventStore: store)
      guard
        let source = store.defaultCalendarForNewReminders()?.source
          ?? store.sources.first(where: { $0.sourceType == .local })
      else { throw ReminderFailure.missing }
      calendar.source = source
    }
    calendar.title = list.name
    try store.saveCalendar(calendar, commit: true)
    return calendar.calendarIdentifier
  }

  func deleteList(_ list: ReminderList) throws {
    guard authorized else { throw ReminderFailure.permission }
    guard let id = list.systemID, let calendar = store.calendar(withIdentifier: id),
      calendar.allowsContentModifications
    else { throw ReminderFailure.readOnly }
    try store.removeCalendar(calendar, commit: true)
  }
}
