import Foundation

enum CalendarPickerComponent: String {
  case date, year, month, day, hour, minute, period

  var label: String {
    switch self {
    case .date: return L10n.text("Date")
    case .year: return L10n.text("Year")
    case .month: return L10n.text("Month")
    case .day: return L10n.text("Day of Month")
    case .hour: return L10n.text("Hour")
    case .minute: return L10n.text("Minute")
    case .period: return L10n.text("AM/PM")
    }
  }
}

enum CalendarPickerDate {
  static func replacing(
    _ component: CalendarPickerComponent, with value: Int, in date: Date,
    calendar: Calendar, twelveHour: Bool = false, minimum: Date? = nil
  ) -> Date {
    var parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    switch component {
    case .date:
      let first = calendar.date(from: DateComponents(year: 1, month: 1, day: 1))!
      let day = calendar.date(byAdding: .day, value: value, to: first)!
      let target = calendar.dateComponents([.year, .month, .day], from: day)
      parts.year = target.year
      parts.month = target.month
      parts.day = target.day
    case .year: parts.year = value
    case .month: parts.month = value
    case .day: parts.day = value
    case .hour: parts.hour = twelveHour ? value % 12 + (parts.hour! / 12) * 12 : value
    case .minute: parts.minute = value
    case .period: parts.hour = parts.hour! % 12 + value * 12
    }
    // Clamp month/year changes before constructing a date; February must not roll into March.
    let month = calendar.date(from: DateComponents(year: parts.year, month: parts.month, day: 1))!
    parts.day = min(parts.day!, calendar.range(of: .day, in: .month, for: month)!.count)
    let result = calendar.date(from: parts) ?? date
    return minimum.map { max(result, $0) } ?? result
  }

  static func value(
    _ component: CalendarPickerComponent, in date: Date, calendar: Calendar, twelveHour: Bool
  ) -> Int {
    switch component {
    case .date:
      let first = calendar.date(from: DateComponents(year: 1, month: 1, day: 1))!
      return calendar.dateComponents([.day], from: first, to: calendar.startOfDay(for: date)).day!
    case .year: return calendar.component(.year, from: date)
    case .month: return calendar.component(.month, from: date)
    case .day: return calendar.component(.day, from: date)
    case .hour:
      let hour = calendar.component(.hour, from: date)
      return twelveHour ? (hour % 12 == 0 ? 12 : hour % 12) : hour
    case .minute: return calendar.component(.minute, from: date)
    case .period: return calendar.component(.hour, from: date) / 12
    }
  }

  static func range(
    _ component: CalendarPickerComponent, date: Date, calendar: Calendar,
    twelveHour: Bool
  ) -> Range<Int> {
    switch component {
    case .date:
      let first = calendar.date(from: DateComponents(year: 1, month: 1, day: 1))!
      let end = calendar.date(from: DateComponents(year: 10000, month: 1, day: 1))!
      return 0..<calendar.dateComponents([.day], from: first, to: end).day!
    case .year: return 1..<10000
    case .month: return 1..<13
    case .day: return calendar.range(of: .day, in: .month, for: date)!
    case .hour: return twelveHour ? 1..<13 : 0..<24
    case .minute: return 0..<60
    case .period: return 0..<2
    }
  }
}
