import SwiftUI

struct ListManager: View {
  @Bindable var store: ReminderStore
  @Binding var showingAccounts: Bool
  let close: () -> Void
  let editList: (ReminderList) -> Void
  let newList: () -> Void
  let openItem: (ReminderItem) -> Void
  @State private var query = ""
  @State private var editing = false
  @State private var deleteTarget: ReminderList?
  @FocusState private var searchFocused: Bool

  var body: some View {
    Group {
      if showingAccounts {
        ReminderAccounts(store: store) { showingAccounts = false }
      } else {
        lists
      }
    }
  }

  private var lists: some View {
    VStack(spacing: 0) {
      ClassicHeader(title: L10n.text("Lists"), darkLeather: true) {
        Button(L10n.text(editing ? "Done" : "Edit")) { editing.toggle() }.buttonStyle(
          ClassicButtonStyle()
        )
        .accessibilityIdentifier("Edit Lists")
      } trailing: {
        Button(L10n.text("Done"), action: close).buttonStyle(ClassicButtonStyle(silver: true))
          .accessibilityIdentifier("Close Lists")
      }
      HStack {
        Image(systemName: "magnifyingglass").foregroundStyle(Color(white: 0.6))
        TextField(L10n.text("Search"), text: $query).font(Classic.font(16)).foregroundStyle(.white)
          .tint(.white).accessibilityIdentifier("Search").focused($searchFocused)
        if !query.isEmpty {
          Button {
            query = ""
          } label: {
            Image(systemName: "xmark.circle.fill").foregroundStyle(.gray)
          }
          .accessibilityLabel(L10n.text("Clear search"))
        }
      }.padding(.horizontal, 11).frame(minHeight: 34)
        .background(Color(white: 0.18), in: Capsule())
        .overlay(Capsule().strokeBorder(.black.opacity(0.5)))
        .shadow(color: .white.opacity(0.08), radius: 0, y: 1)
        .frame(minHeight: 44).contentShape(Rectangle())
        .onTapGesture { searchFocused = true }
        .padding(.horizontal, 10).padding(.top, 2).padding(.bottom, 4)
      RecessedListPanel {
        ScrollView {
          VStack(spacing: 0) {
            if query.isEmpty {
              darkRow("Completed", count: store.items.filter(\.completed).count) {
                store.select(.completed)
                close()
              }
              darkRow(
                "Today",
                count: store.items.filter {
                  !$0.completed && $0.due.map { Calendar.current.isDateInToday($0) } == true
                }.count
              ) {
                store.select(.date(Date()))
                close()
              }
              section("On My iPhone")
              ForEach(store.lists.filter { $0.systemID == nil }) { list in listRow(list) }
              if store.connected {
                section("Accounts")
                ForEach(store.lists.filter { $0.systemID != nil }) { list in listRow(list) }
              }
              darkRow("Create New List…") { newList() }.accessibilityIdentifier("Create New List")
            } else {
              ForEach(store.searchResults(query)) { item in
                Button {
                  searchFocused = false
                  openItem(item)
                } label: {
                  HStack {
                    ClassicCheckbox(checked: item.completed)
                    VStack(alignment: .leading, spacing: 3) {
                      Text(item.title).font(Classic.font(17, bold: true))
                      Text(store.lists.first { $0.id == item.listID }?.displayName() ?? "").font(
                        Classic.font(12)
                      ).foregroundStyle(.gray)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.gray)
                  }.foregroundStyle(Color(white: 0.86)).padding(14).frame(
                    maxWidth: .infinity, alignment: .leading
                  )
                  .contentShape(Rectangle())
                }.accessibilityIdentifier("Search result").overlay(alignment: .bottom) {
                  darkDivider
                }
              }
              if store.searchResults(query).isEmpty {
                Text(L10n.text("No Results")).font(Classic.font(18)).foregroundStyle(.gray).padding(
                  30)
              }
            }
          }
        }.scrollDismissesKeyboard(.interactively)
      }.padding(.horizontal, 10)
      if query.isEmpty {
        HStack {
          Spacer()
          Button {
            searchFocused = false
            showingAccounts = true
          } label: {
            HStack(spacing: 5) {
              Text(L10n.text("Accounts")).font(Classic.font(13, bold: true))
              Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
            }.foregroundStyle(Color(white: 0.68)).shadow(color: .black, radius: 0, y: -1)
              .padding(.horizontal, 13).frame(minWidth: 72, minHeight: 44)
          }.accessibilityIdentifier("Accounts")
        }.padding(.horizontal, 10)
        DateRibbon(selected: Date()) {
          store.select(.date($0))
          close()
        }.padding(.horizontal, 10).padding(.bottom, 8)
      }
    }.disabled(store.loading)
      .overlay {
        if store.loading {
          ProgressView().tint(.white).padding(25).background(
            .black.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
        }
      }
      .alert(
        L10n.text("Delete List?"),
        isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } })
      ) {
        Button(L10n.text("Cancel"), role: .cancel) { deleteTarget = nil }
        Button(L10n.text("Delete"), role: .destructive) {
          if let list = deleteTarget { run { try store.deleteList(list) } }
          deleteTarget = nil
        }
      } message: {
        Text(L10n.text("All reminders in this list will be deleted."))
      }
  }

  private var darkDivider: some View {
    Rectangle().fill(.black.opacity(0.2)).frame(height: 1).shadow(
      color: .white.opacity(0.06), radius: 0, y: 1)
  }
  private func section(_ title: String) -> some View {
    Text(L10n.text(title)).font(Classic.font(12, bold: true)).foregroundStyle(Color(white: 0.65))
      .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).padding(
        .vertical, 6
      ).background {
        LinearGradient(
          colors: [Color(white: 0.29), Color(white: 0.255)], startPoint: .top,
          endPoint: .bottom)
      }
      .shadow(color: .black.opacity(0.45), radius: 0, y: -1)
  }
  private func darkRow(_ title: String, count: Int? = nil, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      HStack {
        Text(L10n.text(title)).font(Classic.font(17, bold: true))
        Spacer()
        if let count {
          Text(count.formatted()).font(Classic.font(15)).foregroundStyle(Color(white: 0.6))
        }
        Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(
          Color(white: 0.4))
      }.foregroundStyle(Color(white: 0.83)).shadow(color: .black.opacity(0.55), radius: 0, y: -1)
        .padding(.horizontal, 15).frame(minHeight: 51)
        .contentShape(Rectangle())
    }.overlay(alignment: .bottom) { darkDivider }
  }
  private func listRow(_ list: ReminderList) -> some View {
    HStack(spacing: 0) {
      if editing && list.writable {
        Button {
          deleteTarget = list
        } label: {
          Image(systemName: "minus.circle.fill").font(.system(size: 22)).foregroundStyle(.red)
            .shadow(color: .white, radius: 0, y: 1)
        }
        .frame(width: 44, height: 51).padding(.leading, 6).accessibilityLabel(
          L10n.format("Delete %@", list.displayName()))
      }
      Button {
        if editing {
          editList(list)
        } else {
          store.select(.list(list.id))
          close()
        }
      } label: {
        HStack(spacing: 10) {
          VStack(alignment: .leading, spacing: 2) {
            Text(list.displayName()).font(Classic.font(17, bold: true))
            if let account = list.account {
              Text(account).font(Classic.font(11)).foregroundStyle(.gray)
            }
          }.frame(maxWidth: .infinity, alignment: .leading)
          Text(store.items.filter { $0.listID == list.id && !$0.completed }.count.formatted())
            .font(Classic.font(15)).foregroundStyle(Color(white: 0.6))
          if editing {
            Image(systemName: "line.3.horizontal").foregroundStyle(Color(white: 0.45))
          } else {
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold))
              .foregroundStyle(Color(white: 0.4))
          }
        }.padding(.leading, editing && list.writable ? 0 : 12).padding(.trailing, 12)
          .frame(maxWidth: .infinity, minHeight: 51).contentShape(Rectangle())
      }.accessibilityIdentifier("list-\(list.displayName())")
        .accessibilityLabel(list.displayName())
        .accessibilityValue(
          store.items.filter { $0.listID == list.id && !$0.completed }.count.formatted())
    }.foregroundStyle(Color(white: 0.83)).overlay(alignment: .bottom) {
      darkDivider
    }
    .draggable(editing ? list.id.uuidString : "")
    .dropDestination(for: String.self) { values, _ in
      guard editing, let id = values.first.flatMap(UUID.init(uuidString:)) else { return false }
      run { try store.reorderLists(id, before: list.id) }
      return true
    }
    .contextMenu {
      if list.writable {
        Button(L10n.text("Rename List")) { editList(list) }
        Button(L10n.text("Delete"), role: .destructive) { deleteTarget = list }
      }
      Button(L10n.text("Move up")) {
        if let index = store.lists.firstIndex(where: { $0.id == list.id }), index > 0 {
          run { try store.reorderLists(list.id, before: store.lists[index - 1].id) }
        }
      }
    }
  }
  private func run(_ operation: () throws -> Void) {
    do { try operation() } catch { store.error = error.localizedDescription }
  }
}

