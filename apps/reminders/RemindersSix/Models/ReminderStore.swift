import Foundation
import Observation

@MainActor @Observable
final class ReminderStore {
  private(set) var lists: [ReminderList] = []
  private(set) var items: [ReminderItem] = []
  var page: ReminderPage
  var error: String?
  var notificationWarning = false
  var loading = false
  private(set) var connected = false
  let isolated: Bool
  @ObservationIgnored private let fileURL: URL?
  @ObservationIgnored private let alerts: ReminderAlerts
  @ObservationIgnored private let system = SystemReminders()
  @ObservationIgnored private var scheduling: Task<Void, Never>?
  @ObservationIgnored private var canWrite = true

  init(
    fileURL: URL? = nil, isolated: Bool = false, demo: Bool = false,
    language: AppLanguage = .current
  ) {
    self.isolated = isolated
    self.fileURL = fileURL ?? (isolated ? nil : Self.defaultURL)
    alerts = ReminderAlerts(disabled: isolated)
    let initial = ReminderList(name: "Reminders", builtIn: true)
    lists = [initial]
    page = .list(initial.id)
    if demo {
      let shopping = ReminderList(name: language == .chinese ? "购物清单" : "Shopping")
      let work = ReminderList(name: language == .chinese ? "工作" : "Work")
      lists += [shopping, work]
      var meeting = ReminderItem(
        listID: initial.id,
        title: language == .chinese ? "准备明天的会议" : "Prepare for tomorrow's meeting")
      meeting.due = Calendar.current.date(
        bySettingHour: 9, minute: 0, second: 0,
        of: Calendar.current.date(byAdding: .day, value: 1, to: Date())!)
      meeting.priority = .high
      meeting.notes = language == .chinese ? "带上笔记本和项目资料" : "Bring the notebook and project notes"
      var reading = ReminderItem(
        listID: initial.id, title: language == .chinese ? "读一本好书" : "Read a good book")
      reading.notes = language == .chinese ? "留一点时间给自己" : "Make a little time for yourself"
      var walk = ReminderItem(
        listID: initial.id, title: language == .chinese ? "出去散步" : "Go for a walk")
      walk.due = Calendar.current.date(bySettingHour: 17, minute: 30, second: 0, of: Date())
      walk.recurrence = .daily
      walk.recurrenceAnchor = walk.due
      var finished = ReminderItem(
        listID: initial.id, title: language == .chinese ? "整理书桌" : "Tidy the desk")
      finished.completedAt = Date()
      items = [
        meeting, reading, walk,
        ReminderItem(
          listID: initial.id, title: language == .chinese ? "给家人打电话" : "Call the family"), finished,
        ReminderItem(
          listID: shopping.id, title: language == .chinese ? "牛奶、鸡蛋和面包" : "Milk, eggs and bread"),
        ReminderItem(listID: work.id, title: language == .chinese ? "整理本周的计划" : "Plan the week"),
      ]
    } else if let url = self.fileURL, FileManager.default.fileExists(atPath: url.path) {
      do {
        let archive = try JSONDecoder().decode(ReminderArchive.self, from: Data(contentsOf: url))
        guard archive.version == 1, !archive.lists.isEmpty,
          Set(archive.lists.map(\.id)).count == archive.lists.count,
          Set(archive.items.map(\.id)).count == archive.items.count,
          archive.items.allSatisfy({ item in archive.lists.contains { $0.id == item.listID } })
        else { throw ReminderFailure.save }
        lists = archive.lists
        items = archive.items
        connected = archive.connected
        page = .list(
          lists.contains { $0.id == archive.selectedList } ? archive.selectedList : lists[0].id)
      } catch {
        self.error = L10n.text("Couldn't read saved reminders. Your file has been preserved.")
        canWrite = false
      }
    }
  }

