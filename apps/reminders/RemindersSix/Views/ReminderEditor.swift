import CoreLocation
import SwiftUI

private enum EditorPage { case details, repeatRule, priority, list, notes, location }

struct ReminderEditor: View {
  let store: ReminderStore
  let session: ReminderDraft
  let close: () -> Void
  @State private var draft: ReminderItem
  @State private var route: EditorPage = .details
  @State private var dateEnabled: Bool
  @State private var locationEnabled: Bool
  @State private var date: Date
  @State private var showWheel = false
  @State private var saving = false
  @State private var deleteConfirmation = false
  @State private var error: String?
  @State private var location = ReminderLocation()
  @FocusState private var titleFocused: Bool

  init(store: ReminderStore, session: ReminderDraft, close: @escaping () -> Void) {
    self.store = store
    self.session = session
    self.close = close
    // A draft is a one-time transaction seed, so Cancel never changes the store.
    _draft = State(initialValue: session.item)
    _dateEnabled = State(initialValue: session.item.due != nil)
    _locationEnabled = State(initialValue: session.item.place != nil)
    _date = State(initialValue: session.item.due ?? Date().addingTimeInterval(3600))
  }
  private var editable: Bool { session.isNew || store.writable(session.item) }
  private var routeTitle: String {
    switch route {
    case .details: "Details"
    case .repeatRule: "Repeat"
    case .priority: "Priority"
    case .list: "List"
    case .notes: "Notes"
    case .location: "Location"
    }
  }
  var body: some View {
    VStack(spacing: 0) {
      ClassicHeader(title: L10n.text(routeTitle)) {
        Button(L10n.text(route == .details ? "Cancel" : "Back")) {
          if route == .details {
            close()
          } else {
            route = .details
            if draft.place == nil { locationEnabled = false }
          }
        }.buttonStyle(ClassicButtonStyle()).accessibilityIdentifier(
          route == .details ? "Cancel Details" : "Back")
      } trailing: {
        if route == .details {
          Button(L10n.text("Done")) { save() }.buttonStyle(ClassicButtonStyle(silver: true))
            .disabled(
              saving || !editable
                || draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || (locationEnabled && draft.place == nil)
            )
            .accessibilityIdentifier("Save Reminder")
        } else {
          Button(L10n.text("Done")) {
            route = .details
            if draft.place == nil { locationEnabled = false }
          }.buttonStyle(ClassicButtonStyle(silver: true))
        }
      }
      PaperCard {
        Group {
          switch route {
          case .details: details
          case .repeatRule: repeatSelection
          case .priority: prioritySelection
          case .list: listSelection
          case .notes: notesEditor
          case .location:
            PlacePicker(location: location, isolated: store.isolated) { place in
              draft.place = place
              locationEnabled = true
              route = .details
            }
          }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
      }.padding(.horizontal, 7).padding(.top, 3).padding(.bottom, 8)
    }.modifier(ClassicError(error: $error))
      .environment(\.colorScheme, .light)
      .overlay {
        if saving {
          ProgressView().tint(Classic.ink).padding(25).background(
            Classic.paper, in: RoundedRectangle(cornerRadius: 8))
        }
      }
      .alert(L10n.text("Delete Reminder?"), isPresented: $deleteConfirmation) {
        Button(L10n.text("Cancel"), role: .cancel) {}
        Button(L10n.text("Delete"), role: .destructive) {
          do {
            try store.delete(session.item)
            close()
          } catch { self.error = error.localizedDescription }
        }
      }
      .onAppear { if session.isNew { titleFocused = true } }
  }

  private var details: some View {
    ScrollView {
      VStack(spacing: 12) {
        DetailGroup {
          TextField(L10n.text("Reminder"), text: $draft.title, axis: .vertical)
            .font(Classic.font(22)).foregroundStyle(Classic.ink).tint(Classic.red)
            .padding(12).frame(minHeight: 56).focused($titleFocused)
            .accessibilityIdentifier("Reminder title").disabled(!editable)
        }
        DetailGroup {
          ClassicToggle(title: "Remind Me On a Day", isOn: $dateEnabled).disabled(
            !editable || draft.complexRecurrence)
          if dateEnabled {
            DetailLine()
            Button {
              titleFocused = false
              showWheel.toggle()
            } label: {
              HStack {
                Text(
                  date.formatted(
                    .dateTime.weekday(.wide).year().month().day().hour().minute().locale(
                      AppLanguage.current.locale))
                )
                .font(Classic.font(17)).multilineTextAlignment(.leading)
                Spacer(minLength: 5)
                Image(systemName: showWheel ? "chevron.up" : "chevron.down").foregroundStyle(
                  Classic.muted
                ).font(.system(size: 12, weight: .bold))
              }.padding(12).frame(minHeight: 50)
            }.accessibilityIdentifier("Due date").disabled(!editable || draft.complexRecurrence)
            if showWheel {
              ClassicDateWheel(date: $date)
            }
            DetailLine()
            DetailRow(
              title: "Repeat", value: L10n.text(draft.recurrence.rawValue),
              action: {
                titleFocused = false
                route = .repeatRule
              }
            )
            .disabled(!editable || draft.complexRecurrence)
          }
        }
        if draft.complexRecurrence {
          Text(
            L10n.text(
              "This system reminder has an advanced repeat rule. Edit its date and repeat in Apple's Reminders."
            )
          ).font(Classic.font(12)).foregroundStyle(Classic.muted).padding(.horizontal, 6)
        }
        DetailGroup {
          ClassicToggle(title: "Remind Me At a Location", isOn: $locationEnabled).disabled(
            !editable)
          if locationEnabled {
            DetailLine()
            DetailRow(
              title: "Location", value: draft.place?.name ?? L10n.text("Choose a Location"),
              action: {
                titleFocused = false
                route = .location
              })
            if draft.place != nil {
              DetailLine()
              HStack(spacing: 0) {
                arrivalChoice(true)
                arrivalChoice(false)
              }.padding(8)
            }
            if location.permission == .denied || location.permission == .restricted {
              Text(L10n.text("Enable location access in Settings for location alerts.")).font(
                Classic.font(12)
              ).foregroundStyle(Classic.red).padding(10)
              Button(L10n.text("Open Settings")) {
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
              }.font(Classic.font(14, bold: true)).padding(10)
            }
          }
        }
        DetailGroup {
          DetailRow(
            title: "Priority", value: L10n.text(draft.priority.title),
            action: {
              titleFocused = false
              route = .priority
            }
          ).disabled(!editable)
        }
        DetailGroup {
          DetailRow(
            title: "List", value: store.lists.first { $0.id == draft.listID }?.displayName() ?? "",
            action: {
              titleFocused = false
              route = .list
            }
          ).disabled(!editable || draft.complexRecurrence)
        }
        DetailGroup {
          DetailRow(
            title: "Notes", value: draft.notes.isEmpty ? "" : draft.notes,
            action: {
              titleFocused = false
              route = .notes
            })
        }
        if !session.isNew && editable {
          Button(L10n.text("Delete")) {
            titleFocused = false
            deleteConfirmation = true
          }
          .font(Classic.font(20)).foregroundStyle(Classic.red).frame(maxWidth: .infinity).frame(
            height: 50
          )
          .background(Classic.red.opacity(0.05)).overlay(
            Rectangle().strokeBorder(.gray.opacity(0.25))
          )
          .accessibilityIdentifier("Delete Reminder")
        }
      }.padding(10).padding(.bottom, 10)
    }.scrollDismissesKeyboard(.interactively)
      .onChange(of: dateEnabled) {
        if !dateEnabled {
          draft.recurrence = .never
          showWheel = false
        }
      }
      .onChange(of: locationEnabled) {
        if locationEnabled {
          if !store.isolated { location.requestPermission() }
          if draft.place == nil {
            titleFocused = false
            route = .location
          }
        }
      }
  }
  private func arrivalChoice(_ arrival: Bool) -> some View {
    Button {
      draft.place?.onArrival = arrival
    } label: {
      Text(L10n.text(arrival ? "When I Arrive" : "When I Leave")).font(Classic.font(14, bold: true))
        .foregroundStyle(draft.place?.onArrival == arrival ? .white : Classic.ink)
        .frame(maxWidth: .infinity).frame(minHeight: 40)
        .background(
          LinearGradient(
            colors: draft.place?.onArrival == arrival
              ? [Color(white: 0.36), Color(white: 0.22)] : [.white, Color(white: 0.79)],
            startPoint: .top, endPoint: .bottom)
        )
        .overlay(Rectangle().strokeBorder(.gray.opacity(0.4)))
    }.accessibilityAddTraits(draft.place?.onArrival == arrival ? .isSelected : []).disabled(
      !editable)
  }
  private var repeatSelection: some View {
    ScrollView {
      VStack(spacing: 0) {
        ForEach(RepeatRule.allCases) { rule in
          selectionRow(L10n.text(rule.rawValue), selected: draft.recurrence == rule) {
            draft.recurrence = rule
            route = .details
          }
        }
      }.padding(10)
    }
  }
  private var prioritySelection: some View {
    ScrollView {
      VStack(spacing: 0) {
        ForEach(ReminderPriority.allCases) { priority in
          selectionRow(L10n.text(priority.title), selected: draft.priority == priority) {
            draft.priority = priority
            route = .details
          }
        }
      }.padding(10)
    }
  }
  private var listSelection: some View {
    ScrollView {
      VStack(spacing: 0) {
        ForEach(store.lists.filter(\.writable)) { list in
          selectionRow(list.displayName(), selected: draft.listID == list.id) {
            draft.listID = list.id
            route = .details
          }
        }
      }.padding(10)
    }
  }
  private func selectionRow(_ title: String, selected: Bool, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      HStack {
        Text(title).font(Classic.font(18))
        Spacer()
        if selected {
          Image(systemName: "checkmark").foregroundStyle(Color(red: 0.25, green: 0.35, blue: 0.5))
            .font(.system(size: 17, weight: .bold))
        }
      }.padding(14).frame(minHeight: 50).contentShape(Rectangle()).overlay(alignment: .bottom) {
        DetailLine()
      }
    }.accessibilityAddTraits(selected ? .isSelected : [])
  }
  private var notesEditor: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(L10n.text("Notes")).font(Classic.font(14, bold: true)).foregroundStyle(Classic.muted)
      TextEditor(text: $draft.notes).font(Classic.font(18)).foregroundStyle(Classic.ink).tint(
        Classic.red
      )
      .scrollContentBackground(.hidden).padding(8).overlay(
        Rectangle().strokeBorder(.gray.opacity(0.3))
      )
      .accessibilityIdentifier("Reminder notes").disabled(!editable)
    }.padding(12)
  }
  private func save() {
    titleFocused = false
    var value = draft
    value.due = dateEnabled ? date : nil
    if !locationEnabled { value.place = nil }
    saving = true
    Task {
      defer { saving = false }
      do {
        try await store.save(value)
        close()
      } catch { self.error = error.localizedDescription }
    }
  }
}

