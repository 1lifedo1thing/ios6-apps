import SwiftUI

struct CalendarDateHeader: View {
  let title: String
  var previousLabel = "Previous Month"
  var nextLabel = "Next Month"
  let previous: () -> Void
  let next: () -> Void
  var body: some View {
    HStack {
      Button(action: previous) {
        Image(systemName: "arrowtriangle.left.fill").frame(width: 48, height: 44)
      }
      .accessibilityLabel(L10n.text(previousLabel)).accessibilityIdentifier("previous-period")
      Spacer(minLength: 0)
      Text(title).font(.custom("HelveticaNeue-Bold", size: 25, relativeTo: .title2))
        .lineLimit(1).minimumScaleFactor(0.65).shadow(color: .white, radius: 0, y: 1)
        .accessibilityIdentifier("date-heading")
      Spacer(minLength: 0)
      Button(action: next) {
        Image(systemName: "arrowtriangle.right.fill").frame(width: 48, height: 44)
      }
      .accessibilityLabel(L10n.text(nextLabel)).accessibilityIdentifier("next-period")
    }
    .foregroundStyle(CalendarPalette.ink).buttonStyle(.plain)
    .background(
      LinearGradient(
        colors: [Color(white: 0.98), Color(red: 0.84, green: 0.86, blue: 0.89)], startPoint: .top,
        endPoint: .bottom))
  }
}

struct CalendarMonthView: View {
  let store: CalendarStore
  @Binding var selectedDate: Date
  let open: (EventOccurrence) -> Void

  var body: some View {
    GeometryReader { geometry in
      let days = CalendarMath.monthDays(containing: selectedDate, calendar: store.calendar)
      let height = max(
        40,
        min(
          geometry.size.width / 7 * 0.91,
          geometry.size.height * 0.60 / CGFloat(max(1, days.count / 7))))
      let marked = markedDates(days)
      VStack(spacing: 0) {
        CalendarDateHeader(
          title: CalendarFormat.date(selectedDate, template: "MMMM yyyy"),
          previous: { move(-1) }, next: { move(1) })
        HStack(spacing: 0) {
          ForEach(weekdayNumbers, id: \.self) { number in
            Text(weekdayName(number)).font(
              .custom("HelveticaNeue-Bold", size: 12, relativeTo: .caption)
            )
            .foregroundStyle(CalendarPalette.ink).frame(maxWidth: .infinity).frame(height: 22)
            .shadow(color: .white, radius: 0, y: 1)
          }
        }.background(Color(red: 0.85, green: 0.87, blue: 0.90))
        LazyVGrid(
          columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0
        ) {
          ForEach(days, id: \.self) { day in
            dateCell(
              day, height: height, marked: marked.contains(store.calendar.startOfDay(for: day)))
          }
        }
        .overlay(alignment: .bottom) { Color(white: 0.5).frame(height: 1) }
        .shadow(color: .black.opacity(0.22), radius: 2, y: 2)
        CalendarAgendaView(store: store, events: store.occurrences(on: selectedDate), open: open)
      }.background(.white)
    }
  }

  private func dateCell(_ day: Date, height: CGFloat, marked: Bool) -> some View {
    let selected = store.calendar.isDate(day, inSameDayAs: selectedDate)
    let sameMonth = store.calendar.isDate(day, equalTo: selectedDate, toGranularity: .month)
    let today = store.calendar.isDate(
      day, inSameDayAs: store.testing || store.demo ? store.now : .now)
    return Button {
      selectedDate = day
    } label: {
      VStack(spacing: 2) {
        Text(String(store.calendar.component(.day, from: day)))
          .font(.custom("HelveticaNeue-Bold", size: min(31, height * 0.57), relativeTo: .title2))
          .foregroundStyle(
            selected
              ? .white
              : !sameMonth ? Color(white: 0.65) : today ? CalendarPalette.blue : CalendarPalette.ink
          )
          .shadow(color: selected ? .black.opacity(0.4) : .white, radius: 0, y: selected ? -1 : 1)
        Circle().fill(marked ? (selected ? .white : CalendarPalette.ink) : .clear).frame(
          width: 4, height: 4)
      }.frame(maxWidth: .infinity).frame(height: height)
        .background {
          if selected {
            LinearGradient(
              colors: [
                Color(red: 0.13, green: 0.35, blue: 0.62),
                Color(red: 0.32, green: 0.58, blue: 0.90),
              ], startPoint: .top, endPoint: .bottom)
          } else {
            LinearGradient(
              colors: [
                Color(white: sameMonth ? 0.96 : 0.92), Color(red: 0.86, green: 0.88, blue: 0.91),
              ], startPoint: .top, endPoint: .bottom)
          }
        }
        .overlay(alignment: .top) {
          (selected ? Color.black.opacity(0.25) : Color.white.opacity(0.8)).frame(height: 1)
        }
        .overlay(alignment: .leading) {
          (selected ? Color.black.opacity(0.25) : Color.white.opacity(0.7)).frame(width: 1)
        }
        .overlay(alignment: .bottom) { Color.black.opacity(0.17).frame(height: 0.5) }
        .overlay(alignment: .trailing) { Color.black.opacity(0.17).frame(width: 0.5) }
    }.buttonStyle(.plain)
      .accessibilityLabel(
        CalendarFormat.date(day, template: "EEEE MMMM d yyyy")
          + (marked ? ", " + L10n.text("Has Events") : "")
      )
      .accessibilityAddTraits(selected ? .isSelected : [])
      .accessibilityIdentifier("date-" + CalendarFormat.dayID(day, calendar: store.calendar))
  }
  private var weekdayNumbers: [Int] { (0..<7).map { (store.calendar.firstWeekday - 1 + $0) % 7 } }
  private func weekdayName(_ number: Int) -> String {
    let formatter = DateFormatter()
    formatter.locale = AppLanguage.current.locale
    return formatter.shortWeekdaySymbols[number]
  }
  private func markedDates(_ days: [Date]) -> Set<Date> {
    guard let first = days.first, let last = days.last,
      let end = store.calendar.date(byAdding: .day, value: 1, to: last)
    else { return [] }
    let items = store.occurrences(in: DateInterval(start: first, end: end))
    return Set(
      days.filter { day in
        let interval = store.calendar.dateInterval(of: .day, for: day)!
        return items.contains {
          CalendarMath.overlaps(start: $0.start, end: $0.end, range: interval)
        }
      }.map { store.calendar.startOfDay(for: $0) })
  }
  private func move(_ months: Int) {
    selectedDate =
      store.calendar.date(byAdding: .month, value: months, to: selectedDate) ?? selectedDate
  }
}

