import UserNotifications
import XCTest

@testable import ClockSix

final class ClockSixTests: XCTestCase {
  private let start = Date(timeIntervalSince1970: 1_800_000_000)

  func testWeatherLanguageRules() {
    XCTAssertEqual(AppLanguage.preferred(["zh-Hant-TW", "en"]), .chinese)
    XCTAssertEqual(AppLanguage.preferred(["zh-HK"]), .chinese)
    XCTAssertEqual(AppLanguage.preferred(["en-GB"]), .english)
    XCTAssertEqual(AppLanguage.preferred(["fr", "zh-Hans"]), .english)
    XCTAssertEqual(AppLanguage.preferred([]), .english)
    XCTAssertEqual(L10n.text("World Clock", language: .chinese), "世界时钟")
    XCTAssertEqual(L10n.text("Snooze", language: .english), "Snooze")
  }
  func testCityIdentityTimeZonesAndBilingualSearch() {
    XCTAssertEqual(Set(ClockCity.catalog.map(\.id)).count, ClockCity.catalog.count)
    for city in ClockCity.catalog { XCTAssertNotNil(TimeZone(identifier: city.zone), city.name) }
    let beijing = ClockCity.catalog.first { $0.name == "Beijing" }!
    XCTAssertTrue(beijing.matches("北京"))
    XCTAssertTrue(beijing.matches("beijing"))
    XCTAssertTrue(beijing.matches("China"))
    XCTAssertFalse(beijing.matches("Tokyo"))
    XCTAssertEqual(beijing.displayName(.chinese), "北京")
    let la = ClockCity.catalog.first { $0.name == "Los Angeles" }!
    let sf = ClockCity.catalog.first { $0.name == "San Francisco" }!
    XCTAssertNotEqual(la.id, sf.id)
    XCTAssertEqual(la.timeZone, sf.timeZone)
  }
  func testWorldDateCrossesInternationalDateLine() {
    let date = ISO8601DateFormatter().date(from: "2026-10-11T23:30:00Z")!
    XCTAssertEqual(
      ClockFormat.day(date, zone: TimeZone(identifier: "Asia/Tokyo")!, localZone: .gmt),
      L10n.text("Tomorrow"))
    let morning = ISO8601DateFormatter().date(from: "2026-10-11T01:30:00Z")!
    XCTAssertEqual(
      ClockFormat.day(morning, zone: TimeZone(identifier: "America/Los_Angeles")!, localZone: .gmt),
      L10n.text("Yesterday"))
  }
  func testStopwatchPauseResumeLapsAndRestartEncoding() throws {
    var watch = StopwatchState()
    watch.start(at: start)
    watch.lap(at: start.addingTimeInterval(2))
    watch.lap(at: start.addingTimeInterval(5))
    watch.stop(at: start.addingTimeInterval(6))
    XCTAssertEqual(watch.laps, [2, 3])
    XCTAssertEqual(watch.elapsed(at: start.addingTimeInterval(100)), 6)
    watch.start(at: start.addingTimeInterval(100))
    let restored = try JSONDecoder().decode(StopwatchState.self, from: JSONEncoder().encode(watch))
    XCTAssertEqual(restored.elapsed(at: start.addingTimeInterval(110)), 16)
    watch.reset()
    XCTAssertFalse(watch.running)
    XCTAssertTrue(watch.laps.isEmpty)
  }
  func testStopwatchDoesNotStartTwiceOrLapWhenPaused() {
    var watch = StopwatchState()
    watch.lap(at: start)
    XCTAssertTrue(watch.laps.isEmpty)
    watch.start(at: start)
    watch.start(at: start.addingTimeInterval(10))
    XCTAssertEqual(watch.elapsed(at: start.addingTimeInterval(12)), 12)
  }
  func testTimerPauseResumeCancelAndBackgroundExpiry() throws {
    var timer = CountdownState()
    timer.configure(hours: 1, minutes: 2)
    XCTAssertEqual(timer.duration, 3720)
    timer.start(at: start)
    timer.pause(at: start.addingTimeInterval(20))
    XCTAssertEqual(timer.remaining, 3700)
    timer.configure(hours: 0, minutes: 1)
    XCTAssertEqual(timer.duration, 3720)
    timer.start(at: start.addingTimeInterval(100))
    let restored = try JSONDecoder().decode(CountdownState.self, from: JSONEncoder().encode(timer))
    XCTAssertEqual(restored.seconds(at: start.addingTimeInterval(200)), 3600)
    XCTAssertEqual(restored.seconds(at: start.addingTimeInterval(5000)), 0)
    timer.cancel()
    XCTAssertEqual(timer.remaining, 3720)
    XCTAssertFalse(timer.active)
  }
  func testZeroTimerAndDisplayBoundaries() {
    var timer = CountdownState()
    timer.configure(hours: 0, minutes: 0)
    timer.start(at: start)
    XCTAssertFalse(timer.running)
    XCTAssertEqual(ClockFormat.countdown(0.1), "00:01")
    XCTAssertEqual(ClockFormat.countdown(-1), "00:00")
    XCTAssertEqual(ClockFormat.countdown(3661), "01:01:01")
    XCTAssertEqual(ClockFormat.stopwatch(65.39), "01:05.3")
    XCTAssertEqual(ClockFormat.stopwatch(7200), "120:00.0")
  }
  func testOneShotTomorrowAndRepeatingWeekday() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    let date = ISO8601DateFormatter().date(from: "2026-10-11T08:30:00Z")!
    var alarm = ClockAlarm()
    alarm.hour = 7
    XCTAssertEqual(
      alarm.nextFire(after: date, calendar: calendar),
      ISO8601DateFormatter().date(from: "2026-10-12T07:00:00Z"))
    alarm.weekdays = [3]
    XCTAssertEqual(
      alarm.nextFire(after: date, calendar: calendar),
      ISO8601DateFormatter().date(from: "2026-10-13T07:00:00Z"))
  }
  func testDaylightSavingNonexistentHourUsesNextValidTime() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    var alarm = ClockAlarm()
    alarm.hour = 2
    alarm.minute = 30
    let date = ISO8601DateFormatter().date(from: "2026-03-08T05:00:00Z")!
    let next = alarm.nextFire(after: date, calendar: calendar)!
    XCTAssertEqual(calendar.component(.hour, from: next), 3)
    XCTAssertEqual(calendar.component(.day, from: next), 8)
  }
  func testNotificationTriggersSoundsSnoozeAndDisabledAlarms() {
    var alarm = ClockAlarm()
    alarm.weekdays = [2, 4, 6]
    alarm.hour = 8
    alarm.minute = 45
    let requests = ClockNotifications.requests(for: alarm)
    XCTAssertEqual(requests.count, 3)
    XCTAssertEqual(
      Set(
        requests.compactMap {
          ($0.trigger as? UNCalendarNotificationTrigger)?.dateComponents.weekday
        }), [2, 4, 6])
    for request in requests {
      XCTAssertTrue(request.trigger!.repeats)
      XCTAssertEqual(request.content.categoryIdentifier, "alarm-snooze")
      XCTAssertEqual(request.content.userInfo["alarmID"] as? String, alarm.id.uuidString)
      XCTAssertNotNil(request.content.sound)
    }
    alarm.weekdays = []
    alarm.sound = .none
    alarm.snooze = false
    let oneShot = ClockNotifications.requests(for: alarm).first!
    XCTAssertFalse(oneShot.trigger!.repeats)
    XCTAssertNil(oneShot.content.sound)
    XCTAssertEqual(oneShot.content.categoryIdentifier, "alarm")
    alarm.enabled = false
    XCTAssertTrue(ClockNotifications.requests(for: alarm).isEmpty)
    alarm.enabled = true
    alarm.scheduledFire = Date().addingTimeInterval(-60)
    XCTAssertTrue(ClockNotifications.requests(for: alarm).isEmpty)
  }
  func testBundledSoundAndLocalizationResources() {
    for sound in ClockSound.alarmSounds {
      if let file = sound.filename {
        XCTAssertNotNil(Bundle.main.url(forResource: file, withExtension: nil), file)
      }
    }
    for language in AppLanguage.allCases {
      XCTAssertNotNil(Bundle.main.path(forResource: language.rawValue, ofType: "lproj"))
    }
  }

  @MainActor func testStorePersistenceCitiesAlarmAndStopwatch() throws {
    let suite = "ClockSix-test-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = ClockStore(defaults: defaults, testing: true)
    let city = ClockCity.catalog.first { $0.name == "Sydney" }!
    store.addCity(city)
    store.addCity(city)
    XCTAssertEqual(store.cities.filter { $0.id == city.id }.count, 1)
    store.moveCity(city.id, by: -1)
    var alarm = ClockAlarm()
    alarm.label = "Keep my text 保留"
    alarm.weekdays = [2, 3]
    alarm.song = AlarmSong(persistentID: 1234, title: "My song")
    store.upsert(alarm)
    store.toggleStopwatch(now: start)
    store.lapOrReset(now: start.addingTimeInterval(3))
    let restored = ClockStore(defaults: defaults, testing: true)
    XCTAssertEqual(restored.cities, store.cities)
    XCTAssertEqual(restored.alarms.first?.label, "Keep my text 保留")
    XCTAssertEqual(restored.alarms.first?.song, alarm.song)
    XCTAssertEqual(restored.stopwatch.laps, [3])
    restored.removeAlarm(alarm.id)
    restored.removeCity(city.id)
    XCTAssertTrue(restored.alarms.isEmpty)
    XCTAssertFalse(restored.cities.contains(city))
  }
  @MainActor func testExpiredOneShotDisablesAndSnoozeSurvivesRelaunch() {
    let suite = "ClockSix-test-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = ClockStore(defaults: defaults, testing: true)
    var alarm = ClockAlarm()
    alarm.scheduledFire = start
    store.alarms = [alarm]
    store.save()
    store.tick(now: start.addingTimeInterval(10))
    XCTAssertEqual(store.ringing?.id, alarm.id)
    XCTAssertFalse(store.alarms[0].enabled)
    store.snooze(alarm, now: start.addingTimeInterval(10))
    let restored = ClockStore(defaults: defaults, testing: true)
    restored.tick(now: start.addingTimeInterval(551))
    XCTAssertEqual(restored.ringing?.id, alarm.id)
    restored.dismissRing()
    XCTAssertNil(restored.ringing)
  }
  @MainActor func testTimerExpiryIsDeliveredOnceAndCancelResets() {
    let suite = "ClockSix-test-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = ClockStore(defaults: defaults, testing: true)
    store.toggleTimer(now: start)
    store.tick(now: start.addingTimeInterval(61))
    XCTAssertTrue(store.timerFinished)
    XCTAssertFalse(store.countdown.running)
    store.cancelTimer()
    store.tick(now: start.addingTimeInterval(62))
    XCTAssertFalse(store.timerFinished)
    XCTAssertEqual(store.countdown.remaining, 60)
  }
  @MainActor func testRepeatingAlarmCapacityRejectsUnschedulableChanges() {
    let suite = "ClockSix-test-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = ClockStore(defaults: defaults, testing: true)
    for _ in 0..<8 {
      var alarm = ClockAlarm()
      alarm.weekdays = Set(1...7)
      store.upsert(alarm)
    }
    XCTAssertEqual(store.alarms.count, 8)
    var extra = ClockAlarm()
    extra.weekdays = Set(1...7)
    store.upsert(extra)
    XCTAssertEqual(store.alarms.count, 8)
    XCTAssertNotNil(store.error)
    extra.enabled = false
    store.error = nil
    store.upsert(extra)
    XCTAssertEqual(store.alarms.count, 9)
    store.toggleAlarm(extra.id)
    XCTAssertFalse(store.alarms.first { $0.id == extra.id }!.enabled)
    XCTAssertNotNil(store.error)
  }
  @MainActor func testForegroundAndNotificationDeliveryDoNotRingTwice() {
    let suite = "ClockSix-test-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = ClockStore(defaults: defaults, testing: true)
    var alarm = ClockAlarm()
    alarm.weekdays = Set(1...7)
    store.upsert(alarm)
    store.receiveAlarm(alarm.id.uuidString, now: start)
    store.dismissRing()
    store.receiveAlarm(alarm.id.uuidString, now: start.addingTimeInterval(1))
    XCTAssertNil(store.ringing)
    store.receiveAlarm(alarm.id.uuidString, now: start.addingTimeInterval(61))
    XCTAssertEqual(store.ringing?.id, alarm.id)
  }
}