struct PlacePicker: View {
  @Bindable var location: ReminderLocation
  let isolated: Bool
  let choose: (ReminderPlace) -> Void
  @State private var address = ""
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        DetailGroup {
          HStack {
            TextField(L10n.text("Enter an Address"), text: $address).font(Classic.font(17)).tint(
              Classic.red
            )
            .submitLabel(.search).onSubmit { Task { await location.searchAddress(address) } }
            .accessibilityIdentifier("Location address")
            Button(L10n.text("Search")) { Task { await location.searchAddress(address) } }.font(
              Classic.font(14, bold: true)
            )
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityIdentifier("Search Address")
          }.padding(.horizontal, 12)
        }
        DetailGroup {
          DetailRow(title: "Current Location", action: { location.requestCurrentLocation() })
        }
        if location.searching {
          ProgressView().tint(Classic.ink).frame(maxWidth: .infinity).padding()
        }
        if let error = location.error {
          Text(error).font(Classic.font(14)).foregroundStyle(Classic.red)
          if location.permission == .denied || location.permission == .restricted {
            Button(L10n.text("Open Settings")) {
              UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
            }.font(Classic.font(16, bold: true)).frame(minHeight: 44)
          }
        }
        ForEach(location.results) { result in
          Button {
            choose(result.place)
          } label: {
            VStack(alignment: .leading, spacing: 4) {
              Text(result.place.name).font(Classic.font(18))
              Text(result.address).font(Classic.font(13)).foregroundStyle(Classic.muted)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(12).overlay(
              alignment: .bottom
            ) { DetailLine() }.contentShape(Rectangle())
          }.accessibilityIdentifier("Place result")
        }
        Text(L10n.text("You will be reminded when you arrive at or leave the selected place."))
          .font(Classic.font(13)).foregroundStyle(Classic.muted)
        if isolated {
          Text(L10n.text("Preview data is separate from your saved reminders.")).font(
            Classic.font(12)
          ).foregroundStyle(Classic.muted)
        }
      }.padding(12)
    }.onChange(of: location.currentPlace) {
      if let place = location.currentPlace {
        choose(place)
        location.currentPlace = nil
      }
    }
  }
}
