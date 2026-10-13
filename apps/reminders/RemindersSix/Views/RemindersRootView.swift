import EventKit
import SwiftUI

struct ReminderDraft: Identifiable {
  let id = UUID()
  var item: ReminderItem
  var isNew: Bool
}
struct ListDraft: Identifiable {
  let id = UUID()
  var list: ReminderList
  var isNew: Bool
}
private struct RowHeightKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct RemindersRootView: View {
  @Bindable var store: ReminderStore
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var managing = false
  @State private var showingAccounts = false
  @State private var editing = false
  @State private var draft: ReminderDraft?
  @State private var listDraft: ListDraft?
  @State private var rowsHeight: CGFloat = 0
  @State private var quickDraft: ReminderItem?
  @State private var quickTitle = ""
  @State private var savingQuick = false
  @FocusState private var quickFocused: Bool

  private var usesPaperSurface: Bool {
    !managing || draft != nil || listDraft != nil || showingAccounts
  }

  var body: some View {
    ZStack {
      LeatherSurface().ignoresSafeArea()
      TopBodySurface(
        paper: usesPaperSurface,
        ruled: !managing && draft == nil && listDraft == nil
      )
      if let draft {
        ReminderEditor(store: store, session: draft) {
          transition {
            if draft.isNew && !store.items.contains(where: { $0.id == draft.item.id }) {
              quickDraft = draft.item
              quickTitle = draft.item.title
              quickFocused = true
            }
            self.draft = nil
          }
        }
        .transition(.move(edge: .trailing))
      } else if let listDraft {
        ListEditor(store: store, session: listDraft) { transition { self.listDraft = nil } }
          .transition(.move(edge: .trailing))
      } else if managing {
        ListManager(
          store: store, showingAccounts: $showingAccounts,
          close: { transition { managing = false } },
          editList: { list in transition { listDraft = ListDraft(list: list, isNew: false) } },
          newList: {
            transition { listDraft = ListDraft(list: ReminderList(name: ""), isNew: true) }
          },
          openItem: { item in
            managing = false
            open(item)
          }
        )
        .transition(.move(edge: .leading))
      } else {
        home
      }
    }
    .preferredColorScheme(usesPaperSurface ? .light : .dark)
    .buttonStyle(.plain)
    .modifier(ClassicError(error: $store.error))
    .task { await store.resume() }
    .onChange(of: scenePhase) { if scenePhase == .active { Task { await store.resume() } } }
    .onChange(of: managing) { if !managing { showingAccounts = false } }
    .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
      if draft == nil && listDraft == nil { Task { await store.refreshSystem() } }
    }
    .accessibilityAction(.escape) {
      if draft != nil {
        draft = nil
      } else if listDraft != nil {
        listDraft = nil
      } else {
        quickDraft = nil
        managing = false
      }
    }
  }

  private var home: some View {
    VStack(spacing: 0) {
      ClassicHeader(title: L10n.text("Reminders")) {
        Button {
          saveQuick {
            transition {
              managing = true
              editing = false
            }
          }
        } label: {
          Image(systemName: "line.3.horizontal").font(.system(size: 20, weight: .bold))
        }.buttonStyle(ClassicButtonStyle()).accessibilityLabel(L10n.text("Lists"))
          .accessibilityIdentifier("Lists")
      } trailing: {
        Button(L10n.text(quickDraft != nil || editing ? "Done" : "Edit")) {
          if quickDraft != nil { saveQuick() } else { editing.toggle() }
        }
        .buttonStyle(ClassicButtonStyle(silver: quickDraft != nil || editing))
        .accessibilityIdentifier(quickDraft != nil ? "Save Reminder" : "Edit")
        .disabled(savingQuick)
      }
      PaperCard {
        VStack(spacing: 0) {
          HStack(spacing: 10) {
            Text(store.pageTitle).font(Classic.font(31)).foregroundStyle(Classic.red)
              .shadow(color: .white, radius: 0, y: 1).lineLimit(2).minimumScaleFactor(0.7)
              .frame(maxWidth: .infinity, alignment: .leading)
              .accessibilityIdentifier("List title")
              .gesture(
                DragGesture(minimumDistance: 30).onEnded { value in
                  if abs(value.translation.width) > 40 && abs(value.translation.height) < 30 {
                    switchList(value.translation.width < 0 ? 1 : -1)
                  }
                }
              )
              .accessibilityAction(named: L10n.text("Next list")) { switchList(1) }
              .accessibilityAction(named: L10n.text("Previous list")) { switchList(-1) }
            if store.page != .completed {
              Button {
                add()
              } label: {
                Image(systemName: "plus").font(.system(size: 20, weight: .bold)).foregroundStyle(
                  Color(white: 0.6)
                )
                .shadow(color: .white, radius: 0, y: 1)
              }.buttonStyle(PaperAddButtonStyle()).accessibilityLabel(
                L10n.text("Add Reminder")
              )
              .accessibilityIdentifier("Add Reminder").disabled(
                store.loading || !store.defaultList.writable)
            }
          }.padding(.horizontal, 12).padding(.vertical, 15)
          DetailLine().padding(.horizontal, 5)
          if store.notificationWarning {
            Button {
              UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
            } label: {
              Text(L10n.text("Enable notifications in Settings for reminder alerts.")).font(
                Classic.font(13)
              ).foregroundStyle(Classic.red)
                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
            }.accessibilityIdentifier("Open Settings")
          }
          GeometryReader { proxy in
            ScrollViewReader { reader in
              ScrollView {
                VStack(spacing: 0) {
                  VStack(spacing: 0) {
                    ForEach(store.visibleItems()) { item in
                      if editing {
                        row(item).draggable(item.id.uuidString)
                          .dropDestination(for: String.self) { values, _ in
                            guard let id = values.first.flatMap(UUID.init(uuidString:)) else {
                              return false
                            }
                            run { try store.reorderItems(id, before: item.id) }
                            return true
                          }
                      } else {
                        row(item)
                      }
                    }
                    if quickDraft != nil { quickEntry.id("quick-entry") }
                    if store.visibleItems().isEmpty && quickDraft == nil {
                      VStack(spacing: 10) {
                        Text(
                          L10n.text(
                            store.page == .completed ? "No Completed Reminders" : "No Reminders")
                        ).font(Classic.font(19, bold: true))
                        Text(
                          L10n.text(
                            store.page == .completed
                              ? "Completed reminders appear here." : "Tap + to add a reminder.")
                        ).font(Classic.font(14))
                      }.foregroundStyle(Classic.muted).multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity).padding(.vertical, 50).padding(.leading, 55)
                        .padding(.trailing, 12)
                        .overlay { MarginRules() }
                    }
                  }.background(
                    GeometryReader { rows in
                      Color.clear.preference(key: RowHeightKey.self, value: rows.size.height)
                    })
                  BlankRules().frame(height: max(0, proxy.size.height - rowsHeight))
                }.frame(minHeight: proxy.size.height, alignment: .top)
              }.scrollDismissesKeyboard(.interactively).accessibilityIdentifier("Reminder paper")
                .onPreferenceChange(RowHeightKey.self) { rowsHeight = $0 }
                .onChange(of: quickDraft?.id) {
                  if quickDraft != nil { reader.scrollTo("quick-entry", anchor: .bottom) }
                }
            }
          }
          if case .date(let date) = store.page {
            DateRibbon(selected: date) { store.select(.date($0)) }
          }
        }
      }.padding(.horizontal, 7).padding(.top, 3).padding(.bottom, 8)
    }
  }
  private func row(_ item: ReminderItem) -> some View {
    ReminderRow(
      item: item, editing: editing, writable: store.writable(item),
      toggle: {
        Task {
          do { try await store.toggle(item) } catch { store.error = error.localizedDescription }
        }
      },
      open: { open(item) }, delete: { run { try store.delete(item) } },
      move: { direction in run { try store.moveItem(item, delta: direction) } })
  }
  private func add() {
    guard quickDraft == nil else {
      quickFocused = true
      return
    }
    var item = ReminderItem(listID: store.defaultList.id, title: "")
    if case .date(let date) = store.page {
      item.due = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: date)
    }
    editing = false
    quickTitle = ""
    quickDraft = item
    quickFocused = true
  }
  private var quickEntry: some View {
    VStack(spacing: 0) {
      HStack(spacing: 0) {
        ClassicCheckbox(checked: false).opacity(0.6).frame(width: 47, height: 52)
          .accessibilityHidden(true)
        TextField(L10n.text("New Reminder"), text: $quickTitle, axis: .vertical)
          .font(Classic.font(18)).foregroundStyle(Classic.ink).tint(Classic.red)
          .padding(.leading, 12).padding(.vertical, 12).focused($quickFocused)
          .accessibilityIdentifier("Reminder title").submitLabel(.done)
          .onSubmit { saveQuick() }.environment(\.colorScheme, .light)
        Button {
          guard var item = quickDraft else { return }
          item.title = quickTitle
          quickFocused = false
          quickDraft = nil
          transition { draft = ReminderDraft(item: item, isNew: true) }
        } label: {
          Image(systemName: "chevron.right").font(.system(size: 16, weight: .bold))
            .foregroundStyle(Color(white: 0.62)).frame(width: 36, height: 50).contentShape(
              Rectangle())
        }.accessibilityLabel(L10n.text("Details")).accessibilityIdentifier("Quick Details")
      }
      DottedRule()
    }.overlay { MarginRules() }
      .accessibilityAction(named: L10n.text("Cancel")) {
        quickDraft = nil
        quickFocused = false
      }
  }
  private func saveQuick(after: @escaping () -> Void = {}) {
    guard var item = quickDraft else {
      after()
      return
    }
    guard !savingQuick else { return }
    item.title = quickTitle
    quickFocused = false
    if item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      quickDraft = nil
      after()
      return
    }
    savingQuick = true
    Task {
      defer { savingQuick = false }
      do {
        try await store.save(item)
        quickDraft = nil
        after()
      } catch { store.error = error.localizedDescription }
    }
  }
  private func open(_ item: ReminderItem) {
    transition { draft = ReminderDraft(item: item, isNew: false) }
  }
  private func switchList(_ direction: Int) {
    guard quickDraft == nil else { return }
    guard let selected = store.selectedList,
      let index = store.lists.firstIndex(where: { $0.id == selected.id })
    else { return }
    let target = index + direction
    guard store.lists.indices.contains(target) else { return }
    transition { store.select(.list(store.lists[target].id)) }
  }
  private func run(_ operation: () throws -> Void) {
    do { try operation() } catch { store.error = error.localizedDescription }
  }
  private func transition(_ change: () -> Void) {
    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.23), change)
  }
}

