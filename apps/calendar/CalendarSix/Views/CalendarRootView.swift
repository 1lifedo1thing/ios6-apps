import EventKit
import SwiftUI
import UIKit

enum CalendarRoute: Identifiable {
  case calendars, settings, inbox
  case detail(EventOccurrence)
  case editor(CalendarEvent, EventOccurrence?)
  var id: String {
    switch self {
    case .calendars: return "calendars"
    case .settings: return "settings"
    case .inbox: return "inbox"
    case .detail(let item): return "detail:" + item.id
    case .editor(let item, _): return "editor:" + item.id
    }
  }
}

struct CalendarRootView: View {
  let store: CalendarStore
  let icon: CalendarIconController
  @State private var selectedDate: Date
  @State private var route: CalendarRoute?
  @State private var query = ""
  @Environment(\.verticalSizeClass) private var verticalSizeClass
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase

  init(store: CalendarStore, icon: CalendarIconController) {
    self.store = store
    self.icon = icon
    _selectedDate = State(initialValue: store.now)
  }
  var body: some View {
    GeometryReader { _ in
      ZStack {
        if let route {
          destination(route).id(route.id).transition(.move(edge: .trailing))
        } else {
          main.transition(.move(edge: .leading))
        }
      }.frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
        .background { CalendarPinstripes().ignoresSafeArea() }
    }
    .fullScreenCover(item: noticeBinding) { notice in
      CalendarNotice(message: notice.message) { store.error = nil }
        .presentationBackground(.clear)
        .interactiveDismissDisabled()
    }
    .task {
      await icon.refresh()
      store.loadSystem(around: selectedDate)
      await store.refreshNotifications()
      store.scheduleReminders()
    }
    .onChange(of: selectedDate) { _, date in store.loadSystem(around: date) }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active {
        store.refreshSystem()
        Task {
          await icon.refresh()
          await store.refreshNotifications()
          store.scheduleReminders()
        }
      } else {
        store.persist()
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
      store.refreshSystem()
    }
    .onReceive(
      NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)
    ) { _ in
      Task { await icon.refresh() }
    }
    .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
      Task { await icon.refresh() }
    }
    .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
      Task { await icon.refresh() }
    }
  }

  private var noticeBinding: Binding<CalendarErrorNotice?> {
    Binding(
      get: { store.error.map { CalendarErrorNotice(message: $0) } },
      set: { store.error = $0?.message })
  }

  private var main: some View {
    VStack(spacing: 0) {
      CalendarNavBar(title: "") {
        Button(L10n.text("Calendars")) { navigate(.calendars) }
          .buttonStyle(ClassicCalendarButtonStyle()).accessibilityIdentifier("calendars")
      } right: {
        Button {
          navigate(.editor(store.draft(on: selectedDate), nil))
        } label: {
          Text("+").font(.custom("HelveticaNeue-Bold", size: 27)).frame(width: 20)
        }.buttonStyle(ClassicCalendarButtonStyle()).accessibilityLabel(L10n.text("Add Event"))
          .accessibilityIdentifier("add-event")
      }
      // iPhone orientation traits remain stable when the keyboard reduces content height.
      if verticalSizeClass == .compact {
        CalendarWeekView(store: store, selectedDate: $selectedDate, open: open, create: create)
      } else {
        switch store.preferences.mode {
        case .month: CalendarMonthView(store: store, selectedDate: $selectedDate, open: open)
        case .day:
          CalendarDayView(store: store, selectedDate: $selectedDate, open: open, create: create)
        case .list:
          CalendarListView(store: store, selectedDate: $selectedDate, query: $query, open: open)
        }
      }
      footer
    }
  }
  private var footer: some View {
    HStack(spacing: 8) {
      Button(L10n.text("Today")) { selectedDate = store.testing || store.demo ? store.now : .now }
        .buttonStyle(ClassicCalendarButtonStyle()).accessibilityIdentifier("today")
      Spacer(minLength: 0)
      HStack(spacing: 0) {
        ForEach(CalendarMode.allCases, id: \.self) { mode in
          Button {
            store.preferences.mode = mode
            store.persist()
          } label: {
            Text(L10n.text(mode.rawValue)).font(
              .custom("HelveticaNeue-Bold", size: 13, relativeTo: .caption)
            )
            .foregroundStyle(.white).shadow(color: .black.opacity(0.65), radius: 0, y: -1)
            .frame(minWidth: 49, minHeight: 32)
            .background {
              if store.preferences.mode == mode {
                LinearGradient(
                  colors: [
                    Color(red: 0.25, green: 0.35, blue: 0.49),
                    Color(red: 0.45, green: 0.56, blue: 0.71),
                  ], startPoint: .top, endPoint: .bottom)
              }
            }
            .overlay(alignment: .trailing) { Color.black.opacity(0.3).frame(width: 0.5) }
          }.buttonStyle(.plain).accessibilityIdentifier("mode-" + mode.rawValue.lowercased())
            .accessibilityAddTraits(store.preferences.mode == mode ? .isSelected : [])
        }
      }
      .background(
        LinearGradient(
          colors: [
            Color(red: 0.63, green: 0.70, blue: 0.80), Color(red: 0.36, green: 0.47, blue: 0.61),
          ], startPoint: .top, endPoint: .bottom)
      )
      .clipShape(RoundedRectangle(cornerRadius: 5))
      .overlay(RoundedRectangle(cornerRadius: 5).stroke(.black.opacity(0.55), lineWidth: 1))
      Spacer(minLength: 0)
      Button {
        navigate(.inbox)
      } label: {
        ZStack(alignment: .topTrailing) {
          Image(systemName: "tray.fill").font(.system(size: 22)).foregroundStyle(
            Color(red: 0.20, green: 0.31, blue: 0.46)
          )
          .shadow(color: .white.opacity(0.75), radius: 0, y: 1)
          if !store.pendingInvitations.isEmpty {
            Text(String(store.pendingInvitations.count)).font(.system(size: 10, weight: .bold))
              .foregroundStyle(.white)
              .padding(3).background(.red, in: Circle()).offset(x: 6, y: -5)
          }
        }.frame(width: 38, height: 44)
      }.buttonStyle(.plain).accessibilityLabel(L10n.text("Inbox")).accessibilityIdentifier("inbox")
    }.padding(.horizontal, 8).frame(minHeight: 49).background { CalendarMetal() }
  }

  @ViewBuilder private func destination(_ route: CalendarRoute) -> some View {
    switch route {
    case .calendars:
      CalendarsView(store: store, done: { navigate(nil) }, settings: { navigate(.settings) })
    case .settings:
      CalendarSettingsView(store: store, icon: icon, back: { navigate(.calendars) })
    case .inbox:
      CalendarInboxView(store: store, done: { navigate(nil) }, open: open)
    case .detail(let occurrence):
      EventDetailView(
        store: store, occurrence: occurrence, back: { navigate(nil) },
        edit: {
          var draft = occurrence.event
          draft.start = occurrence.start
          draft.end = occurrence.end
          navigate(.editor(draft, occurrence))
        })
    case .editor(let draft, let occurrence):
      EventEditorView(
        store: store, draft: draft, occurrence: occurrence,
        cancel: { navigate(occurrence.map { .detail($0) }) },
        saved: { date in
          selectedDate = date
          navigate(nil)
        })
    }
  }
  private func open(_ occurrence: EventOccurrence) { navigate(.detail(occurrence)) }
  private func create(_ date: Date) {
    var draft = store.draft(on: date)
    draft.start = date
    draft.end = date.addingTimeInterval(3600)
    navigate(.editor(draft, nil))
  }
  private func navigate(_ route: CalendarRoute?) {
    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) { self.route = route }
  }
}

private struct CalendarErrorNotice: Identifiable {
  let message: String
  var id: String { message }
}
