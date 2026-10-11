import Foundation

enum ClockTab: String, CaseIterable, Codable {
  case world = "World Clock"
  case alarm = "Alarm"
  case stopwatch = "Stopwatch"
  case timer = "Timer"
  var identifier: String { "tab-" + String(describing: self) }
}

struct ClockCity: Identifiable, Codable, Equatable {
  var id: String { name + "|" + zone }
  let name: String
  let chinese: String
  let country: String
  let zone: String

  func displayName(_ language: AppLanguage = .current) -> String {
    language == .chinese ? chinese : name
  }
  var timeZone: TimeZone { TimeZone(identifier: zone) ?? .gmt }
  func matches(_ query: String) -> Bool {
    query.isEmpty
      || [name, chinese, country, zone].contains {
        $0.localizedStandardContains(query.trimmingCharacters(in: .whitespaces))
      }
      || chinese.applyingTransform(.toLatin, reverse: false)?
        .applyingTransform(.stripDiacritics, reverse: false)?.localizedStandardContains(query)
        == true
  }

  static let catalog: [Self] = [
    .init(name: "Amsterdam", chinese: "阿姆斯特丹", country: "Netherlands", zone: "Europe/Amsterdam"),
    .init(name: "Athens", chinese: "雅典", country: "Greece", zone: "Europe/Athens"),
    .init(name: "Auckland", chinese: "奥克兰", country: "New Zealand", zone: "Pacific/Auckland"),
    .init(name: "Bangkok", chinese: "曼谷", country: "Thailand", zone: "Asia/Bangkok"),
    .init(name: "Beijing", chinese: "北京", country: "China", zone: "Asia/Shanghai"),
    .init(name: "Berlin", chinese: "柏林", country: "Germany", zone: "Europe/Berlin"),
    .init(
      name: "Buenos Aires", chinese: "布宜诺斯艾利斯", country: "Argentina",
      zone: "America/Argentina/Buenos_Aires"),
    .init(name: "Cairo", chinese: "开罗", country: "Egypt", zone: "Africa/Cairo"),
    .init(name: "Chicago", chinese: "芝加哥", country: "United States", zone: "America/Chicago"),
    .init(name: "Delhi", chinese: "新德里", country: "India", zone: "Asia/Kolkata"),
    .init(name: "Dubai", chinese: "迪拜", country: "United Arab Emirates", zone: "Asia/Dubai"),
    .init(name: "Hong Kong", chinese: "香港", country: "China", zone: "Asia/Hong_Kong"),
    .init(name: "Honolulu", chinese: "檀香山", country: "United States", zone: "Pacific/Honolulu"),
    .init(name: "Istanbul", chinese: "伊斯坦布尔", country: "Türkiye", zone: "Europe/Istanbul"),
    .init(name: "Jakarta", chinese: "雅加达", country: "Indonesia", zone: "Asia/Jakarta"),
    .init(
      name: "Johannesburg", chinese: "约翰内斯堡", country: "South Africa", zone: "Africa/Johannesburg"),
    .init(name: "Kathmandu", chinese: "加德满都", country: "Nepal", zone: "Asia/Kathmandu"),
    .init(name: "London", chinese: "伦敦", country: "United Kingdom", zone: "Europe/London"),
    .init(
      name: "Los Angeles", chinese: "洛杉矶", country: "United States", zone: "America/Los_Angeles"),
    .init(name: "Madrid", chinese: "马德里", country: "Spain", zone: "Europe/Madrid"),
    .init(name: "Mexico City", chinese: "墨西哥城", country: "Mexico", zone: "America/Mexico_City"),
    .init(name: "Moscow", chinese: "莫斯科", country: "Russia", zone: "Europe/Moscow"),
    .init(name: "New York", chinese: "纽约", country: "United States", zone: "America/New_York"),
    .init(name: "Paris", chinese: "巴黎", country: "France", zone: "Europe/Paris"),
    .init(name: "Rome", chinese: "罗马", country: "Italy", zone: "Europe/Rome"),
    .init(
      name: "San Francisco", chinese: "旧金山", country: "United States", zone: "America/Los_Angeles"),
    .init(name: "São Paulo", chinese: "圣保罗", country: "Brazil", zone: "America/Sao_Paulo"),
    .init(name: "Seoul", chinese: "首尔", country: "South Korea", zone: "Asia/Seoul"),
    .init(name: "Singapore", chinese: "新加坡", country: "Singapore", zone: "Asia/Singapore"),
    .init(name: "Sydney", chinese: "悉尼", country: "Australia", zone: "Australia/Sydney"),
    .init(name: "Taipei", chinese: "台北", country: "Taiwan", zone: "Asia/Taipei"),
    .init(name: "Tokyo", chinese: "东京", country: "Japan", zone: "Asia/Tokyo"),
    .init(name: "Toronto", chinese: "多伦多", country: "Canada", zone: "America/Toronto"),
    .init(name: "Vancouver", chinese: "温哥华", country: "Canada", zone: "America/Vancouver"),
  ]
  static var defaults: [Self] {
    ["Europe/London", "America/New_York", "Asia/Shanghai", "Asia/Tokyo"].compactMap { id in
      catalog.first { $0.zone == id }
    }
  }
}

