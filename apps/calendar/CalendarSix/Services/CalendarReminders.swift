import Foundation
import UserNotifications

@MainActor
final class CalendarReminders {
  private let center = UNUserNotificationCenter.current()
  func requestAccess() async throws {
    guard try await center.requestAuthorization(options: [.alert, .sound, .badge]) else {
      throw ReminderFailure.denied
    }
  }
  func status() async -> String {
    switch await center.notificationSettings().authorizationStatus {
    case .authorized, .provisional, .ephemeral: return "Enabled"
    case .denied: return "Disabled in Settings"
    case .notDetermined: return "Not Enabled"
    @unknown default: return "Not Enabled"
    }
  }
  static func upcoming(events: [CalendarEvent], now: Date, calendar: Calendar) -> [(
    String, Date, String, String
  )] {
    let end = calendar.date(byAdding: .year, value: 1, to: now)!
    let range = DateInterval(start: now.addingTimeInterval(-86400), end: end)
    return events.flatMap { event in
      CalendarMath.occurrences(of: event, in: range, calendar: calendar).flatMap { occurrence in
        event.alertMinutes.compactMap { minutes -> (String, Date, String, String)? in
          let fire = occurrence.start.addingTimeInterval(TimeInterval(-minutes * 60))
          guard fire > now else { return nil }
          return (
            "calendar:" + occurrence.id + ":" + String(minutes), fire, event.title, event.location
          )
        }
      }
    }.sorted { $0.1 < $1.1 }.prefix(60).map { $0 }
  }
  func schedule(events: [CalendarEvent], calendar: Calendar) async throws {
    guard await status() == "Enabled", !Task.isCancelled else { return }
    let pending = await center.pendingNotificationRequests()
    guard !Task.isCancelled else { return }
    center.removePendingNotificationRequests(
      withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix("calendar:") })
    for item in Self.upcoming(events: events, now: .now, calendar: calendar) {
      try Task.checkCancellation()
      let content = UNMutableNotificationContent()
      content.title = item.2
      content.body = item.3
      content.sound = .default
      var components = calendar.dateComponents(
        [.year, .month, .day, .hour, .minute, .second], from: item.1)
      components.timeZone = calendar.timeZone
      let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
      try await center.add(
        UNNotificationRequest(identifier: item.0, content: content, trigger: trigger))
    }
  }
}

enum ReminderFailure: LocalizedError {
  case denied
  var errorDescription: String? {
    L10n.text("Enable notifications in Settings to receive event reminders.")
  }
}