struct CalendarAgendaView: View {
  let store: CalendarStore
  let events: [EventOccurrence]
  let open: (EventOccurrence) -> Void
  var body: some View {
    GeometryReader { geometry in
      ScrollView {
        VStack(spacing: 0) {
          if events.isEmpty {
            Text(L10n.text("No Events"))
              .font(.custom("HelveticaNeue-Bold", size: 20, relativeTo: .headline))
              .foregroundStyle(Color(white: 0.68))
              .shadow(color: .white, radius: 0, y: 1)
              .frame(maxWidth: .infinity).frame(height: 52).padding(.top, 52)
          } else {
            LazyVStack(spacing: 0) {
              ForEach(events) { occurrence in
                CalendarEventRow(
                  occurrence: occurrence, source: store.source(occurrence.event.calendarID),
                  open: { open(occurrence) })
              }
            }
          }
          Spacer(minLength: 0)
        }.frame(minHeight: geometry.size.height, alignment: .top)
      }
      .accessibilityIdentifier("agenda")
      .background { CalendarAgendaPaper() }
      .overlay(alignment: .top) {
        LinearGradient(colors: [.black.opacity(0.15), .clear], startPoint: .top, endPoint: .bottom)
          .frame(height: 6).allowsHitTesting(false).accessibilityHidden(true)
      }
    }
  }
}

private struct CalendarAgendaPaper: View {
  var body: some View {
    Canvas { context, size in
      context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
      var rules = Path()
      for y in stride(from: 52.0, through: size.height, by: 52) {
        rules.move(to: CGPoint(x: 0, y: y))
        rules.addLine(to: CGPoint(x: size.width, y: y))
      }
      context.stroke(rules, with: .color(Color(white: 0.84)), lineWidth: 0.5)
    }.allowsHitTesting(false).accessibilityHidden(true)
  }
}

struct CalendarEventRow: View {
  let occurrence: EventOccurrence
  let source: CalendarSource?
  let open: () -> Void
  @ScaledMetric(relativeTo: .body) private var timeColumnWidth = 86.0
  var body: some View {
    Button(action: open) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        let color = source?.color.color ?? CalendarPalette.blue
        Circle().fill(
          RadialGradient(
            colors: [color.opacity(0.65), color, color.opacity(0.85)],
            center: .topLeading, startRadius: 0, endRadius: 11)
        ).frame(width: 11, height: 11)
          .overlay(Circle().stroke(.black.opacity(0.20), lineWidth: 0.5))
          .overlay(alignment: .top) {
            Capsule().fill(.white.opacity(0.7)).frame(width: 5, height: 1.5).offset(y: 1.5)
          }
          .shadow(color: .black.opacity(0.13), radius: 0.5, y: 1)
        Text(occurrence.event.allDay ? L10n.text("all-day") : CalendarFormat.time(occurrence.start))
          .font(.custom("HelveticaNeue-Bold", size: 17, relativeTo: .body))
          .foregroundStyle(.black).lineLimit(1)
          .frame(
            width: AppLanguage.current == .english ? timeColumnWidth : timeColumnWidth * 65 / 86,
            alignment: .leading)
        VStack(alignment: .leading, spacing: 1) {
          Text(occurrence.event.title).font(
            .custom("HelveticaNeue-Bold", size: 18, relativeTo: .headline)
          ).foregroundStyle(.black).lineLimit(2)
          if !occurrence.event.location.isEmpty {
            Text(occurrence.event.location).font(
              .custom("HelveticaNeue", size: 14, relativeTo: .caption)
            ).foregroundStyle(Color(white: 0.45)).lineLimit(1)
          }
        }
        Spacer(minLength: 0)
      }.padding(.horizontal, 10).padding(.vertical, 6).frame(minHeight: 52)
        .background(.white)
        .overlay(alignment: .bottom) { Color(white: 0.84).frame(height: 0.5) }
        .contentShape(Rectangle())
    }.buttonStyle(CalendarAgendaButtonStyle()).accessibilityIdentifier(
      "event-" + occurrence.event.id
    )
    .accessibilityLabel(
      occurrence.event.title + ", "
        + (occurrence.event.allDay ? L10n.text("All-day") : CalendarFormat.time(occurrence.start))
        + (occurrence.event.allDay ? "" : ", " + CalendarFormat.time(occurrence.end))
        + ", " + (source?.displayTitle ?? "") + ", " + occurrence.event.location)
  }
}

private struct CalendarAgendaButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.overlay {
      if configuration.isPressed {
        LinearGradient(
          colors: [CalendarPalette.blue.opacity(0.25), CalendarPalette.blue.opacity(0.08)],
          startPoint: .top, endPoint: .bottom
        ).allowsHitTesting(false)
      }
    }
  }
}
