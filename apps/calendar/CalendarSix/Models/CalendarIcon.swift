import Foundation
import Observation
import UIKit

struct CalendarIconDate: Equatable, Sendable {
  let language: AppLanguage
  let weekday: Int
  let day: Int

  init(date: Date, language: AppLanguage, timeZone: TimeZone = .autoupdatingCurrent) {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    self.language = language
    weekday = calendar.component(.weekday, from: date)
    day = calendar.component(.day, from: date)
  }

  init?(iconName: String) {
    let parts = iconName.split(separator: "_").map(String.init)
    guard parts.count == 4, parts[0] == "CalendarDate",
      let language = AppLanguage(rawValue: parts[1]),
      parts[2].hasPrefix("w"), let weekday = Int(parts[2].dropFirst()), (1...7).contains(weekday),
      parts[3].hasPrefix("d"), let day = Int(parts[3].dropFirst()), (1...31).contains(day)
    else { return nil }
    self.language = language
    self.weekday = weekday
    self.day = day
  }

  var iconName: String { "CalendarDate_\(language.rawValue)_w\(weekday)_d\(day)" }

  var label: String {
    let weekdays =
      language == .chinese
      ? ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"]
      : ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    return "\(weekdays[weekday - 1]) \(day)"
  }
}

@MainActor
protocol CalendarIconApplication: AnyObject {
  var supported: Bool { get }
  var active: Bool { get }
  var iconName: String? { get }
  func changeIcon(to name: String?) async throws
}

@MainActor
final class SystemCalendarIconApplication: CalendarIconApplication {
  var supported: Bool { UIApplication.shared.supportsAlternateIcons }
  var active: Bool { UIApplication.shared.applicationState == .active }
  var iconName: String? { UIApplication.shared.alternateIconName }
  func changeIcon(to name: String?) async throws {
    try await UIApplication.shared.setAlternateIconName(name)
  }
}

@MainActor @Observable
final class CalendarIconController {
  private(set) var enabled: Bool
  private(set) var updating = false
  private(set) var currentIconName: String?
  private(set) var error: String?
  let isolated: Bool
  private let application: any CalendarIconApplication
  private let defaults: UserDefaults?
  private let now: () -> Date
  private let language: () -> AppLanguage
  private let timeZone: () -> TimeZone
  private var refreshRequested = false
  static let preferenceKey = "dynamicCalendarIconEnabled"

  init(
    application: (any CalendarIconApplication)? = nil,
    defaults: UserDefaults? = .standard, isolated: Bool = false,
    now: @escaping () -> Date = { .now },
    language: @escaping () -> AppLanguage = { .current },
    timeZone: @escaping () -> TimeZone = { .autoupdatingCurrent }
  ) {
    let application = application ?? SystemCalendarIconApplication()
    self.application = application
    self.defaults = defaults
    self.isolated = isolated
    self.now = now
    self.language = language
    self.timeZone = timeZone
    enabled = defaults?.object(forKey: Self.preferenceKey) as? Bool ?? true
    currentIconName = application.iconName
  }

  var supported: Bool { application.supported }
  var currentLabel: String {
    currentIconName.flatMap(CalendarIconDate.init(iconName:))?.label ?? L10n.text("Original Icon")
  }

  func setEnabled(_ value: Bool) async {
    enabled = value
    defaults?.set(value, forKey: Self.preferenceKey)
    await refresh()
  }

  func refresh() async {
    guard !isolated, application.active else { return }
    refreshRequested = true
    guard !updating else { return }
    updating = true
    defer { updating = false }
    var retries = 0
    while refreshRequested {
      refreshRequested = false
      guard application.active else { return }
      guard supported else {
        error = "Icon changes are unavailable on this device."
        return
      }
      let target =
        enabled
        ? CalendarIconDate(date: now(), language: language(), timeZone: timeZone()).iconName : nil
      currentIconName = application.iconName
      guard currentIconName != target else {
        error = nil
        continue
      }
      do {
        try await application.changeIcon(to: target)
        currentIconName = application.iconName
        error = nil
      } catch {
        #if DEBUG
          print("CalendarSix icon change failed: \(error)")
        #endif
        let failure = error as NSError
        if failure.domain == NSPOSIXErrorDomain, failure.code == 35, retries < 2 {
          retries += 1
          refreshRequested = true
          try? await Task.sleep(for: .milliseconds(300 * retries))
        } else {
          self.error = "Unable to change the app icon. Try again."
        }
      }
    }
  }
}
