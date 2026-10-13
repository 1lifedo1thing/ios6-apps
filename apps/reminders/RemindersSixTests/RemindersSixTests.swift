import CoreLocation
import UserNotifications
import XCTest

@testable import RemindersSix

@MainActor
final class RemindersSixTests: XCTestCase {
  private func temporaryFile() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      .appendingPathComponent("reminders.json")
  }
  func testWeatherLanguageSelectionAndLocalization() {
    for code in ["zh", "zh-Hant", "zh-TW", "zh-HK", "zh-Hans-CN"] {
      XCTAssertEqual(AppLanguage.preferred([code]), .chinese)
    }
    for codes in [[], ["fr-FR"], ["en-GB", "zh-Hans"], ["de", "zh"]] {
      XCTAssertEqual(AppLanguage.preferred(codes), .english)
    }
    XCTAssertEqual(L10n.text("Reminders", language: .chinese), "提醒事项")
    XCTAssertEqual(L10n.format("Complete %@", "My task", language: .chinese), "将My task标记为已完成")
  }
  func testPersistenceAndUserTextSurviveLanguageChanges() async throws {
    let file = temporaryFile()
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let store = ReminderStore(fileURL: file, isolated: true)
    let list = ReminderList(name: "My 中文 list")
    try store.saveList(list)
    var item = ReminderItem(listID: list.id, title: "English and 中文")
    item.notes = "A user's own words"
    item.priority = .high
    item.due = Date().addingTimeInterval(3600)
    item.recurrence = .weekly
    try await store.save(item)
    let loaded = ReminderStore(fileURL: file, isolated: true, language: .chinese)
    XCTAssertEqual(loaded.lists.last?.displayName(language: .chinese), list.name)
    XCTAssertEqual(loaded.items.first?.title, item.title)
    XCTAssertEqual(loaded.items.first?.notes, item.notes)
    XCTAssertEqual(loaded.items.first?.recurrence, .weekly)
    XCTAssertEqual(loaded.items.first?.priority, .high)
    XCTAssertEqual(loaded.selectedList?.id, list.id)
  }
  func testCompletionCreatesNextOccurrenceAndUndoRemovesUntouchedSuccessor() async throws {
    let store = ReminderStore(isolated: true)
    var item = ReminderItem(listID: store.defaultList.id, title: "Weekly task")
    item.due = Date().addingTimeInterval(3600)
    item.recurrence = .weekly
    try await store.save(item)
    try await store.toggle(store.items[0])
    XCTAssertEqual(store.items.count, 2)
    XCTAssertTrue(store.items[0].completed)
    XCTAssertEqual(store.visibleItems().map(\.id), store.items.map(\.id))
    XCTAssertEqual(store.items[1].predecessorID, item.id)
    XCTAssertEqual(
      store.items[1].due, Calendar.current.date(byAdding: .day, value: 7, to: item.due!))
    try await store.toggle(store.items[0])
    XCTAssertEqual(store.items.count, 1)
    XCTAssertFalse(store.items[0].completed)
    XCTAssertEqual(store.visibleItems().map(\.id), [item.id])
  }
  func testUndoKeepsEditedSuccessorAndRecompletionDoesNotDuplicateIt() async throws {
    let store = ReminderStore(isolated: true)
    var item = ReminderItem(listID: store.defaultList.id, title: "Original")
    item.due = Date().addingTimeInterval(3600)
    item.recurrence = .daily
    try await store.save(item)
    try await store.toggle(store.items[0])
    var successor = store.items[1]
    successor.title = "Edited next task"
    try await store.save(successor)
    try await store.toggle(store.items[0])
    XCTAssertEqual(store.items.count, 2)
    XCTAssertEqual(store.items[1].title, successor.title)
    try await store.toggle(store.items[0])
    XCTAssertEqual(store.items.count, 2)
  }
  func testMonthEndAndLeapYearRepeatAnchor() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let jan = calendar.date(from: DateComponents(year: 2027, month: 1, day: 31, hour: 9))!
    let feb = try XCTUnwrap(RepeatRule.monthly.next(after: jan, anchor: jan, calendar: calendar))
    let mar = try XCTUnwrap(RepeatRule.monthly.next(after: feb, anchor: jan, calendar: calendar))
    XCTAssertEqual(calendar.component(.day, from: feb), 28)
    XCTAssertEqual(calendar.component(.day, from: mar), 31)
    let leap = calendar.date(from: DateComponents(year: 2028, month: 2, day: 29, hour: 9))!
    var next = leap
    for _ in 0..<4 {
      next = try XCTUnwrap(RepeatRule.yearly.next(after: next, anchor: leap, calendar: calendar))
    }
    XCTAssertEqual(calendar.component(.year, from: next), 2032)
    XCTAssertEqual(calendar.component(.day, from: next), 29)
  }
  func testSearchCompletedDateAndListFiltering() async throws {
    let store = ReminderStore(isolated: true)
    var item = ReminderItem(listID: store.defaultList.id, title: "Book")
    item.notes = "Hidden keyword"
    item.due = Date()
    try await store.save(item)
    let other = ReminderList(name: "Other")
    try store.saveList(other)
    var unrelated = ReminderItem(listID: other.id, title: "Other completed task")
    unrelated.completedAt = Date()
    try await store.save(unrelated)
    XCTAssertEqual(store.searchResults("keyword").map(\.id), [item.id])
    store.select(.date(Date()))
    XCTAssertEqual(store.visibleItems().count, 1)
    try await store.toggle(store.items[0])
    XCTAssertEqual(store.visibleItems().map(\.id), [item.id])
    XCTAssertTrue(store.visibleItems()[0].completed)
    store.select(.list(item.listID))
    XCTAssertEqual(store.visibleItems().map(\.id), [item.id])
    XCTAssertEqual(store.visibleItems(search: "keyword").map(\.id), [item.id])
    XCTAssertTrue(store.visibleItems(search: "absent").isEmpty)
    store.select(.completed)
    XCTAssertEqual(Set(store.visibleItems().map(\.id)), [item.id, unrelated.id])
    try await store.toggle(store.items[0])
    XCTAssertEqual(store.visibleItems().map(\.id), [unrelated.id])
    store.select(.list(item.listID))
    XCTAssertEqual(store.visibleItems().map(\.id), [item.id])
    XCTAssertFalse(store.visibleItems()[0].completed)
  }
  func testListDeletionLastListProtectionAndStableReordering() async throws {
    let store = ReminderStore(isolated: true)
    let original = store.defaultList
    XCTAssertThrowsError(try store.deleteList(original))
    let second = ReminderList(name: "Shopping")
    try store.saveList(second)
    let a = ReminderItem(listID: second.id, title: "A")
    let b = ReminderItem(listID: second.id, title: "B")
    try await store.save(a)
    try await store.save(b)
    try store.reorderItems(b.id, before: a.id)
    XCTAssertEqual(store.visibleItems().map(\.id), [b.id, a.id])
    try store.reorderLists(second.id, before: original.id)
    XCTAssertEqual(store.lists.first?.id, second.id)
    try store.deleteList(second)
    XCTAssertEqual(store.items.count, 0)
    XCTAssertEqual(store.selectedList?.id, original.id)
  }
  func testFailedWriteRollsBackChanges() async throws {
    let blocked = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: blocked) }
    try Data("parent is a file".utf8).write(to: blocked)
    let store = ReminderStore(
      fileURL: blocked.appendingPathComponent("reminders.json"), isolated: true)
    XCTAssertNil(store.error)
    let count = store.items.count
    do {
      try await store.save(ReminderItem(listID: store.defaultList.id, title: "Must not appear"))
      XCTFail("Expected an archive write failure")
    } catch { XCTAssertEqual(store.items.count, count) }
  }
  func testCorruptArchiveIsPreserved() throws {
    let file = temporaryFile()
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    try FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    let content = Data("corrupt original".utf8)
    try content.write(to: file)
    let store = ReminderStore(fileURL: file, isolated: true)
    XCTAssertNotNil(store.error)
    XCTAssertThrowsError(try store.saveList(ReminderList(name: "No overwrite")))
    XCTAssertEqual(try Data(contentsOf: file), content)
  }
  func testAlertDateLocationLanguageAndCancellationEligibility() throws {
    var item = ReminderItem(listID: UUID(), title: "User text")
    item.due = Date().addingTimeInterval(3600)
    item.place = ReminderPlace(name: "London", latitude: 51.5, longitude: -0.1, onArrival: false)
    let requests = ReminderAlerts.requests(for: item, language: .chinese)
    XCTAssertEqual(requests.count, 2)
    XCTAssertEqual(requests[0].content.title, "User text")
    XCTAssertEqual(requests[0].content.body, "提醒事项")
    XCTAssertNotNil((requests[0].trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate())
    let region = try XCTUnwrap(
      (requests[1].trigger as? UNLocationNotificationTrigger)?.region as? CLCircularRegion)
    XCTAssertFalse(region.notifyOnEntry)
    XCTAssertTrue(region.notifyOnExit)
    item.completedAt = Date()
    XCTAssertTrue(ReminderAlerts.requests(for: item).isEmpty)
    item.completedAt = nil
    item.systemID = "system-test"
    XCTAssertTrue(ReminderAlerts.requests(for: item).isEmpty)
  }
  func testDemoDoesNotWriteProductionArchive() {
    let store = ReminderStore(isolated: true, demo: true, language: .chinese)
    XCTAssertEqual(store.lists.count, 3)
    XCTAssertTrue(store.items.contains { $0.title == "读一本好书" })
    XCTAssertFalse(store.connected)
  }
}
