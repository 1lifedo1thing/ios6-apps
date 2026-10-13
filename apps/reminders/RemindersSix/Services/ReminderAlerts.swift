import CoreLocation
import Foundation
import UserNotifications

final class ReminderAlerts: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
  private let center = UNUserNotificationCenter.current()
  private let disabled: Bool

  init(disabled: Bool) {
    self.disabled = disabled
    super.init()
    if !disabled { center.delegate = self }
  }

  func requestPermission() async throws -> Bool {
    guard !disabled else { return true }
    let settings = await center.notificationSettings()
    if settings.authorizationStatus == .notDetermined {
      return try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }
    return settings.authorizationStatus == .authorized
      || settings.authorizationStatus == .provisional
  }

  func permissionDenied() async -> Bool {
    guard !disabled else { return false }
    return await center.notificationSettings().authorizationStatus == .denied
  }

  static func requests(for item: ReminderItem, language: AppLanguage = .current, now: Date = Date())
    -> [UNNotificationRequest]
  {
    guard !item.completed, item.systemID == nil else { return [] }
    let content = UNMutableNotificationContent()
    content.title = item.title
    content.body = item.notes.isEmpty ? L10n.text("Reminders", language: language) : item.notes
    content.sound = .default
    content.userInfo = ["reminderID": item.id.uuidString]
    var requests: [UNNotificationRequest] = []
    if let due = item.due, due > now {
      var parts = Calendar.current.dateComponents(
        [.year, .month, .day, .hour, .minute, .second], from: due)
      parts.calendar = Calendar.current
      requests.append(
        UNNotificationRequest(
          identifier: "reminder-date-\(item.id)", content: content,
          trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)))
    }
    if let place = item.place {
      let region = CLCircularRegion(
        center: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude),
        radius: place.radius, identifier: item.id.uuidString)
      region.notifyOnEntry = place.onArrival
      region.notifyOnExit = !place.onArrival
      requests.append(
        UNNotificationRequest(
          identifier: "reminder-place-\(item.id)", content: content,
          trigger: UNLocationNotificationTrigger(region: region, repeats: false)))
    }
    return requests
  }

  func reconcile(_ items: [ReminderItem]) async throws {
    guard !disabled else { return }
    try Task.checkCancellation()
    let requests = items.sorted { ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) }.flatMap
    { Self.requests(for: $0) }
    let locations = requests.filter { $0.trigger is UNLocationNotificationTrigger }
    let dates = requests.filter { $0.trigger is UNCalendarNotificationTrigger }
    let selected = Array(dates.prefix(60)) + Array(locations.prefix(20))
    let settings = await center.notificationSettings()
    try Task.checkCancellation()
    let pending = await center.pendingNotificationRequests()
    try Task.checkCancellation()
    center.removePendingNotificationRequests(
      withIdentifiers: pending.filter { $0.identifier.hasPrefix("reminder-") }.map(\.identifier))
    let delivered = await center.deliveredNotifications()
    let active = Set(items.filter { !$0.completed }.map { $0.id.uuidString })
    try Task.checkCancellation()
    center.removeDeliveredNotifications(
      withIdentifiers: delivered.filter {
        $0.request.identifier.hasPrefix("reminder-")
          && !active.contains($0.request.content.userInfo["reminderID"] as? String ?? "")
      }.map { $0.request.identifier })
    if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
      // iOS permits at most 64 pending local notifications per app.
      for request in selected.prefix(64) {
        try Task.checkCancellation()
        try await center.add(request)
      }
      if dates.count > 60 || locations.count > 20 || selected.count > 64 {
        throw ReminderFailure.capacity
      }
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound])
  }
}
