import SwiftUI

private enum EditorPage: String {
  case start = "Starts"
  case end = "Ends"
  case repeatRule = "Repeat"
  case repeatEnd = "End Repeat"
  case alert = "Alert"
  case secondAlert = "Second Alert"
  case calendar = "Calendar"
  case timeZone = "Time Zone"
  case availability = "Availability"
}

struct EventEditorView: View {
  let store: CalendarStore
  let occurrence: EventOccurrence?
  let cancel: () -> Void
  let saved: (Date) -> Void
  @State private var draft: CalendarEvent
  @State private var page: EditorPage?
  @State private var choosingScope = false
  @State private var zoneQuery = ""
  @FocusState private var focused: String?
  @Environment(\.verticalSizeClass) private var verticalSizeClass

  init(
    store: CalendarStore, draft: CalendarEvent, occurrence: EventOccurrence?,
    cancel: @escaping () -> Void, saved: @escaping (Date) -> Void
  ) {
    self.store = store
    self.occurrence = occurrence
    self.cancel = cancel
    self.saved = saved
    _draft = State(initialValue: draft)
  }
  var body: some View {
    VStack(spacing: 0) {
      if let page { pageView(page) } else { form }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .allowsHitTesting(!choosingScope)
    .accessibilityHidden(choosingScope)
    .overlay {
      if choosingScope {
        CalendarActionSheet(
          title: "Save Repeating Event", options: scopes.map(\.rawValue), destructive: false,
          cancel: { choosingScope = false },
          select: { value in
            choosingScope = false
            if let scope = SeriesScope(rawValue: value) { commit(scope) }
          })
      }
    }
    .accessibilityAction(.escape) { if page != nil { page = nil } else { cancel() } }
  }
  private var form: some View {
    VStack(spacing: 0) {
      CalendarNavBar(title: L10n.text(occurrence == nil ? "Add Event" : "Edit Event")) {
        Button(L10n.text("Cancel"), action: cancel).buttonStyle(ClassicCalendarButtonStyle())
          .accessibilityIdentifier("editor-cancel")
      } right: {
        Button(L10n.text("Done")) {
          focused = nil
          if occurrence?.event.isRecurring == true { choosingScope = true } else { commit(.all) }
        }.buttonStyle(ClassicCalendarButtonStyle(primary: true))
          .disabled(
            draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !store.canWrite
          )
          .opacity(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)
          .accessibilityIdentifier("editor-save")
      }
      ScrollView {
        VStack(spacing: 23) {
          CalendarGroup {
            field("Title", text: $draft.title, id: "event-title")
            field("Location", text: $draft.location, id: "event-location")
          }
          CalendarGroup {
            HStack {
              Text(L10n.text("All-day")).font(.custom("HelveticaNeue", size: 17, relativeTo: .body))
              Spacer()
              CalendarSwitch(isOn: $draft.allDay, label: "All-day").accessibilityIdentifier(
                "all-day-toggle")
            }.padding(13).overlay(alignment: .bottom) { Color(white: 0.85).frame(height: 0.5) }
            row(.start, value: formatted(draft.start))
            row(.end, value: formatted(displayEnd))
            if !draft.allDay {
              row(
                .timeZone,
                value: TimeZone(identifier: draft.timeZoneID)?.localizedName(
                  for: .standard, locale: AppLanguage.current.locale) ?? draft.timeZoneID)
            }
          }
          CalendarGroup {
            row(
              .repeatRule,
              value: L10n.text(draft.complexRecurrence ? "Custom" : draft.repeatRule.rawValue)
            )
            .disabled(draft.complexRecurrence)
            if draft.repeatRule != .never {
              row(
                .repeatEnd,
                value: draft.repeatUntil.map { CalendarFormat.date($0, template: "yyyy MMM d") }
                  ?? L10n.text("Never"))
            }
          }
          CalendarGroup {
            row(.calendar, value: store.source(draft.calendarID)?.displayTitle ?? "")
          }
          CalendarGroup {
            row(
              .alert, value: draft.alertMinutes.first.map(CalendarFormat.alert) ?? L10n.text("None")
            )
            if !draft.alertMinutes.isEmpty {
              row(
                .secondAlert,
                value: draft.alertMinutes.dropFirst().first.map(CalendarFormat.alert)
                  ?? L10n.text("None"))
            }
            row(.availability, value: L10n.text(draft.busy ? "Busy" : "Free"))
          }
          CalendarGroup {
            field("URL", text: $draft.url, id: "event-url", url: true)
            VStack(alignment: .leading, spacing: 8) {
              Text(L10n.text("Notes")).foregroundStyle(Color(white: 0.5)).font(
                .custom("HelveticaNeue", size: 15))
              TextEditor(text: $draft.notes).font(
                .custom("HelveticaNeue", size: 17, relativeTo: .body)
              )
              .frame(minHeight: 100).focused($focused, equals: "notes").accessibilityIdentifier(
                "event-notes")
            }.padding(10)
          }
          if !draft.alertMinutes.isEmpty && occurrence?.event.systemID == nil {
            Text(
              L10n.text(
                "Enable notifications in Calendar Settings to receive local event reminders.")
            )
            .font(.custom("HelveticaNeue", size: 13, relativeTo: .footnote)).foregroundStyle(
              CalendarPalette.ink
            )
            .multilineTextAlignment(.center).padding(.horizontal, 22)
          }
        }.padding(.vertical, 22).frame(maxWidth: 650).frame(maxWidth: .infinity)
      }.scrollDismissesKeyboard(.interactively).accessibilityIdentifier("event-form")
    }
    .onChange(of: draft.allDay) { _, allDay in
      if allDay {
        draft = CalendarMath.normalized(draft, calendar: store.calendar)
      } else {
        var calendar = store.calendar
        calendar.timeZone = zone
        draft.start =
          calendar.date(bySettingHour: 9, minute: 0, second: 0, of: draft.start) ?? draft.start
        draft.end = draft.start.addingTimeInterval(3600)
      }
    }
  }
  private func field(_ label: String, text: Binding<String>, id: String, url: Bool = false)
    -> some View
  {
    TextField(L10n.text(label), text: text).font(
      .custom("HelveticaNeue", size: 17, relativeTo: .body)
    )
    .keyboardType(url ? .URL : .default).textInputAutocapitalization(url ? .never : .sentences)
    .autocorrectionDisabled(url).focused($focused, equals: id)
    .padding(13).frame(minHeight: 47).accessibilityLabel(L10n.text(label)).accessibilityIdentifier(
      id
    )
    .overlay(alignment: .bottom) { Color(white: 0.85).frame(height: 0.5) }
  }
  private func row(_ option: EditorPage, value: String) -> some View {
    Button {
      focused = nil
      page = option
    } label: {
      CalendarRow(title: option.rawValue, value: value, chevron: true)
    }
    .buttonStyle(.plain).accessibilityIdentifier(
      "edit-" + option.rawValue.lowercased().replacingOccurrences(of: " ", with: "-"))
  }

  @ViewBuilder private func pageView(_ option: EditorPage) -> some View {
    VStack(spacing: 0) {
      CalendarNavBar(
        title: L10n.text(option == .start || option == .end ? "Start & End" : option.rawValue)
      ) {
        Button(L10n.text("Back")) { page = nil }.buttonStyle(ClassicCalendarButtonStyle())
          .accessibilityIdentifier("option-back")
      } right: {
        EmptyView()
      }
      if option == .start || option == .end {
        if verticalSizeClass == .compact {
          HStack(alignment: .center, spacing: 0) {
            dateRows(option).frame(width: 260)
            wheel(option).frame(maxWidth: 650)
          }.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          VStack(spacing: 0) {
            dateRows(option).padding(.top, 28).frame(maxWidth: 650)
            Spacer(minLength: 16)
            wheel(option).frame(maxWidth: 650)
          }.frame(maxWidth: .infinity)
        }
      } else {
        ScrollView {
          VStack(spacing: 20) {
            switch option {
            case .start, .end:
              EmptyView()
            case .repeatRule:
              CalendarGroup {
                ForEach(RepeatRule.allCases, id: \.self) { rule in
                  choice(rule.rawValue, checked: draft.repeatRule == rule) {
                    draft.repeatRule = rule
                    page = nil
                  }
                }
              }
            case .repeatEnd:
              CalendarGroup {
                choice("Never", checked: draft.repeatUntil == nil) {
                  draft.repeatUntil = nil
                  page = nil
                }
                choice("On Date", checked: draft.repeatUntil != nil) {
                  draft.repeatUntil = store.calendar.date(
                    byAdding: .month, value: 1, to: draft.start)
                }
              }
              if draft.repeatUntil != nil {
                CalendarDatePicker(
                  selection: Binding(
                    get: { draft.repeatUntil ?? draft.start },
                    set: {
                      draft.repeatUntil = zoneCalendar.dateInterval(of: .day, for: $0)?.end
                        .addingTimeInterval(-1)
                    }), calendar: zoneCalendar, dateOnly: true, minimum: draft.start,
                  today: store.now
                ).accessibilityIdentifier("repeat-end-picker")
              }
            case .alert, .secondAlert:
              CalendarGroup {
                choice("None", checked: alertValue(option) == nil) { setAlert(nil, option) }
                ForEach([0, 5, 15, 30, 60, 120, 1440, 2880, 10080], id: \.self) { minutes in
                  choice(
                    CalendarFormat.alert(minutes), checked: alertValue(option) == minutes,
                    localized: true
                  ) { setAlert(minutes, option) }
                }
              }
            case .calendar:
              CalendarGroup {
                ForEach(availableCalendars) { source in
                  Button {
                    draft.calendarID = source.id
                    page = nil
                  } label: {
                    HStack {
                      Circle().fill(source.color.color).frame(width: 12, height: 12)
                      Text(source.displayTitle).font(.custom("HelveticaNeue", size: 17))
                      Spacer()
                      CalendarCheck(checked: draft.calendarID == source.id)
                    }.foregroundStyle(.black).padding(14).contentShape(Rectangle())
                  }.buttonStyle(.plain).accessibilityIdentifier("choose-calendar-" + source.id)
                }
              }
            case .timeZone:
              TextField(L10n.text("Search"), text: $zoneQuery).padding(12).background(.white)
                .padding(
                  .horizontal, 15
                )
                .accessibilityIdentifier("search-timezone")
              CalendarGroup {
                ForEach(
                  TimeZone.knownTimeZoneIdentifiers.filter {
                    zoneQuery.isEmpty || $0.localizedStandardContains(zoneQuery)
                  }, id: \.self
                ) { identifier in
                  choice(identifier, checked: identifier == draft.timeZoneID, localized: true) {
                    draft.timeZoneID = identifier
                    page = nil
                  }
                }
              }
            case .availability:
              CalendarGroup {
                choice("Busy", checked: draft.busy) {
                  draft.busy = true
                  page = nil
                }
                choice("Free", checked: !draft.busy) {
                  draft.busy = false
                  page = nil
                }
              }
            }
          }.padding(.vertical, 22).frame(maxWidth: 650).frame(maxWidth: .infinity)
        }
      }
    }
  }
  private func dateRows(_ option: EditorPage) -> some View {
    CalendarGroup {
      dateSelectionRow(.start, selected: option == .start)
      dateSelectionRow(.end, selected: option == .end)
    }
  }
  private func dateSelectionRow(_ option: EditorPage, selected: Bool) -> some View {
    Button {
      page = option
    } label: {
      HStack {
        Text(L10n.text(option.rawValue)).font(
          .custom("HelveticaNeue-Bold", size: 17, relativeTo: .body))
        Spacer(minLength: 8)
        Text(formatted(option == .start ? draft.start : displayEnd))
          .font(.custom("HelveticaNeue", size: 16, relativeTo: .body))
          .lineLimit(1).minimumScaleFactor(0.7)
      }
      .foregroundStyle(selected ? .white : CalendarPalette.ink)
      .padding(.horizontal, 14).frame(minHeight: 48)
      .background {
        if selected {
          LinearGradient(
            colors: [
              Color(red: 0.22, green: 0.48, blue: 0.94), Color(red: 0.08, green: 0.20, blue: 0.78),
            ],
            startPoint: .top, endPoint: .bottom)
        }
      }
      .overlay(alignment: .bottom) { Color(white: 0.6).opacity(0.5).frame(height: 0.5) }
      .contentShape(Rectangle())
    }.buttonStyle(.plain).accessibilityIdentifier("picker-" + option.rawValue.lowercased())
      .accessibilityAddTraits(selected ? .isSelected : [])
  }
  private func wheel(_ option: EditorPage) -> some View {
    CalendarDatePicker(
      selection: Binding(
        get: {
          option == .start ? draft.start : displayEnd
        },
        set: { date in
          if option == .start {
            let duration = draft.end.timeIntervalSince(draft.start)
            let days =
              zoneCalendar.dateComponents([.day], from: draft.start, to: draft.end).day ?? 1
            draft.start = date
            draft.end =
              draft.allDay
              ? zoneCalendar.date(byAdding: .day, value: max(1, days), to: date)!
              : date.addingTimeInterval(duration)
          } else {
            draft.end =
              draft.allDay
              ? zoneCalendar.date(byAdding: .day, value: 1, to: zoneCalendar.startOfDay(for: date))!
              : date
          }
        }), calendar: zoneCalendar, dateOnly: draft.allDay, today: store.now
    )
    .id(option).accessibilityIdentifier("event-date-picker")
  }
  private func choice(
    _ title: String, checked: Bool, localized: Bool = false, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack {
        Text(localized ? title : L10n.text(title))
        Spacer()
        CalendarCheck(checked: checked)
      }
      .font(.custom("HelveticaNeue", size: 17, relativeTo: .body)).foregroundStyle(.black)
      .padding(14).frame(minHeight: 47).contentShape(Rectangle())
      .overlay(alignment: .bottom) { Color(white: 0.85).frame(height: 0.5) }
    }.buttonStyle(.plain).accessibilityIdentifier("choice-" + title)
      .accessibilityAddTraits(checked ? .isSelected : [])
  }
  private var zone: TimeZone { TimeZone(identifier: draft.timeZoneID) ?? .current }
  private var zoneCalendar: Calendar {
    var value = store.calendar
    value.timeZone = zone
    return value
  }
  private var displayEnd: Date {
    draft.allDay ? zoneCalendar.date(byAdding: .day, value: -1, to: draft.end)! : draft.end
  }
  private func formatted(_ date: Date) -> String {
    CalendarFormat.date(
      date, template: draft.allDay ? "EEE yyyy MMM d" : "EEE MMM d", timeZone: zone)
      + (draft.allDay ? "" : "  " + CalendarFormat.time(date, timeZone: zone))
  }
  private var availableCalendars: [CalendarSource] {
    store.writableCalendars.filter { source in
      guard let occurrence else { return true }
      return source.system == (occurrence.event.systemID != nil)
    }
  }
  private var scopes: [SeriesScope] {
    occurrence?.event.systemID != nil ? [.thisEvent, .future] : [.thisEvent, .future, .all]
  }
  private func alertValue(_ option: EditorPage) -> Int? {
    option == .alert ? draft.alertMinutes.first : draft.alertMinutes.dropFirst().first
  }
  private func setAlert(_ minutes: Int?, _ option: EditorPage) {
    if option == .alert {
      if let minutes {
        draft.alertMinutes =
          [minutes] + Array(draft.alertMinutes.dropFirst()).filter { $0 != minutes }
      } else {
        draft.alertMinutes = []
      }
    } else {
      draft.alertMinutes = Array(draft.alertMinutes.prefix(1)) + (minutes.map { [$0] } ?? [])
      draft.alertMinutes = Array(Set(draft.alertMinutes)).sorted()
    }
    page = nil
  }
  private func commit(_ scope: SeriesScope) {
    if store.save(draft, occurrence: occurrence, scope: scope) { saved(draft.start) }
  }
}