struct ListEditor: View {
  let store: ReminderStore
  let session: ListDraft
  let close: () -> Void
  @State private var name: String
  @State private var inSystem = false
  @State private var error: String?
  @FocusState private var focused: Bool
  init(store: ReminderStore, session: ListDraft, close: @escaping () -> Void) {
    self.store = store
    self.session = session
    self.close = close
    // The route seeds a private editing transaction once, preserving Cancel semantics.
    _name = State(initialValue: session.list.displayName())
  }
  var body: some View {
    VStack(spacing: 0) {
      ClassicHeader(title: L10n.text(session.isNew ? "New List" : "Rename List")) {
        Button(L10n.text("Cancel"), action: close).buttonStyle(ClassicButtonStyle())
      } trailing: {
        Button(L10n.text("Done")) {
          var list = session.list
          list.name = name
          do {
            try store.saveList(list, createInSystem: inSystem)
            close()
          } catch { self.error = error.localizedDescription }
        }.buttonStyle(ClassicButtonStyle(silver: true)).disabled(
          name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !session.list.writable
        )
        .accessibilityIdentifier("Save List")
      }
      PaperCard {
        VStack(alignment: .leading, spacing: 20) {
          DetailGroup {
            TextField(L10n.text("List Name"), text: $name).font(Classic.font(24)).focused($focused)
              .foregroundStyle(Classic.ink).tint(Classic.red).padding(15).accessibilityIdentifier(
                "List Name")
          }
          if session.isNew && store.connected {
            DetailGroup { ClassicToggle(title: "Create in System Reminders", isOn: $inSystem) }
          }
          Text(L10n.text("Choose a name for your list.")).font(Classic.font(14)).foregroundStyle(
            Classic.muted)
          Spacer()
        }.padding(10).frame(maxWidth: .infinity, maxHeight: .infinity)
      }.padding(7)
    }.modifier(ClassicError(error: $error)).onAppear {
      if session.isNew {
        focused = true
        name = ""
      }
    }
    .environment(\.colorScheme, .light)
  }
}
