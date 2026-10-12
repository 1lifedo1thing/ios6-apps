import SwiftUI

struct EventDetailView: View {
  let store: CalendarStore
  let occurrence: EventOccurrence
  let back: () -> Void
  let edit: () -> Void
  @State private var deleting = false
  @Environment(\.openURL) private var openURL
  private var event: CalendarEvent { occurrence.event }
  private var writable: Bool { store.source(event.calendarID)?.writable == true }
  var body: some View {
    VStack(spacing: 0) {
      CalendarNavBar(title: L10n.text("Event Details")) {
        Button(L10n.text("Back"), action: back).buttonStyle(ClassicCalendarButtonStyle())
          .accessibilityIdentifier("detail-back")
      } right: {
        if writable {
          Button(L10n.text("Edit"), action: edit).buttonStyle(ClassicCalendarButtonStyle())
            .accessibilityIdentifier("edit-event")
        }
      }
      ScrollView {
        VStack(spacing: 22) {
          CalendarGroup {
            VStack(alignment: .leading, spacing: 12) {
              Text(event.title).font(.custom("HelveticaNeue-Bold", size: 25, relativeTo: .title2))
                .accessibilityIdentifier("detail-title")
              if !event.location.isEmpty {
                Button {
                  openMaps()
                } label: {
                  Text(event.location).font(.custom("HelveticaNeue", size: 17, relativeTo: .body))
                    .foregroundStyle(CalendarPalette.blue)
                }.buttonStyle(.plain).accessibilityLabel(
                  L10n.text("Open Location in Maps") + ": " + event.location)
              }
              Text(dateDescription).font(.custom("HelveticaNeue", size: 17, relativeTo: .body))
                .foregroundStyle(CalendarPalette.ink)
              if !event.allDay {
                Text(
                  TimeZone(identifier: event.timeZoneID)?.localizedName(
                    for: .standard, locale: AppLanguage.current.locale) ?? event.timeZoneID
                ).font(.custom("HelveticaNeue", size: 12)).foregroundStyle(Color(white: 0.5))
              }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
          }
          CalendarGroup {
            HStack {
              Circle().fill(store.source(event.calendarID)?.color.color ?? .blue).frame(
                width: 12, height: 12)
              CalendarRow(
                title: "Calendar", value: store.source(event.calendarID)?.displayTitle ?? "")
            }.padding(.leading, 13)
            if event.isRecurring {
              CalendarRow(
                title: "Repeat",
                value: L10n.text(event.complexRecurrence ? "Custom" : event.repeatRule.rawValue))
            }
            ForEach(event.alertMinutes, id: \.self) { alert in
              CalendarRow(title: "Alert", value: CalendarFormat.alert(alert))
            }
            CalendarRow(title: "Availability", value: L10n.text(event.busy ? "Busy" : "Free"))
          }
          if !event.attendees.isEmpty {
            CalendarGroup(title: "Invitees") {
              ForEach(event.attendees, id: \.self) { name in CalendarRow(title: name) }
            }
          }
          if !event.url.isEmpty || !event.notes.isEmpty {
            CalendarGroup {
              if let url = URL(string: event.url),
                ["http", "https"].contains(url.scheme?.lowercased() ?? "")
              {
                Button {
                  openURL(url)
                } label: {
                  CalendarRow(title: "URL", value: event.url, chevron: true)
                }.buttonStyle(.plain)
              }
              if !event.notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                  Text(L10n.text("Notes")).foregroundStyle(Color(white: 0.5)).font(
                    .custom("HelveticaNeue", size: 14))
                  Text(event.notes).font(.custom("HelveticaNeue", size: 17, relativeTo: .body))
                    .textSelection(.enabled)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(14)
              }
            }
          }
          if event.systemID != nil {
            Button(L10n.text("Open in System Calendar")) { openSystemCalendar() }
              .buttonStyle(ClassicCalendarButtonStyle()).accessibilityIdentifier(
                "open-system-event")
          }
          if writable {
            Button(L10n.text("Delete Event")) { deleting = true }
              .buttonStyle(ClassicCalendarButtonStyle(destructive: true)).accessibilityIdentifier(
                "delete-event"
              )
              .padding(.vertical, 5)
          }
        }.padding(.vertical, 23).frame(maxWidth: 650).frame(maxWidth: .infinity)
      }
    }
    .allowsHitTesting(!deleting)
    .accessibilityHidden(deleting)
    .overlay {
      if deleting {
        CalendarActionSheet(
          title: event.isRecurring ? "Delete Repeating Event" : "Delete this event?",
          options: deletionOptions,
          cancel: { deleting = false },
          select: { option in
            deleting = false
            if store.delete(occurrence, scope: SeriesScope(rawValue: option) ?? .all) { back() }
          })
      }
    }
    .accessibilityAction(.escape, back)
  }
  private var deletionOptions: [String] {
    guard event.isRecurring else { return ["Delete Event"] }
    return
      (event.systemID == nil ? [SeriesScope.thisEvent, .future, .all] : [.thisEvent, .future]).map(
        \.rawValue)
  }
  private var dateDescription: String {
    let zone = TimeZone(identifier: event.timeZoneID) ?? .current
    var calendar = store.calendar
    calendar.timeZone = zone
    if event.allDay {
      let lastDay =
        calendar.date(byAdding: .day, value: -1, to: occurrence.end) ?? occurrence.start
      let range =
        calendar.isDate(occurrence.start, inSameDayAs: lastDay)
        ? "" : " – " + CalendarFormat.date(lastDay, template: "yyyy MMM d", timeZone: zone)
      return CalendarFormat.date(occurrence.start, template: "EEEE yyyy MMM d", timeZone: zone)
        + range + "\n"
        + L10n.text("All-day")
    }
    let sameDay = calendar.isDate(occurrence.start, inSameDayAs: occurrence.end)
    return CalendarFormat.date(occurrence.start, template: "EEEE yyyy MMM d", timeZone: zone) + "\n"
      + CalendarFormat.time(occurrence.start, timeZone: zone) + " – "
      + (sameDay
        ? "" : CalendarFormat.date(occurrence.end, template: "yyyy MMM d", timeZone: zone) + " ")
      + CalendarFormat.time(occurrence.end, timeZone: zone)
  }
  private func openMaps() {
    var parts = URLComponents(string: "https://maps.apple.com/")!
    parts.queryItems = [URLQueryItem(name: "q", value: event.location)]
    if let url = parts.url { openURL(url) }
  }
  private func openSystemCalendar() {
    if let url = URL(string: "calshow:" + String(occurrence.start.timeIntervalSinceReferenceDate)) {
      openURL(url)
    }
  }
}
