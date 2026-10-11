import Foundation
import UserNotifications

final class ClockNotifications: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
  private let center = UNUserNotificationCenter.current()
  private let testing: Bool
  @MainActor var onAlarm: ((String) -> Void)?
  @MainActor var onTimer: (() -> Void)?
  @MainActor var onSnooze: ((String) -> Void)?

  init(testing: Bool) {
    self.testing = testing
    super.init()
    if !testing { center.delegate = self }
  }
  func prepare(requestPermission: Bool) async throws -> Bool {
    if testing { return false }
    let snooze = UNNotificationAction(identifier: "snooze", title: L10n.text("Snooze"), options: [])
    let stop = UNNotificationAction(identifier: "stop", title: L10n.text("Stop"), options: [])
    center.setNotificationCategories([
      UNNotificationCategory(
        identifier: "alarm-snooze", actions: [snooze, stop], intentIdentifiers: []),
      UNNotificationCategory(identifier: "alarm", actions: [stop], intentIdentifiers: []),
      UNNotificationCategory(identifier: "timer", actions: [stop], intentIdentifiers: []),
    ])
    var settings = await center.notificationSettings()
    if settings.authorizationStatus == .notDetermined && requestPermission {
      _ = try await center.requestAuthorization(options: [.alert, .sound])
      settings = await center.notificationSettings()
    }
    return settings.authorizationStatus == .denied
  }
  static func requests(for alarm: ClockAlarm) -> [UNNotificationRequest] {
    guard alarm.enabled,
      !(alarm.weekdays.isEmpty && alarm.scheduledFire.map { $0 <= Date() } == true)
    else { return [] }
    let days: [Int?] = alarm.weekdays.isEmpty ? [nil] : alarm.weekdays.sorted().map { Optional($0) }
    return days.map { day in
      var components = DateComponents()
      components.hour = alarm.hour
      components.minute = alarm.minute
      components.second = 0
      components.weekday = day
      if day == nil, let scheduled = alarm.scheduledFire {
        components = Calendar.current.dateComponents(
          [.year, .month, .day, .hour, .minute, .second], from: scheduled)
      }
      let content = content(title: L10n.text("Alarm"), body: alarm.displayLabel, sound: alarm.sound)
      content.categoryIdentifier = alarm.snooze ? "alarm-snooze" : "alarm"
      content.userInfo = ["alarmID": alarm.id.uuidString]
      return UNNotificationRequest(
        identifier: "alarm-\(alarm.id)-\(day ?? 0)", content: content,
        trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: day != nil))
    }
  }
  static func content(title: String, body: String, sound: ClockSound)
    -> UNMutableNotificationContent
  {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    if let file = sound.filename {
      content.sound = UNNotificationSound(named: UNNotificationSoundName(file))
    }
    return content
  }
  func schedule(alarms: [ClockAlarm], timer: CountdownState) async throws {
    if testing { return }
    try Task.checkCancellation()
    let requests = alarms.flatMap(Self.requests)
    guard requests.count <= 60 else { throw SchedulingError.capacity }
    let pending = await center.pendingNotificationRequests()
    try Task.checkCancellation()
    center.removePendingNotificationRequests(
      withIdentifiers: pending.filter {
        $0.identifier.hasPrefix("alarm-") || $0.identifier == "timer"
      }.map(\.identifier))
    for request in requests {
      try Task.checkCancellation()
      try await center.add(request)
    }
    if let deadline = timer.deadline, deadline > Date() {
      let content = Self.content(
        title: L10n.text("Timer"), body: L10n.text("Timer finished"), sound: timer.sound)
      content.categoryIdentifier = "timer"
      try Task.checkCancellation()
      try await center.add(
        UNNotificationRequest(
          identifier: "timer", content: content,
          trigger: UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, deadline.timeIntervalSinceNow), repeats: false)))
    }
  }
  func cancelAlarm(_ id: UUID) {
    guard !testing else { return }
    center.removePendingNotificationRequests(
      withIdentifiers: (0...7).map { "alarm-\(id)-\($0)" } + ["snooze-\(id)"])
  }
  func cancelTimer() {
    if !testing { center.removePendingNotificationRequests(withIdentifiers: ["timer"]) }
  }
  func snooze(_ alarm: ClockAlarm, after seconds: TimeInterval) {
    guard !testing else { return }
    let content = Self.content(
      title: L10n.text("Alarm"), body: alarm.displayLabel, sound: alarm.sound)
    content.categoryIdentifier = "alarm-snooze"
    content.userInfo = ["alarmID": alarm.id.uuidString]
    center.add(
      UNNotificationRequest(
        identifier: "snooze-\(alarm.id)", content: content,
        trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)))
  }
  func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let id = notification.request.content.userInfo["alarmID"] as? String
    Task { @MainActor in if let id { onAlarm?(id) } else { onTimer?() } }
    completionHandler([])
  }
  func userNotificationCenter(
    _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let id = response.notification.request.content.userInfo["alarmID"] as? String
    Task { @MainActor in
      if response.actionIdentifier == "snooze", let id {
        onSnooze?(id)
      } else if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
        if let id { onAlarm?(id) } else { onTimer?() }
      }
      completionHandler()
    }
  }
  enum SchedulingError: Error { case capacity }
}