struct CalendarSwitch: View {
  @Binding var isOn: Bool
  let label: String
  var body: some View {
    Button {
      isOn.toggle()
    } label: {
      ZStack(alignment: isOn ? .trailing : .leading) {
        RoundedRectangle(cornerRadius: 16).fill(
          LinearGradient(
            colors: isOn
              ? [
                Color(red: 0.09, green: 0.33, blue: 0.70),
                Color(red: 0.29, green: 0.61, blue: 0.97),
              ] : [Color(white: 0.6), Color(white: 0.92)], startPoint: .top, endPoint: .bottom))
        Text(L10n.text(isOn ? "ON" : "OFF")).font(.custom("HelveticaNeue-Bold", size: 12))
          .foregroundStyle(isOn ? .white : Color(white: 0.45))
          .offset(x: isOn ? -16 : 16).frame(maxWidth: .infinity)
        Circle().fill(
          LinearGradient(colors: [.white, Color(white: 0.8)], startPoint: .top, endPoint: .bottom)
        )
        .frame(width: 29, height: 29).overlay(Circle().stroke(Color(white: 0.5), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.3), radius: 1, x: isOn ? -1 : 1)
      }.frame(width: 78, height: 31).overlay(
        RoundedRectangle(cornerRadius: 16).stroke(.black.opacity(0.3), lineWidth: 1))
    }.buttonStyle(.plain).accessibilityRepresentation { Toggle(L10n.text(label), isOn: $isOn) }
  }
}