struct DateRibbon: View {
  let selected: Date
  let choose: (Date) -> Void
  private var days: [Date] {
    (-3...3).compactMap {
      Calendar.current.date(
        byAdding: .day, value: $0, to: Calendar.current.startOfDay(for: selected))
    }
  }
  var body: some View {
    HStack(spacing: 0) {
      ForEach(days, id: \.self) { day in
        Button {
          choose(day)
        } label: {
          VStack(spacing: 2) {
            Text(
              Calendar.current.isDateInToday(day)
                ? L10n.text("Today")
                : day.formatted(.dateTime.weekday(.abbreviated).locale(AppLanguage.current.locale))
            )
            .font(Classic.font(11, bold: true)).lineLimit(1).minimumScaleFactor(0.7)
            Text(
              Calendar.current.component(.day, from: day).formatted(
                .number.locale(AppLanguage.current.locale))
            ).font(
              Classic.font(26, bold: true)
            )
            .lineLimit(1).minimumScaleFactor(0.5)
          }.foregroundStyle(
            Calendar.current.isDate(day, inSameDayAs: selected) ? .white : Color(white: 0.64)
          )
          .shadow(color: .black.opacity(0.8), radius: 0, y: -1)
          .frame(maxWidth: .infinity).frame(height: 64)
          .background {
            LinearGradient(
              colors: Calendar.current.isDate(day, inSameDayAs: selected)
                ? [Color(white: 0.11), Color(white: 0.15)]
                : [Color(white: 0.23), Color(white: 0.18)], startPoint: .top, endPoint: .bottom)
          }
          .overlay(alignment: .leading) {
            Rectangle().fill(.black.opacity(0.30)).frame(width: 0.5)
              .shadow(color: .white.opacity(0.08), radius: 0, x: 1)
          }
          .overlay(alignment: .top) {
            Rectangle().fill(.white.opacity(0.09)).frame(height: 0.5)
          }
        }.accessibilityLabel(
          day.formatted(.dateTime.year().month().day().locale(AppLanguage.current.locale))
        )
        .accessibilityAddTraits(
          Calendar.current.isDate(day, inSameDayAs: selected) ? .isSelected : [])
      }
    }.clipShape(RoundedRectangle(cornerRadius: 4))
      .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.black.opacity(0.55)))
      .shadow(color: .white.opacity(0.08), radius: 0, y: 1)
      .accessibilityIdentifier("Date ribbon")
  }
}
