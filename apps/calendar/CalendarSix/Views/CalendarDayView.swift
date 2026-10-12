import SwiftUI

struct CalendarDayView: View {
  let store: CalendarStore
  @Binding var selectedDate: Date
  let open: (EventOccurrence) -> Void
  let create: (Date) -> Void
  var body: some View {
    VStack(spacing: 0) {
      CalendarDateHeader(
        title: CalendarFormat.date(selectedDate, template: "EEE d MMM yyyy"),
        previousLabel: "Previous Day", nextLabel: "Next Day",
        previous: { move(-1) }, next: { move(1) })
      CalendarAllDayBand(store: store, date: selectedDate, open: open)
      CalendarTimeline(store: store, dates: [selectedDate], open: open, create: create)
    }.background(.white)
  }
  private func move(_ days: Int) {
    selectedDate =
      store.calendar.date(byAdding: .day, value: days, to: selectedDate) ?? selectedDate
  }
}

struct CalendarAllDayBand: View {
  let store: CalendarStore
  let date: Date
  let open: (EventOccurrence) -> Void
  var body: some View {
    let events = store.occurrences(on: date).filter { $0.event.allDay }
    HStack(alignment: .top, spacing: 5) {
      Text(L10n.text("all-day")).font(.custom("HelveticaNeue", size: 12, relativeTo: .caption))
        .foregroundStyle(Color(white: 0.45)).frame(width: 64).padding(.top, 9)
      VStack(spacing: 3) {
        if events.isEmpty { Color.clear.frame(height: 30) }
        ForEach(events) { event in
          Button {
            open(event)
          } label: {
            Text(event.event.title).font(
              .custom("HelveticaNeue-Bold", size: 13, relativeTo: .caption)
            )
            .foregroundStyle(.black).frame(maxWidth: .infinity, alignment: .leading).padding(6)
            .background(
              (store.source(event.event.calendarID)?.color.color ?? CalendarPalette.blue).opacity(
                0.22), in: RoundedRectangle(cornerRadius: 4))
          }.buttonStyle(.plain).accessibilityIdentifier("all-day-" + event.event.id)
        }
      }.padding(.vertical, 3).padding(.trailing, 6)
    }.background(Color(red: 0.94, green: 0.95, blue: 0.97))
      .overlay(alignment: .bottom) { Color(white: 0.65).frame(height: 1) }
  }
}

struct CalendarWeekView: View {
  let store: CalendarStore
  @Binding var selectedDate: Date
  let open: (EventOccurrence) -> Void
  let create: (Date) -> Void
  private var dates: [Date] {
    let day = store.calendar.startOfDay(for: selectedDate)
    let offset =
      (store.calendar.component(.weekday, from: day) - store.calendar.firstWeekday + 7) % 7
    let start = store.calendar.date(byAdding: .day, value: -offset, to: day)!
    return (0..<7).map { store.calendar.date(byAdding: .day, value: $0, to: start)! }
  }
  var body: some View {
    VStack(spacing: 0) {
      CalendarDateHeader(
        title: CalendarFormat.date(selectedDate, template: "MMMM yyyy"),
        previousLabel: "Previous Week", nextLabel: "Next Week",
        previous: { move(-7) }, next: { move(7) })
      HStack(spacing: 0) {
        Text(L10n.text("Week")).font(.custom("HelveticaNeue", size: 11)).frame(width: 64)
        ForEach(dates, id: \.self) { day in
          Button {
            selectedDate = day
          } label: {
            Text(CalendarFormat.date(day, template: "EEE d")).font(
              .custom("HelveticaNeue-Bold", size: 13)
            )
            .foregroundStyle(
              store.calendar.isDate(day, inSameDayAs: selectedDate) ? .white : CalendarPalette.ink
            )
            .frame(maxWidth: .infinity).frame(height: 29)
            .background(
              store.calendar.isDate(day, inSameDayAs: selectedDate) ? CalendarPalette.blue : .clear)
          }.buttonStyle(.plain).accessibilityLabel(
            CalendarFormat.date(day, template: "EEEE MMMM d"))
        }
      }.background(Color(red: 0.86, green: 0.89, blue: 0.93))
      if dates.contains(where: { store.occurrences(on: $0).contains { $0.event.allDay } }) {
        HStack(alignment: .top, spacing: 0) {
          Text(L10n.text("all-day")).font(.custom("HelveticaNeue", size: 11)).frame(width: 64)
            .padding(.top, 5)
          ForEach(dates, id: \.self) { day in
            VStack(spacing: 2) {
              ForEach(store.occurrences(on: day).filter { $0.event.allDay }) { item in
                Button(item.event.title) { open(item) }.font(
                  .custom("HelveticaNeue-Bold", size: 10)
                )
                .lineLimit(1).padding(3).frame(maxWidth: .infinity)
                .background(
                  (store.source(item.event.calendarID)?.color.color ?? .blue).opacity(0.2))
              }
            }.frame(maxWidth: .infinity).padding(2)
          }
        }.background(.white)
      }
      CalendarTimeline(store: store, dates: dates, open: open, create: create)
    }.accessibilityElement(children: .contain).accessibilityIdentifier("week-view")
  }
  private func move(_ days: Int) {
    selectedDate =
      store.calendar.date(byAdding: .day, value: days, to: selectedDate) ?? selectedDate
  }
}