  static var defaultURL: URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("RemindersSix", isDirectory: true).appendingPathComponent(
        "reminders.json")
  }
  var selectedList: ReminderList? {
    if case .list(let id) = page { return lists.first { $0.id == id } }
    return nil
  }
  var defaultList: ReminderList {
    selectedList ?? lists.first { $0.writable && $0.systemID == nil } ?? lists[0]
  }
  var pageTitle: String {
    switch page {
    case .list: return selectedList?.displayName() ?? L10n.text("Reminders")
    case .completed: return L10n.text("Completed")
    case .date(let date):
      if Calendar.current.isDateInToday(date) { return L10n.text("Today") }
      return date.formatted(.dateTime.month().day().locale(AppLanguage.current.locale))
    }
  }
  func visibleItems(search: String = "") -> [ReminderItem] {
    items.filter { item in
      let matches: Bool
      switch page {
      case .list(let id): matches = item.listID == id
      case .completed: matches = item.completed
      case .date(let date):
        matches = item.due.map { Calendar.current.isDate($0, inSameDayAs: date) } == true
      }
      return matches
        && (search.isEmpty || item.title.localizedStandardContains(search)
          || item.notes.localizedStandardContains(search))
    }
  }
  func searchResults(_ query: String) -> [ReminderItem] {
    guard !query.isEmpty else { return [] }
    return items.filter {
      $0.title.localizedStandardContains(query) || $0.notes.localizedStandardContains(query)
    }
  }
  func writable(_ item: ReminderItem) -> Bool {
    canWrite && !loading && lists.first { $0.id == item.listID }?.writable == true
      && (item.systemID == nil || system.authorized)
  }

  private func persist() throws {
    guard canWrite else { throw ReminderFailure.save }
    guard let fileURL else { return }
    let selected = selectedList?.id ?? lists[0].id
    let archive = ReminderArchive(
      lists: lists, items: items, selectedList: selected, connected: connected)
    do {
      try FileManager.default.createDirectory(
        at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      try JSONEncoder().encode(archive).write(to: fileURL, options: .atomic)
    } catch { throw ReminderFailure.save }
  }
  private func commit(
    lists nextLists: [ReminderList]? = nil, items nextItems: [ReminderItem]? = nil
  ) throws {
    let oldLists = lists
    let oldItems = items
    let oldPage = page
    if let nextLists { lists = nextLists }
    if let nextItems { items = nextItems }
    if case .list(let id) = page, !lists.contains(where: { $0.id == id }) {
      page = .list(lists[0].id)
    }
    do { try persist() } catch {
      lists = oldLists
      items = oldItems
      page = oldPage
      throw error
    }
    schedule()
  }
  func select(_ next: ReminderPage) {
    let old = page
    page = next
    do { try persist() } catch {
      page = old
      self.error = error.localizedDescription
    }
  }

  func save(_ draft: ReminderItem) async throws {
    guard canWrite, !loading else { throw ReminderFailure.save }
    guard let list = lists.first(where: { $0.id == draft.listID }), list.writable else {
      throw ReminderFailure.readOnly
    }
    let original = items.first { $0.id == draft.id }
    if let original, !writable(original) { throw ReminderFailure.readOnly }
    var value = draft
    value.title = value.title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.title.isEmpty else { return }
    if value.due == nil {
      value.recurrence = .never
      value.recurrenceAnchor = nil
    }
    if original?.due != value.due || original?.recurrence != value.recurrence {
      value.recurrenceAnchor = value.due
    }
    if value.complexRecurrence
      && (original?.due != value.due || original?.recurrence != value.recurrence
        || original?.listID != value.listID)
    {
      throw ReminderFailure.unsupportedRepeat
    }
    if let original, (original.systemID != nil) != (list.systemID != nil) {
      // Cross-store moves are explicit copies followed by deletion of the old record.
      value.systemID = nil
    }
    if list.systemID != nil {
      value.systemID = try system.save(
        value, list: list,
        original: original?.systemID != nil && original?.systemID == value.systemID ? original : nil
      )
    }
    if let original, original.systemID != nil, list.systemID == nil { try system.delete(original) }
    var next = items
    if let index = next.firstIndex(where: { $0.id == value.id }) {
      next[index] = value
    } else {
      next.append(value)
    }
    try commit(items: next)
    if value.systemID == nil && (value.due != nil || value.place != nil) {
      notificationWarning = !(try await alerts.requestPermission())
      schedule()
    }
  }

  func toggle(_ item: ReminderItem) async throws {
    guard writable(item) else { throw ReminderFailure.readOnly }
    var changed = item
    changed.completedAt = item.completed ? nil : Date()
    if item.systemID != nil {
      guard let list = lists.first(where: { $0.id == item.listID }) else {
        throw ReminderFailure.missing
      }
      _ = try system.save(changed, list: list, original: item)
    }
    var next = items
    guard let index = next.firstIndex(where: { $0.id == item.id }) else {
      throw ReminderFailure.missing
    }
    next[index] = changed
    if item.systemID == nil {
      if !item.completed, !next.contains(where: { $0.predecessorID == item.id }),
        let due = item.due,
        let following = item.recurrence.next(after: due, anchor: item.recurrenceAnchor ?? due)
      {
        var successor = item
        successor.id = UUID()
        successor.due = following
        successor.predecessorID = item.id
        next.insert(successor, at: index + 1)
      } else if item.completed {
        // Undo a completion without duplicating an untouched generated occurrence.
        next.removeAll { successor in
          guard successor.predecessorID == item.id, !successor.completed,
            let due = item.due,
            let following = item.recurrence.next(after: due, anchor: item.recurrenceAnchor ?? due)
          else { return false }
          var expected = item
          expected.id = successor.id
          expected.completedAt = nil
          expected.due = following
          expected.predecessorID = item.id
          return expected == successor
        }
      }
    }
    try commit(items: next)
    if item.systemID != nil { await refreshSystem() }
  }
  func delete(_ item: ReminderItem) throws {
    guard writable(item) else { throw ReminderFailure.readOnly }
    if item.systemID != nil { try system.delete(item) }
    try commit(items: items.filter { $0.id != item.id })
  }

  func saveList(_ draft: ReminderList, createInSystem: Bool = false) throws {
    guard canWrite, !loading, draft.writable else { throw ReminderFailure.readOnly }
    var value = draft
    value.name = value.name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.name.isEmpty else { return }
    value.builtIn = false
    if value.systemID != nil || createInSystem { value.systemID = try system.saveList(value) }
    var next = lists
    if let index = next.firstIndex(where: { $0.id == value.id }) {
      next[index] = value
    } else {
      next.append(value)
    }
    try commit(lists: next)
    select(.list(value.id))
  }
  func deleteList(_ list: ReminderList) throws {
    guard canWrite, !loading, list.writable else { throw ReminderFailure.readOnly }
    if list.systemID == nil && lists.filter({ $0.systemID == nil }).count <= 1 {
      throw ReminderFailure.lastList
    }
    if list.systemID != nil { try system.deleteList(list) }
    try commit(
      lists: lists.filter { $0.id != list.id }, items: items.filter { $0.listID != list.id })
  }
  func reorderItems(_ source: UUID, before target: UUID) throws {
    guard source != target, let from = items.firstIndex(where: { $0.id == source }),
      let targetItem = items.first(where: { $0.id == target }),
      items[from].listID == targetItem.listID
    else { return }
    var next = items
    let moving = next.remove(at: from)
    guard let to = next.firstIndex(where: { $0.id == target }) else { return }
    next.insert(moving, at: to)
    try commit(items: next)
  }
  func moveItem(_ item: ReminderItem, delta: Int) throws {
    let visible = visibleItems()
    guard let index = visible.firstIndex(where: { $0.id == item.id }),
      visible.indices.contains(index + delta)
    else { return }
    var next = items
    guard let a = next.firstIndex(where: { $0.id == item.id }),
      let b = next.firstIndex(where: { $0.id == visible[index + delta].id })
    else { return }
    next.swapAt(a, b)
    try commit(items: next)
  }
  func reorderLists(_ source: UUID, before target: UUID) throws {
    guard source != target, let from = lists.firstIndex(where: { $0.id == source }) else { return }
    var next = lists
    let moving = next.remove(at: from)
    guard let to = next.firstIndex(where: { $0.id == target }) else { return }
    next.insert(moving, at: to)
    try commit(lists: next)
  }

  func connectSystem() async throws {
    guard !isolated else { throw ReminderFailure.permission }
    guard try await system.requestAccess() else { throw ReminderFailure.permission }
    connected = true
    await refreshSystem()
    try persist()
  }
  func disconnectSystem() throws {
    let old = connected
    connected = false
    do {
      try commit(
        lists: lists.filter { $0.systemID == nil }, items: items.filter { $0.systemID == nil })
    } catch {
      connected = old
      throw error
    }
  }
  func refreshSystem() async {
    guard connected, !loading else { return }
    loading = true
    defer { loading = false }
    guard system.authorized else {
      error = ReminderFailure.permission.localizedDescription
      return
    }
    let loaded = await system.load(existingLists: lists, existingItems: items)
    do {
      try commit(
        lists: lists.filter { $0.systemID == nil } + loaded.lists,
        items: items.filter { $0.systemID == nil } + loaded.items)
    } catch { self.error = error.localizedDescription }
  }
  func resume() async {
    await refreshSystem()
    let denied = await alerts.permissionDenied()
    notificationWarning =
      items.contains { $0.systemID == nil && !$0.completed && ($0.due != nil || $0.place != nil) }
      && denied
    schedule()
  }
  private func schedule() {
    let previous = scheduling
    previous?.cancel()
    let snapshot = items
    scheduling = Task { [weak self] in
      // Wait for an old request to finish before replacing the schedule.
      await previous?.value
      guard !Task.isCancelled, let self else { return }
      do { try await self.alerts.reconcile(snapshot) } catch is CancellationError {} catch {
        self.error = error.localizedDescription
      }
    }
  }
}
