import MediaPlayer
import SwiftUI

struct AlarmListView: View {
  let store: ClockStore
  let editing: Bool
  var onEdit: () -> Void
  var onAdd: () -> Void
  var onOpen: (ClockAlarm) -> Void
  @Environment(\.openURL) private var openURL
  var body: some View {
    VStack(spacing: 0) {
      ClockNavigationBar(
        title: "Alarm", left: editing ? "Done" : "Edit", right: "+", onLeft: onEdit, onRight: onAdd)
      if store.notificationDenied {
        Button {
          if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
        } label: {
          Text(L10n.text("Enable notifications in Settings for background reminders."))
            .font(ClockTheme.font(13)).foregroundStyle(ClockTheme.value).padding(12)
        }.accessibilityIdentifier("notification-settings")
      }
      if store.alarms.isEmpty {
        Text(L10n.text("No Alarms")).font(ClockTheme.font(25, bold: true)).foregroundStyle(
          Color(hex: 0x7A8495)
        )
        .shadow(color: .white, radius: 0, y: 1).frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(store.alarms) { alarm in
              HStack(spacing: 5) {
                if editing {
                  Button {
                    store.removeAlarm(alarm.id)
                  } label: {
                    Image(systemName: "minus.circle.fill").font(.system(size: 25)).foregroundStyle(
                      Color(hex: 0xC42D32))
                  }
                  .frame(width: 44, height: 44).accessibilityLabel(
                    L10n.text("Delete") + " " + alarm.displayLabel
                  )
                  .accessibilityIdentifier("delete-alarm-" + alarm.id.uuidString)
                }
                Button {
                  onOpen(alarm)
                } label: {
                  VStack(alignment: .leading, spacing: 3) {
                    Text(ClockFormat.alarmTime(alarm)).font(ClockTheme.font(43)).foregroundStyle(
                      alarm.enabled ? .black : .gray
                    )
                    .lineLimit(1).minimumScaleFactor(0.65)
                    Text(
                      alarm.displayLabel
                        + (alarm.weekdays.isEmpty ? "" : ", " + alarm.repeatDescription)
                    )
                    .font(ClockTheme.font(14, bold: true)).foregroundStyle(Color(hex: 0x555555))
                    .lineLimit(2)
                  }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("alarm-row-" + alarm.id.uuidString)
                if editing {
                  Image(systemName: "chevron.right").foregroundStyle(.gray)
                } else {
                  Toggle(
                    alarm.displayLabel,
                    isOn: Binding(get: { alarm.enabled }, set: { _ in store.toggleAlarm(alarm.id) })
                  )
                  .labelsHidden().toggleStyle(ClassicToggleStyle(showsLabel: false))
                  .accessibilityIdentifier("alarm-toggle-" + alarm.id.uuidString).frame(width: 80)
                }
              }.padding(.horizontal, 14).padding(.vertical, 12).frame(minHeight: 104)
                .background(ClockTheme.row).overlay(alignment: .bottom) { SilverSeparator() }
            }
          }
        }.accessibilityIdentifier("alarm-list")
      }
    }
  }
}

struct AlarmEditorView: View {
  let store: ClockStore
  let isNew: Bool
  var close: () -> Void
  @State private var alarm: ClockAlarm
  @State private var detail: Detail?
  private enum Detail { case repeatDays, sound, label }
  init(store: ClockStore, initial: ClockAlarm, isNew: Bool, close: @escaping () -> Void) {
    self.store = store
    self.isNew = isNew
    self.close = close
    _alarm = State(initialValue: initial)
  }
  var body: some View {
    ZStack {
      PinstripeBackground()
      if let detail {
        detailView(detail)
      } else {
        VStack(spacing: 0) {
          ClockNavigationBar(
            title: isNew ? "Add Alarm" : "Edit Alarm", left: "Cancel", right: "Save",
            rightBlue: true,
            onLeft: close,
            onRight: {
              alarm.enabled = true
              store.upsert(alarm)
              close()
            })
          GeometryReader { geometry in
            ScrollView {
              VStack(spacing: 16) {
                ClassicGroup {
                  SettingsRow(title: "Repeat", value: alarm.repeatDescription) {
                    detail = .repeatDays
                  }.accessibilityIdentifier("alarm-repeat")
                  SilverSeparator()
                  SettingsRow(
                    title: "Sound", value: alarm.song?.title ?? L10n.text(alarm.sound.rawValue)
                  ) { detail = .sound }.accessibilityIdentifier("alarm-sound")
                  SilverSeparator()
                  Toggle(L10n.text("Snooze"), isOn: $alarm.snooze).toggleStyle(ClassicToggleStyle())
                    .foregroundStyle(.black).padding(.horizontal, 13).frame(minHeight: 48)
                    .accessibilityIdentifier("alarm-snooze")
                  SilverSeparator()
                  SettingsRow(title: "Label", value: alarm.displayLabel) { detail = .label }
                    .accessibilityIdentifier("alarm-label")
                }.padding(.top, 12)
                Spacer(minLength: 0)
                ClassicTimePicker(hour: $alarm.hour, minute: $alarm.minute)
                  .frame(maxWidth: .infinity).padding(.bottom, 8)
              }.frame(minHeight: geometry.size.height)
            }
          }
        }
      }
    }
  }
  @ViewBuilder private func detailView(_ detail: Detail) -> some View {
    switch detail {
    case .repeatDays:
      VStack(spacing: 0) {
        ClockNavigationBar(title: "Repeat", left: "Back", onLeft: { self.detail = nil })
        ScrollView {
          ClassicGroup {
            ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { day in
              Button {
                if alarm.weekdays.contains(day) {
                  alarm.weekdays.remove(day)
                } else {
                  alarm.weekdays.insert(day)
                }
              } label: {
                HStack {
                  Text(ClockFormat.weekday(day)).font(ClockTheme.font(19, bold: true))
                    .foregroundStyle(.black)
                  Spacer()
                  if alarm.weekdays.contains(day) {
                    Image(systemName: "checkmark").foregroundStyle(ClockTheme.value)
                  }
                }.padding(.horizontal, 14).frame(minHeight: 49).contentShape(Rectangle())
              }.buttonStyle(.plain).accessibilityIdentifier("weekday-\(day)")
                .accessibilityAddTraits(alarm.weekdays.contains(day) ? .isSelected : [])
              if day != 1 { SilverSeparator() }
            }
          }.padding(.top, 15)
        }
      }
    case .sound:
      SoundSelectionView(sound: $alarm.sound, timer: false, song: $alarm.song) { self.detail = nil }
    case .label:
      VStack(spacing: 0) {
        ClockNavigationBar(
          title: "Label", left: "Back", right: "Done", rightBlue: true,
          onLeft: { self.detail = nil }, onRight: { self.detail = nil })
        ClassicGroup {
          TextField(L10n.text("Alarm"), text: $alarm.label).font(ClockTheme.font(19))
            .foregroundStyle(.black)
            .padding(14).accessibilityLabel(L10n.text("Label")).accessibilityIdentifier(
              "alarm-label-field"
            )
            .submitLabel(.done).onSubmit { self.detail = nil }
        }.padding(.top, 16)
        Spacer()
      }
    }
  }
}