struct CalendarTimeline: View {
  let store: CalendarStore
  let dates: [Date]
  let open: (EventOccurrence) -> Void
  let create: (Date) -> Void
  private let hourHeight: CGFloat = 60

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        HStack(alignment: .top, spacing: 0) {
          VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
              Text(hourLabel(hour)).font(.custom("HelveticaNeue", size: 11, relativeTo: .caption2))
                .foregroundStyle(Color(white: 0.48)).frame(
                  width: 64, height: hourHeight, alignment: .topTrailing
                )
                .padding(.trailing, 7).id("hour-" + String(hour))
            }
          }.frame(width: 64)
          ForEach(dates, id: \.self) { day in column(day) }
        }.padding(.top, 8)
      }
      .background(.white).accessibilityIdentifier("timeline")
      .onAppear { proxy.scrollTo("hour-8", anchor: .top) }
    }
  }
  private func column(_ day: Date) -> some View {
    GeometryReader { geometry in
      let placements = TimelineLayout.placements(
        store.occurrences(on: day), on: day, calendar: store.calendar)
      ZStack(alignment: .topLeading) {
        VStack(spacing: 0) {
          ForEach(0..<24, id: \.self) { hour in
            Button {
              let date =
                store.calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
              create(date)
            } label: {
              Color.clear.frame(height: hourHeight)
                .overlay(alignment: .top) { Color(white: 0.82).frame(height: 0.5) }
                .overlay { Color(white: 0.92).frame(height: 0.5) }
                .contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel(L10n.text("Add Event") + " " + hourLabel(hour))
              .accessibilityIdentifier(
                "time-slot-" + CalendarFormat.dayID(day, calendar: store.calendar) + "-"
                  + String(hour))
          }
        }
        ForEach(placements) { placement in
          eventBlock(placement, width: geometry.size.width)
        }
        if store.calendar.isDate(day, inSameDayAs: store.testing || store.demo ? store.now : .now) {
          TimelineView(.everyMinute) { context in
            let now = store.testing || store.demo ? store.now : context.date
            let parts = store.calendar.dateComponents([.hour, .minute], from: now)
            let minutes = Double((parts.hour ?? 0) * 60 + (parts.minute ?? 0))
            Color.red.opacity(0.7).frame(height: 1).offset(y: minutes / 60 * hourHeight)
          }.allowsHitTesting(false).accessibilityHidden(true)
        }
      }.overlay(alignment: .leading) { Color(white: 0.84).frame(width: 0.5) }
    }.frame(height: hourHeight * 24).frame(maxWidth: .infinity)
  }
  private func eventBlock(_ placement: TimelinePlacement, width: CGFloat) -> some View {
    let color =
      store.source(placement.occurrence.event.calendarID)?.color.color ?? CalendarPalette.blue
    let blockWidth = max(10, (width - 4) / CGFloat(placement.columns) - 3)
    return Button {
      open(placement.occurrence)
    } label: {
      VStack(alignment: .leading, spacing: 2) {
        Text(placement.occurrence.event.title).font(
          .custom("HelveticaNeue-Bold", size: dates.count == 1 ? 14 : 11, relativeTo: .caption)
        ).lineLimit(2)
        if dates.count == 1, !placement.occurrence.event.location.isEmpty {
          Text(placement.occurrence.event.location).font(.custom("HelveticaNeue", size: 12))
            .lineLimit(1)
        }
        Spacer(minLength: 0)
      }.padding(5).frame(
        width: blockWidth,
        height: max(22, (placement.endMinute - placement.startMinute) / 60 * hourHeight - 1),
        alignment: .topLeading
      )
      .foregroundStyle(CalendarPalette.ink)
      .background(
        LinearGradient(
          colors: [color.opacity(0.28), color.opacity(0.46)], startPoint: .top, endPoint: .bottom),
        in: RoundedRectangle(cornerRadius: 4)
      )
      .overlay(RoundedRectangle(cornerRadius: 4).stroke(color.opacity(0.9), lineWidth: 1)).clipped()
    }.buttonStyle(.plain)
      .offset(
        x: 2 + CGFloat(placement.column) * (blockWidth + 3),
        y: placement.startMinute / 60 * hourHeight
      )
      .accessibilityIdentifier("timeline-event-" + placement.occurrence.event.id)
      .accessibilityLabel(
        placement.occurrence.event.title + ", " + CalendarFormat.time(placement.occurrence.start)
          + " – " + CalendarFormat.time(placement.occurrence.end))
  }
  private func hourLabel(_ hour: Int) -> String {
    if AppLanguage.current == .chinese { return String(format: "%02d:00", hour) }
    if hour == 0 { return L10n.text("12 AM") }
    if hour == 12 { return L10n.text("Noon") }
    return String(hour % 12) + " " + (hour < 12 ? "AM" : "PM")
  }
}
