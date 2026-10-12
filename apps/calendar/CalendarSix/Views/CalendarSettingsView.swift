import SwiftUI
import UIKit

struct CalendarSettingsView: View {
  let store: CalendarStore
  let icon: CalendarIconController
  let back: () -> Void
  @State private var selectingDefault = false
  @Environment(\.openURL) private var openURL
  var body: some View {
    VStack(spacing: 0) {
      CalendarNavBar(title: L10n.text(selectingDefault ? "Default Calendar" : "Settings")) {
        Button(L10n.text("Back")) {
          if selectingDefault { selectingDefault = false } else { back() }
        }
        .buttonStyle(ClassicCalendarButtonStyle()).accessibilityIdentifier("settings-back")
      } right: {
        EmptyView()
      }
      ScrollView {
        VStack(spacing: 23) {
          if selectingDefault {
            CalendarGroup {
              ForEach(store.writableCalendars) { source in
                Button {
                  store.preferences.defaultCalendarID = source.id
                  store.persist()
                  selectingDefault = false
                } label: {
                  HStack {
                    Circle().fill(source.color.color).frame(width: 12, height: 12)
                    Text(source.displayTitle)
                    Spacer()
                    CalendarCheck(checked: store.defaultCalendar.id == source.id)
                  }.font(.custom("HelveticaNeue", size: 17)).foregroundStyle(.black).padding(14)
                    .contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("default-" + source.id)
              }
            }
          } else {
            CalendarGroup(title: "Calendars") {
              Button {
                selectingDefault = true
              } label: {
                CalendarRow(
                  title: "Default Calendar", value: store.defaultCalendar.displayTitle,
                  chevron: true)
              }.buttonStyle(.plain).accessibilityIdentifier("default-calendar")
              HStack {
                Text(L10n.text("Start Week on Monday")).font(
                  .custom("HelveticaNeue", size: 17, relativeTo: .body))
                Spacer()
                CalendarSwitch(
                  isOn: Binding(
                    get: { store.preferences.mondayFirst },
                    set: {
                      store.preferences.mondayFirst = $0
                      store.persist()
                    }), label: "Start Week on Monday"
                ).accessibilityIdentifier("monday-first")
              }.padding(13)
            }
            CalendarGroup(title: "Home Screen Icon") {
              HStack {
                Text(L10n.text("Dynamic Date Icon")).font(
                  .custom("HelveticaNeue", size: 17, relativeTo: .body))
                Spacer()
                CalendarSwitch(
                  isOn: Binding(
                    get: { icon.enabled },
                    set: { value in Task { await icon.setEnabled(value) } }),
                  label: "Dynamic Date Icon"
                ).disabled(icon.updating || icon.isolated || !icon.supported)
                  .accessibilityIdentifier("dynamic-date-icon")
              }.padding(13)
              CalendarRow(title: "Current Icon", value: icon.currentLabel)
                .accessibilityIdentifier("current-calendar-icon")
              Button {
                Task { await icon.refresh() }
              } label: {
                CalendarRow(title: "Update Icon Now", chevron: true)
              }.buttonStyle(.plain).disabled(icon.updating || icon.isolated || !icon.supported)
                .accessibilityIdentifier("update-calendar-icon")
            }
            Text(
              L10n.text(
                icon.isolated
                  ? "Icon updates are disabled in the isolated demo."
                  : "The icon updates when Calendar opens or returns to the foreground. iOS displays a notice when the icon changes. It cannot refresh while the app is closed."
              )
            ).font(.custom("HelveticaNeue", size: 13, relativeTo: .footnote))
              .foregroundStyle(CalendarPalette.ink).multilineTextAlignment(.center)
              .padding(.horizontal, 24)
            if let error = icon.error {
              Text(L10n.text(error)).font(.custom("HelveticaNeue", size: 13, relativeTo: .footnote))
                .foregroundStyle(.red).multilineTextAlignment(.center).padding(.horizontal, 24)
            }
            CalendarGroup(title: "System Calendars") {
              CalendarRow(
                title: "Access",
                value: L10n.text(store.preferences.systemEnabled ? "Connected" : "Not Connected"))
              Button {
                if store.preferences.systemEnabled {
                  store.disconnectSystem()
                } else {
                  Task { await store.connectSystem() }
                }
              } label: {
                CalendarRow(
                  title: store.connecting
                    ? "Connecting…"
                    : store.preferences.systemEnabled
                      ? "Disconnect System Calendars" : "Connect System Calendars", chevron: true)
              }.buttonStyle(.plain).disabled(store.connecting).accessibilityIdentifier(
                "connect-system-calendars")
            }
            Text(
              L10n.text(
                "Only calendars already configured on this iPhone appear here. Manage accounts and subscriptions in system Settings. Your local calendars remain on this device."
              )
            )
            .font(.custom("HelveticaNeue", size: 13, relativeTo: .footnote)).foregroundStyle(
              CalendarPalette.ink
            )
            .multilineTextAlignment(.center).padding(.horizontal, 24)
            CalendarGroup(title: "Event Reminders") {
              CalendarRow(title: "Notifications", value: L10n.text(store.notificationStatus))
              Button {
                Task { await store.enableReminders() }
              } label: {
                CalendarRow(title: "Enable Reminders", chevron: true)
              }.buttonStyle(.plain).accessibilityIdentifier("enable-reminders")
            }
            Text(
              L10n.text(
                "The next 60 local alerts are scheduled. Open Calendar periodically to refresh future reminders. System calendars manage their own alerts."
              )
            )
            .font(.custom("HelveticaNeue", size: 13, relativeTo: .footnote)).foregroundStyle(
              CalendarPalette.ink
            )
            .multilineTextAlignment(.center).padding(.horizontal, 24)
            CalendarGroup(title: "Language") {
              CalendarRow(
                title: "App Language", value: AppLanguage.current == .chinese ? "简体中文" : "English")
              Button {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
              } label: {
                CalendarRow(title: "Open Settings", chevron: true)
              }.buttonStyle(.plain).accessibilityIdentifier("open-settings")
            }
            Text(
              L10n.text(
                "Calendar follows your system or per-app language, just like Weather. English and Simplified Chinese are supported."
              )
            )
            .font(.custom("HelveticaNeue", size: 13, relativeTo: .footnote)).foregroundStyle(
              CalendarPalette.ink
            )
            .multilineTextAlignment(.center).padding(.horizontal, 24)
          }
        }.padding(.vertical, 23).frame(maxWidth: 650).frame(maxWidth: .infinity)
      }
    }.accessibilityAction(.escape, back)
  }
}

struct CalendarInboxView: View {
  let store: CalendarStore
  let done: () -> Void
  let open: (EventOccurrence) -> Void
  var body: some View {
    VStack(spacing: 0) {
      CalendarNavBar(title: L10n.text("Invitations")) {
        EmptyView()
      } right: {
        Button(L10n.text("Done"), action: done).buttonStyle(
          ClassicCalendarButtonStyle(primary: true)
        ).accessibilityIdentifier("inbox-done")
      }
      if store.pendingInvitations.isEmpty {
        CalendarEmpty(
          title: "No Invitations",
          subtitle: store.preferences.systemEnabled
            ? "Pending invitations from connected calendars appear here."
            : "Connect system calendars in Settings to view pending invitations.")
      } else {
        ScrollView {
          VStack(spacing: 20) {
            CalendarGroup {
              ForEach(store.pendingInvitations) { event in
                CalendarEventRow(
                  occurrence: EventOccurrence(event: event, start: event.start, end: event.end),
                  source: store.source(event.calendarID)
                ) {
                  open(EventOccurrence(event: event, start: event.start, end: event.end))
                }
              }
            }
            Text(
              L10n.text(
                "Open an invitation in System Calendar to accept, decline, or reply. EventKit does not allow this app to send invitation responses."
              )
            )
            .font(.custom("HelveticaNeue", size: 14, relativeTo: .footnote)).foregroundStyle(
              CalendarPalette.ink
            )
            .multilineTextAlignment(.center).padding(.horizontal, 24)
          }.padding(.vertical, 23)
        }
      }
    }.accessibilityAction(.escape, done)
  }
}
