import SwiftUI

struct CalendarsView: View {
  let store: CalendarStore
  let done: () -> Void
  let settings: () -> Void
  @State private var editing = false
  @State private var selected: CalendarSource?
  var body: some View {
    if let selected {
      CalendarSourceEditor(store: store, source: selected, done: { self.selected = nil })
    } else {
      VStack(spacing: 0) {
        CalendarNavBar(title: L10n.text("Calendars")) {
          Button(L10n.text(editing ? "Done" : "Edit")) { editing.toggle() }
            .buttonStyle(ClassicCalendarButtonStyle()).accessibilityIdentifier("edit-calendars")
        } right: {
          Button(L10n.text("Done"), action: done).buttonStyle(
            ClassicCalendarButtonStyle(primary: true)
          ).accessibilityIdentifier("calendars-done")
        }
        ScrollView {
          VStack(spacing: 23) {
            if !editing {
              CalendarGroup {
                Button {
                  let allShown = store.allCalendars.allSatisfy { store.isVisible($0.id) }
                  store.showAll(!allShown)
                } label: {
                  CalendarRow(
                    title: store.allCalendars.allSatisfy { store.isVisible($0.id) }
                      ? "Hide All Calendars" : "Show All Calendars")
                }.buttonStyle(.plain).accessibilityIdentifier("toggle-all-calendars")
              }
            }
            CalendarGroup(title: "On My iPhone") {
              ForEach(store.calendars) { source in sourceRow(source) }
              if editing {
                Button {
                  selected = CalendarSource(title: "", color: .blue)
                } label: {
                  CalendarRow(title: "Add Calendar", chevron: true)
                }.buttonStyle(.plain).accessibilityIdentifier("add-calendar")
              }
            }
            ForEach(accounts, id: \.self) { account in
              CalendarGroup(title: account) {
                ForEach(store.systemCalendars.filter { $0.account == account }) { source in
                  sourceRow(source)
                }
              }
            }
            CalendarGroup {
              Button(action: settings) { CalendarRow(title: "Settings", chevron: true) }
                .buttonStyle(.plain).accessibilityIdentifier("calendar-settings")
            }
            if !store.preferences.systemEnabled {
              Text(
                L10n.text(
                  "Connect system calendars in Settings to see your iCloud, Exchange, and subscribed calendars."
                )
              )
              .font(.custom("HelveticaNeue", size: 13, relativeTo: .footnote)).foregroundStyle(
                CalendarPalette.ink
              )
              .multilineTextAlignment(.center).padding(.horizontal, 25)
            }
          }.padding(.vertical, 22).frame(maxWidth: 650).frame(maxWidth: .infinity)
        }
      }.accessibilityAction(.escape, done)
    }
  }
  private var accounts: [String] { Array(Set(store.systemCalendars.map(\.account))).sorted() }
  private func sourceRow(_ source: CalendarSource) -> some View {
    Button {
      if editing && !source.system { selected = source } else { store.toggle(source.id) }
    } label: {
      HStack(spacing: 12) {
        Circle().fill(source.color.color).frame(width: 17, height: 17)
          .overlay(Circle().stroke(.black.opacity(0.25), lineWidth: 0.5))
        VStack(alignment: .leading, spacing: 3) {
          Text(source.displayTitle).font(.custom("HelveticaNeue", size: 18, relativeTo: .body))
          if !source.writable {
            Text(L10n.text("Read-only")).font(.custom("HelveticaNeue", size: 12)).foregroundStyle(
              Color(white: 0.55))
          }
        }
        Spacer()
        if editing && !source.system {
          Image(systemName: "chevron.right").foregroundStyle(Color(white: 0.55))
        } else {
          CalendarCheck(checked: store.isVisible(source.id))
        }
      }.foregroundStyle(.black).padding(14).frame(minHeight: 50).contentShape(Rectangle())
        .overlay(alignment: .bottom) { Color(white: 0.85).frame(height: 0.5) }
    }.buttonStyle(.plain).accessibilityIdentifier("calendar-" + source.id)
      .accessibilityLabel(source.displayTitle + ", " + source.color.label)
      .accessibilityAddTraits(store.isVisible(source.id) ? .isSelected : [])
  }
}

struct CalendarSourceEditor: View {
  let store: CalendarStore
  let done: () -> Void
  @State private var source: CalendarSource
  @State private var deleting = false
  @FocusState private var focused: Bool
  init(store: CalendarStore, source: CalendarSource, done: @escaping () -> Void) {
    self.store = store
    self.done = done
    var editing = source
    editing.title = source.displayTitle
    editing.builtIn = false
    _source = State(initialValue: editing)
  }
  private var existing: Bool { store.calendars.contains { $0.id == source.id } }
  var body: some View {
    VStack(spacing: 0) {
      CalendarNavBar(title: L10n.text(existing ? "Edit Calendar" : "Add Calendar")) {
        Button(L10n.text("Cancel"), action: done).buttonStyle(ClassicCalendarButtonStyle())
      } right: {
        Button(L10n.text("Done")) { if store.saveCalendar(source) { done() } }
          .buttonStyle(ClassicCalendarButtonStyle(primary: true)).accessibilityIdentifier(
            "save-calendar"
          )
          .disabled(
            source.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !store.canWrite)
      }
      ScrollView {
        VStack(spacing: 23) {
          CalendarGroup {
            TextField(L10n.text("Calendar Name"), text: $source.title).font(
              .custom("HelveticaNeue", size: 17)
            ).padding(14)
              .focused($focused).accessibilityIdentifier("calendar-name")
          }
          CalendarGroup(title: "Color") {
            ForEach(EventColor.allCases, id: \.self) { color in
              Button {
                source.color = color
                focused = false
              } label: {
                HStack {
                  Circle().fill(color.color).frame(width: 18, height: 18)
                  Text(color.label)
                  Spacer()
                  CalendarCheck(checked: source.color == color)
                }.font(.custom("HelveticaNeue", size: 17)).foregroundStyle(.black).padding(14)
                  .contentShape(Rectangle())
                  .overlay(alignment: .bottom) { Color(white: 0.85).frame(height: 0.5) }
              }.buttonStyle(.plain).accessibilityIdentifier("color-" + color.rawValue)
            }
          }
          if existing && store.calendars.count > 1 {
            Button(L10n.text("Delete Calendar")) {
              focused = false
              deleting = true
            }
            .buttonStyle(ClassicCalendarButtonStyle(destructive: true)).accessibilityIdentifier(
              "delete-calendar")
          }
        }.padding(.vertical, 23).frame(maxWidth: 650).frame(maxWidth: .infinity)
      }.scrollDismissesKeyboard(.interactively)
    }
    .allowsHitTesting(!deleting)
    .accessibilityHidden(deleting)
    .overlay {
      if deleting {
        CalendarActionSheet(
          title: "Delete this calendar and all its events?", options: ["Delete Calendar"],
          cancel: { deleting = false },
          select: { _ in
            deleting = false
            if store.deleteCalendar(source.id) { done() }
          })
      }
    }
  }
}