enum ClockSound: String, Codable, CaseIterable {
  case marimba = "Marimba"
  case bell = "Bell Tower"
  case digital = "Digital"
  case ascending = "Ascending"
  case none = "None"
  case stopPlaying = "Stop Playing"
  var filename: String? {
    switch self {
    case .marimba: "marimba.wav"
    case .bell: "bell.wav"
    case .digital: "digital.wav"
    case .ascending: "ascending.wav"
    case .none, .stopPlaying: nil
    }
  }
  static var alarmSounds: [Self] { allCases.filter { $0 != .stopPlaying } }
  static var timerSounds: [Self] { allCases.filter { $0 != .none } }
}

struct ClockAlarm: Identifiable, Codable, Equatable {
  var id = UUID()
  var hour = 7
  var minute = 0
  var weekdays: Set<Int> = []
  var sound: ClockSound = .marimba
  var snooze = true
  var label = ""
  var enabled = true
  var scheduledFire: Date?
  var song: AlarmSong?
  var displayLabel: String { label.isEmpty ? L10n.text("Alarm") : label }

  func nextFire(after date: Date, calendar: Calendar = .current) -> Date? {
    let days: [Int?] = weekdays.isEmpty ? [nil] : weekdays.sorted().map { Optional($0) }
    return days.compactMap { day in
      var match = DateComponents()
      match.hour = hour
      match.minute = minute
      match.second = 0
      match.weekday = day
      return calendar.nextDate(
        after: date, matching: match, matchingPolicy: .nextTime,
        repeatedTimePolicy: .first, direction: .forward)
    }.min()
  }
  var repeatDescription: String {
    if weekdays.isEmpty { return L10n.text("Never") }
    if weekdays.count == 7 { return L10n.text("Every day") }
    if weekdays == Set(2...6) { return L10n.text("Weekdays") }
    if weekdays == [1, 7] { return L10n.text("Weekends") }
    return weekdays.sorted().map { ClockFormat.weekday($0, short: true) }.joined(separator: " ")
  }
}

struct AlarmSong: Codable, Equatable {
  let persistentID: UInt64
  let title: String
}

struct StopwatchState: Codable {
  var accumulated: TimeInterval = 0
  var startedAt: Date?
  var laps: [TimeInterval] = []
  var running: Bool { startedAt != nil }
  func elapsed(at date: Date) -> TimeInterval {
    max(0, accumulated + (startedAt.map { date.timeIntervalSince($0) } ?? 0))
  }
  func currentLap(at date: Date) -> TimeInterval { max(0, elapsed(at: date) - laps.reduce(0, +)) }
  mutating func start(at date: Date) { if !running { startedAt = date } }
  mutating func stop(at date: Date) {
    accumulated = elapsed(at: date)
    startedAt = nil
  }
  mutating func lap(at date: Date) { if running { laps.append(currentLap(at: date)) } }
  mutating func reset() { self = Self() }
}

struct CountdownState: Codable {
  var duration: TimeInterval = 60
  var remaining: TimeInterval = 60
  var deadline: Date?
  var sound: ClockSound = .marimba
  var running: Bool { deadline != nil }
  var active: Bool { running || remaining != duration }
  func seconds(at date: Date) -> TimeInterval {
    max(0, deadline.map { $0.timeIntervalSince(date) } ?? remaining)
  }
  mutating func start(at date: Date) {
    if !running && remaining > 0 { deadline = date.addingTimeInterval(remaining) }
  }
  mutating func pause(at date: Date) {
    remaining = seconds(at: date)
    deadline = nil
  }
  mutating func cancel() {
    deadline = nil
    remaining = duration
  }
  mutating func configure(hours: Int, minutes: Int) {
    guard !active else { return }
    duration = TimeInterval(hours * 3600 + minutes * 60)
    remaining = duration
  }
}

enum ClockFormat {
  static func time(_ date: Date, zone: TimeZone = .current, language: AppLanguage = .current)
    -> String
  {
    let formatter = DateFormatter()
    formatter.locale = language.locale
    formatter.timeZone = zone
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }
  static func alarmTime(_ alarm: ClockAlarm) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    let date = calendar.date(
      from: DateComponents(year: 2000, month: 1, day: 1, hour: alarm.hour, minute: alarm.minute))!
    return time(date, zone: .gmt)
  }
  static func day(_ date: Date, zone: TimeZone, localZone: TimeZone = .current) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = localZone
    let local = calendar.dateComponents([.year, .month, .day], from: date)
    calendar.timeZone = zone
    let remote = calendar.dateComponents([.year, .month, .day], from: date)
    calendar.timeZone = .gmt
    guard let a = calendar.date(from: local), let b = calendar.date(from: remote) else {
      return L10n.text("Today")
    }
    let difference = calendar.dateComponents([.day], from: a, to: b).day ?? 0
    return L10n.text(difference < 0 ? "Yesterday" : difference > 0 ? "Tomorrow" : "Today")
  }
  static func weekday(_ day: Int, short: Bool = false) -> String {
    let formatter = DateFormatter()
    formatter.locale = AppLanguage.current.locale
    return (short ? formatter.shortWeekdaySymbols! : formatter.weekdaySymbols!)[day - 1]
  }
  static func stopwatch(_ elapsed: TimeInterval) -> String {
    let tenths = Int(max(0, elapsed) * 10)
    return String(format: "%02d:%02d.%d", tenths / 600, (tenths / 10) % 60, tenths % 10)
  }
  static func countdown(_ elapsed: TimeInterval) -> String {
    let total = Int(ceil(max(0, elapsed)))
    if total < 3600 { return String(format: "%02d:%02d", total / 60, total % 60) }
    return String(format: "%02d:%02d:%02d", total / 3600, (total / 60) % 60, total % 60)
  }
}
