import Foundation
import Observation

@MainActor @Observable
final class ClockStore {
  var cities: [ClockCity]
  var alarms: [ClockAlarm]
  var stopwatch: StopwatchState
  var countdown: CountdownState
  var tab: ClockTab = .world
  var ringing: ClockAlarm?
  var timerFinished = false
  var notificationDenied = false
  var error: String?
  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private let notifications: ClockNotifications
  @ObservationIgnored private var scheduleTask: Task<Void, Never>?
  @ObservationIgnored private var lastTick = Date()
  @ObservationIgnored private var snoozeDeadline: Date?
  @ObservationIgnored private var snoozedAlarm: ClockAlarm?
  @ObservationIgnored private var delivered: Set<String> = []
  @ObservationIgnored private var lastPresentation: [UUID: Date] = [:]
  @ObservationIgnored let testing: Bool

  struct Saved: Codable {
    var cities: [ClockCity]
    var alarms: [ClockAlarm]
    var stopwatch: StopwatchState
    var countdown: CountdownState
    var snoozeDeadline: Date?
    var snoozedAlarm: ClockAlarm?
  }
  init(defaults: UserDefaults = .standard, testing: Bool = false, realReminders: Bool = false) {
    self.defaults = defaults
    self.testing = testing
    notifications = ClockNotifications(testing: testing && !realReminders)
    let saved = defaults.data(forKey: "clock-state").flatMap {
      try? JSONDecoder().decode(Saved.self, from: $0)
    }
    cities = saved?.cities ?? ClockCity.defaults
    alarms = saved?.alarms ?? []
    stopwatch = saved?.stopwatch ?? StopwatchState()
    countdown = saved?.countdown ?? CountdownState()
    snoozeDeadline = saved?.snoozeDeadline
    snoozedAlarm = saved?.snoozedAlarm
    notifications.onAlarm = { [weak self] id in self?.receiveAlarm(id) }
    notifications.onTimer = { [weak self] in self?.completeTimer() }
    notifications.onSnooze = { [weak self] id in
      guard let self, let alarm = self.alarms.first(where: { $0.id.uuidString == id }) else {
        return
      }
      self.snooze(alarm)
    }
  }
  func save() {
    do {
      defaults.set(
        try JSONEncoder().encode(
          Saved(
            cities: cities, alarms: alarms, stopwatch: stopwatch, countdown: countdown,
            snoozeDeadline: snoozeDeadline, snoozedAlarm: snoozedAlarm)), forKey: "clock-state")
    } catch { self.error = L10n.text("Couldn't save clock data. Please try again.") }
  }
  func addCity(_ city: ClockCity) {
    if !cities.contains(where: { $0.id == city.id }) {
      cities.append(city)
      save()
    }
  }
  func removeCity(_ id: String) {
    cities.removeAll { $0.id == id }
    save()
  }
  func moveCity(_ id: String, by offset: Int) {
    guard let index = cities.firstIndex(where: { $0.id == id }),
      cities.indices.contains(index + offset)
    else { return }
    cities.swapAt(index, index + offset)
    save()
  }
  func upsert(_ alarm: ClockAlarm) {
    var alarm = alarm
    alarm.scheduledFire = alarm.enabled ? alarm.nextFire(after: Date()) : nil
    var candidate = alarms
    if let index = candidate.firstIndex(where: { $0.id == alarm.id }) {
      candidate[index] = alarm
    } else {
      candidate.append(alarm)
    }
    guard hasReminderCapacity(candidate) else { return }
    alarms = candidate
    alarms.sort { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
    save()
    reschedule(requestPermission: alarm.enabled)
  }
  func removeAlarm(_ id: UUID) {
    alarms.removeAll { $0.id == id }
    notifications.cancelAlarm(id)
    if snoozedAlarm?.id == id {
      snoozeDeadline = nil
      snoozedAlarm = nil
    }
    save()
    reschedule()
  }
  func toggleAlarm(_ id: UUID) {
    guard let i = alarms.firstIndex(where: { $0.id == id }) else { return }
    var candidate = alarms
    candidate[i].enabled.toggle()
    guard hasReminderCapacity(candidate) else { return }
    alarms[i].enabled.toggle()
    alarms[i].scheduledFire = alarms[i].enabled ? alarms[i].nextFire(after: Date()) : nil
    if !alarms[i].enabled {
      notifications.cancelAlarm(id)
      if snoozedAlarm?.id == id {
        snoozeDeadline = nil
        snoozedAlarm = nil
      }
    }
    save()
    reschedule(requestPermission: alarms[i].enabled)
  }
  private func hasReminderCapacity(_ alarms: [ClockAlarm]) -> Bool {
    let count = alarms.filter(\.enabled).reduce(0) { $0 + max(1, $1.weekdays.count) }
    guard count <= 60 else {
      error = L10n.text("Too many repeating alarms. Reduce the number of repeat days or alarms.")
      return false
    }
    return true
  }
  func reschedule(requestPermission: Bool = false) {
    scheduleTask?.cancel()
    scheduleTask = Task {
      do {
        notificationDenied = try await notifications.prepare(requestPermission: requestPermission)
        guard !Task.isCancelled else { return }
        try await notifications.schedule(alarms: alarms, timer: countdown)
      } catch is CancellationError {} catch ClockNotifications.SchedulingError.capacity {
        self.error = L10n.text(
          "Too many repeating alarms. Reduce the number of repeat days or alarms.")
      } catch { self.error = L10n.text("Couldn't schedule the reminder. Please try again.") }
    }
  }
  func toggleStopwatch(now: Date = Date()) {
    if stopwatch.running { stopwatch.stop(at: now) } else { stopwatch.start(at: now) }
    save()
  }
  func lapOrReset(now: Date = Date()) {
    if stopwatch.running { stopwatch.lap(at: now) } else { stopwatch.reset() }
    save()
  }
  func toggleTimer(now: Date = Date()) {
    timerFinished = false
    if countdown.running { countdown.pause(at: now) } else { countdown.start(at: now) }
    save()
    reschedule(requestPermission: countdown.running)
  }
  func cancelTimer() {
    countdown.cancel()
    timerFinished = false
    notifications.cancelTimer()
    save()
    reschedule()
  }
  func tick(now: Date = Date()) {
    if countdown.running && countdown.seconds(at: now) <= 0 { completeTimer() }
    if let deadline = snoozeDeadline, now >= deadline {
      if now.timeIntervalSince(deadline) < 60, let alarm = snoozedAlarm {
        receiveAlarm(alarm.id.uuidString, now: now)
      }
      snoozeDeadline = nil
      snoozedAlarm = nil
      save()
    }
    for alarm in alarms where alarm.enabled {
      guard
        let next = alarm.weekdays.isEmpty ? alarm.scheduledFire : alarm.nextFire(after: lastTick),
        next <= now
      else { continue }
      if now.timeIntervalSince(next) >= 60 {
        if alarm.weekdays.isEmpty, let i = alarms.firstIndex(where: { $0.id == alarm.id }) {
          alarms[i].enabled = false
          save()
        }
        continue
      }
      let key = alarm.id.uuidString + String(Int(next.timeIntervalSince1970))
      if delivered.insert(key).inserted { receiveAlarm(alarm.id.uuidString, now: now) }
    }
    lastTick = now
  }
  func receiveAlarm(_ id: String, now: Date = Date()) {
    guard let alarm = alarms.first(where: { $0.id.uuidString == id }) else { return }
    if let last = lastPresentation[alarm.id],
      now.timeIntervalSince(last) >= 0 && now.timeIntervalSince(last) < 60
    {
      return
    }
    lastPresentation[alarm.id] = now
    ringing = alarm
    if snoozedAlarm?.id == alarm.id {
      snoozeDeadline = nil
      snoozedAlarm = nil
    }
    if alarm.weekdays.isEmpty, let i = alarms.firstIndex(where: { $0.id == alarm.id }) {
      alarms[i].enabled = false
      save()
    }
  }
  func completeTimer() {
    guard !timerFinished else { return }
    timerFinished = true
    countdown.remaining = 0
    countdown.deadline = nil
    notifications.cancelTimer()
    save()
  }
  func dismissRing() {
    ringing = nil
    ClockAudio.shared.stop()
  }
  func snooze(_ alarm: ClockAlarm, now: Date = Date()) {
    snoozedAlarm = alarm
    snoozeDeadline = now.addingTimeInterval(9 * 60)
    notifications.snooze(alarm, after: 9 * 60)
    save()
    dismissRing()
  }
}
