import Foundation

struct TimelinePlacement: Identifiable {
  var id: String { occurrence.id }
  let occurrence: EventOccurrence
  let startMinute: Double
  let endMinute: Double
  var column: Int
  var columns: Int
}

enum TimelineLayout {
  static func placements(_ occurrences: [EventOccurrence], on day: Date, calendar: Calendar)
    -> [TimelinePlacement]
  {
    let interval = calendar.dateInterval(of: .day, for: day)!
    let items = occurrences.filter { !$0.event.allDay }.sorted { $0.start < $1.start }
    var result: [TimelinePlacement] = []
    var group: [TimelinePlacement] = []
    var columnEnds: [Double] = []
    var groupEnd = 0.0
    func minute(_ date: Date) -> Double {
      if date <= interval.start { return 0 }
      if date >= interval.end { return 1440 }
      let parts = calendar.dateComponents([.hour, .minute, .second], from: date)
      return Double((parts.hour ?? 0) * 60 + (parts.minute ?? 0)) + Double(parts.second ?? 0) / 60
    }
    for item in items {
      let start = minute(item.start)
      let end = max(start + 15, minute(item.end))
      if start >= groupEnd, !group.isEmpty {
        result += group.map {
          var value = $0
          value.columns = columnEnds.count
          return value
        }
        group = []
        columnEnds = []
      }
      let column = columnEnds.firstIndex(where: { $0 <= start }) ?? columnEnds.count
      if column == columnEnds.count { columnEnds.append(end) } else { columnEnds[column] = end }
      group.append(
        TimelinePlacement(
          occurrence: item, startMinute: start,
          endMinute: min(1440, end), column: column, columns: 1))
      groupEnd = max(groupEnd, end)
    }
    result += group.map {
      var value = $0
      value.columns = columnEnds.count
      return value
    }
    return result
  }
}