struct CalendarActionSheet: View {
  let title: String
  let options: [String]
  var destructive = true
  let cancel: () -> Void
  let select: (String) -> Void
  var body: some View {
    ZStack(alignment: .bottom) {
      Color.black.opacity(0.4).ignoresSafeArea().accessibilityHidden(true)
      VStack(spacing: 13) {
        Text(L10n.text(title)).font(.custom("HelveticaNeue-Bold", size: 16)).foregroundStyle(.white)
          .shadow(color: .black, radius: 0, y: -1).multilineTextAlignment(.center)
        ForEach(options, id: \.self) { value in
          Button {
            select(value)
          } label: {
            Text(L10n.text(value)).frame(maxWidth: .infinity).frame(minHeight: 38)
          }.buttonStyle(ClassicCalendarButtonStyle(primary: !destructive, destructive: destructive))
            .accessibilityIdentifier("scope-" + value)
        }
        Button(L10n.text("Cancel"), action: cancel).frame(maxWidth: .infinity).buttonStyle(
          ClassicCalendarButtonStyle()
        )
        .accessibilityIdentifier("scope-cancel")
      }.padding(20).background(
        LinearGradient(
          colors: [Color(white: 0.4), Color(white: 0.18)], startPoint: .top, endPoint: .bottom)
      )
      .accessibilityElement(children: .contain)
      .accessibilityAddTraits(.isModal)
    }
  }
}