struct SoundSelectionView: View {
  @Binding var sound: ClockSound
  var timer: Bool
  var song: Binding<AlarmSong?>? = nil
  var close: () -> Void
  @State private var musicPicker: MusicPickerRequest?
  @State private var musicError: String?
  private struct MusicPickerRequest: Identifiable { let id = UUID() }
  var body: some View {
    ZStack {
      PinstripeBackground()
      if musicError == nil {
        VStack(spacing: 0) {
          ClockNavigationBar(
            title: timer ? "When Timer Ends" : "Sound", left: "Back",
            onLeft: {
              ClockAudio.shared.stop()
              close()
            })
          ScrollView {
            if let song {
              Text(L10n.text("Songs")).font(ClockTheme.font(16, bold: true)).foregroundStyle(
                ClockTheme.value
              )
              .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(
                .top, 18)
              ClassicGroup {
                SettingsRow(title: "Pick a song", value: song.wrappedValue?.title ?? "") {
                  chooseSong()
                }
                .accessibilityIdentifier("pick-song")
              }
            }
            ClassicGroup {
              ForEach(timer ? ClockSound.timerSounds : ClockSound.alarmSounds, id: \.self) { item in
                Button {
                  sound = item
                  song?.wrappedValue = nil
                  ClockAudio.shared.play(item)
                } label: {
                  HStack {
                    Text(L10n.text(item.rawValue)).font(ClockTheme.font(18, bold: true))
                      .foregroundStyle(.black)
                    Spacer()
                    if sound == item && song?.wrappedValue == nil {
                      Image(systemName: "checkmark").foregroundStyle(ClockTheme.value)
                    }
                  }.padding(.horizontal, 14).frame(minHeight: 49).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("sound-" + item.rawValue)
                  .accessibilityAddTraits(
                    sound == item && song?.wrappedValue == nil ? .isSelected : [])
                SilverSeparator()
              }
            }.padding(.top, 16)
            if song?.wrappedValue != nil {
              Text(
                L10n.text(
                  "Songs play while Clock is open. Background reminders use the selected built-in tone."
                )
              )
              .font(ClockTheme.font(13)).foregroundStyle(ClockTheme.value).padding(20)
            }
            if timer && sound == .stopPlaying {
              Text(
                L10n.text(
                  "Stop Playing pauses other audio while Clock is open. In the background, the timer delivers a silent notification."
                )
              )
              .font(ClockTheme.font(13)).foregroundStyle(ClockTheme.value).padding(20)
            }
          }
        }
      }
      if let musicError {
        RingingPanel(title: L10n.text("Music Library"), message: musicError, buttonTitle: "OK") {
          self.musicError = nil
        }
      }
    }.onDisappear { ClockAudio.shared.stop() }
      .sheet(item: $musicPicker) { _ in
        MusicLibraryPicker { choice in song?.wrappedValue = choice }
      }
  }
  private func chooseSong() {
    #if targetEnvironment(simulator)
      musicError = L10n.text("Music selection requires a physical iPhone with downloaded songs.")
    #else
      MPMediaLibrary.requestAuthorization { status in
        Task { @MainActor in
          if status == .authorized {
            musicPicker = MusicPickerRequest()
          } else {
            musicError = L10n.text(
              "Music access is unavailable. You can still use the built-in tones.")
          }
        }
      }
    #endif
  }
}
