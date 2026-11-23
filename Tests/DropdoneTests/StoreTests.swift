import XCTest

final class StoreTests: XCTestCase {
    private var fileURL: URL!

    override func setUp() {
        super.setUp()
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("items.json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
        super.tearDown()
    }

    func testAddAppendsItem() {
        let store = Store(fileURL: fileURL)
        store.add(title: "Buy milk")
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items[0].title, "Buy milk")
        XCTAssertFalse(store.items[0].isDone)
    }

    func testToggleFlipsDone() {
        let store = Store(fileURL: fileURL)
        let id = store.add(title: "Study")
        store.toggle(id)
        XCTAssertTrue(store.items[0].isDone)
        store.toggle(id)
        XCTAssertFalse(store.items[0].isDone)
    }

    func testRenameTrimsSpaces() {
        let store = Store(fileURL: fileURL)
        let id = store.add(title: "old")
        store.rename(id, to: "  new name  ")
        XCTAssertEqual(store.items[0].title, "new name")
    }

    func testRenameToEmptyRemovesItem() {
        let store = Store(fileURL: fileURL)
        let id = store.add(title: "temp")
        store.rename(id, to: "   ")
        XCTAssertTrue(store.items.isEmpty)
    }

    func testDeleteRemovesOnlyThatItem() {
        let store = Store(fileURL: fileURL)
        let first = store.add(title: "one")
        store.add(title: "two")
        store.delete(first)
        XCTAssertEqual(store.items.map(\.title), ["two"])
    }

    func testMoveReorders() {
        let store = Store(fileURL: fileURL)
        store.add(title: "a")
        store.add(title: "b")
        store.add(title: "c")
        store.move(from: IndexSet(integer: 0), to: 3)
        XCTAssertEqual(store.items.map(\.title), ["b", "c", "a"])
    }

    func testItemsSurviveReload() {
        let store = Store(fileURL: fileURL)
        let id = store.add(title: "keep me")
        store.toggle(id)

        let reloaded = Store(fileURL: fileURL)
        XCTAssertEqual(reloaded.items.count, 1)
        XCTAssertEqual(reloaded.items[0].title, "keep me")
        XCTAssertTrue(reloaded.items[0].isDone)
    }

    func testToggleSetsAndClearsCompletedDate() {
        let store = Store(fileURL: fileURL)
        let id = store.add(title: "finish me")

        store.toggle(id)
        XCTAssertNotNil(store.items[0].completedAt)

        store.toggle(id)
        XCTAssertNil(store.items[0].completedAt)
    }

    func testOldFileWithoutCompletedDateStillLoads() throws {
        let json = #"[{"id":"\#(UUID().uuidString)","title":"old item","isDone":true}]"#
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try Data(json.utf8).write(to: fileURL)

        let store = Store(fileURL: fileURL)
        XCTAssertEqual(store.items.map(\.title), ["old item"])
        XCTAssertNil(store.items[0].completedAt)
    }

    func testCheckedItemMovesToHistoryAfterUndoTime() {
        let store = Store(fileURL: fileURL)
        let finished = Date()
        let item = Item(title: "done", isDone: true, completedAt: finished)

        XCTAssertFalse(store.isArchived(item, at: finished.addingTimeInterval(1)))
        XCTAssertTrue(store.isArchived(item, at: finished.addingTimeInterval(Store.archiveDelay)))
    }

    func testOpenItemIsNeverArchived() {
        let store = Store(fileURL: fileURL)
        let item = Item(title: "still open")
        XCTAssertFalse(store.isArchived(item, at: Date.distantFuture))
    }

    func testJustCheckedItemStaysInOpenItems() {
        let store = Store(fileURL: fileURL)
        let id = store.add(title: "oops")
        store.toggle(id)

        XCTAssertEqual(store.openItems.count, 1)
        XCTAssertTrue(store.history.isEmpty)
    }

    func testDoneItemFromOldFileGoesToHistory() throws {
        let old = [Item(title: "open"), Item(title: "old done", isDone: true)]
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try JSONEncoder().encode(old).write(to: fileURL)

        let store = Store(fileURL: fileURL)
        XCTAssertEqual(store.openItems.map(\.title), ["open"])
        XCTAssertEqual(store.history.map(\.title), ["old done"])
    }

    func testClearHistoryKeepsOpenItems() throws {
        let old = [Item(title: "open"), Item(title: "old done", isDone: true)]
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try JSONEncoder().encode(old).write(to: fileURL)

        let store = Store(fileURL: fileURL)
        store.clearHistory()
        XCTAssertEqual(store.items.map(\.title), ["open"])
        XCTAssertTrue(store.history.isEmpty)
    }

    func testUnreadableFileIsKeptAsBackup() throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try Data("not json".utf8).write(to: fileURL)

        let store = Store(fileURL: fileURL)
        store.add(title: "New")

        let backup = fileURL.appendingPathExtension("bak")
        XCTAssertEqual(try String(contentsOf: backup, encoding: .utf8), "not json")
        XCTAssertEqual(Store(fileURL: fileURL).items.map(\.title), ["New"])
    }

    func testFileThatCannotBeReadIsKeptAsBackup() throws {
        // A folder where the items file should be: it exists but cannot be read as data.
        try FileManager.default.createDirectory(at: fileURL, withIntermediateDirectories: true)

        let store = Store(fileURL: fileURL)
        XCTAssertTrue(store.items.isEmpty)
        store.add(title: "New")

        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.appendingPathExtension("bak").path))
        XCTAssertEqual(Store(fileURL: fileURL).items.map(\.title), ["New"])
    }

    func testRestoreFromHistoryPutsItemBackOnList() throws {
        let old = [Item(title: "old done", isDone: true)]
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try JSONEncoder().encode(old).write(to: fileURL)

        let store = Store(fileURL: fileURL)
        store.toggle(store.history[0].id)
        XCTAssertEqual(store.openItems.map(\.title), ["old done"])
        XCTAssertTrue(store.history.isEmpty)
    }

    func testMoveKeepsHistoryAfterOpenItems() throws {
        let old = [
            Item(title: "a"),
            Item(title: "old done", isDone: true),
            Item(title: "c"),
        ]
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try JSONEncoder().encode(old).write(to: fileURL)

        let store = Store(fileURL: fileURL)
        store.move(from: IndexSet(integer: 1), to: 0)
        XCTAssertEqual(store.items.map(\.title), ["c", "a", "old done"])
    }

    func testRemainingCountSkipsDoneAndUnnamedItems() {
        let store = Store(fileURL: fileURL)
        store.add(title: "one")
        store.add(title: "two")
        let done = store.add(title: "three")
        store.add()
        XCTAssertEqual(store.remainingCount, 3)

        store.toggle(done)
        XCTAssertEqual(store.remainingCount, 2)
    }

    func testItemWithoutNameIsNotSaved() {
        let store = Store(fileURL: fileURL)
        store.add(title: "keep me")
        store.add()

        let reloaded = Store(fileURL: fileURL)
        XCTAssertEqual(reloaded.items.map(\.title), ["keep me"])
    }

    func testBlankItemsInOldFileAreDroppedOnLoad() throws {
        let old = [Item(title: "keep me"), Item(title: "", isDone: true)]
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try JSONEncoder().encode(old).write(to: fileURL)

        let store = Store(fileURL: fileURL)
        XCTAssertEqual(store.items.map(\.title), ["keep me"])
    }

    func testHistoryListsNewestFirstAndUndatedLast() throws {
        let now = Date()
        let old = [
            Item(title: "undated", isDone: true),
            Item(title: "older", isDone: true, completedAt: now.addingTimeInterval(-600)),
            Item(title: "newer", isDone: true, completedAt: now.addingTimeInterval(-60)),
        ]
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try JSONEncoder().encode(old).write(to: fileURL)

        let store = Store(fileURL: fileURL)
        XCTAssertEqual(store.history.map(\.title), ["newer", "older", "undated"])
    }

    func testClearHistoryIsSaved() throws {
        let old = [Item(title: "open"), Item(title: "old done", isDone: true)]
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try JSONEncoder().encode(old).write(to: fileURL)

        Store(fileURL: fileURL).clearHistory()
        XCTAssertEqual(Store(fileURL: fileURL).items.map(\.title), ["open"])
    }

    func testClearHistoryAlsoRemovesJustCheckedItem() {
        let store = Store(fileURL: fileURL)
        let id = store.add()
        store.rename(id, to: "just done")
        store.toggle(id)

        store.clearHistory()
        XCTAssertTrue(store.items.isEmpty)
    }

    func testDeleteIsSaved() {
        let store = Store(fileURL: fileURL)
        let first = store.add(title: "one")
        store.add(title: "two")
        store.delete(first)
        XCTAssertEqual(Store(fileURL: fileURL).items.map(\.title), ["two"])
    }

    func testDeleteRemovesItemFromHistory() throws {
        let old = [Item(title: "open"), Item(title: "done", isDone: true)]
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try JSONEncoder().encode(old).write(to: fileURL)

        let store = Store(fileURL: fileURL)
        store.delete(store.history[0].id)
        XCTAssertTrue(store.history.isEmpty)
        XCTAssertEqual(Store(fileURL: fileURL).items.map(\.title), ["open"])
    }

    func testRenameIsSaved() {
        let store = Store(fileURL: fileURL)
        let id = store.add(title: "old")
        store.rename(id, to: "new name")
        XCTAssertEqual(Store(fileURL: fileURL).items.map(\.title), ["new name"])
    }
}

@MainActor
extension StoreTests {
    func testToggledItemLeavesOpenItemsAfterUndoTime() async throws {
        let store = Store(fileURL: fileURL, archiveDelay: 0.1)
        let id = store.add(title: "finish soon")
        store.toggle(id)
        XCTAssertEqual(store.openItems.map(\.title), ["finish soon"])

        try await Task.sleep(for: .seconds(0.6))
        XCTAssertTrue(store.openItems.isEmpty)
        XCTAssertEqual(store.history.map(\.title), ["finish soon"])
    }

    func testUncheckingBeforeUndoTimeKeepsItemOnList() async throws {
        let store = Store(fileURL: fileURL, archiveDelay: 0.2)
        let id = store.add(title: "changed my mind")
        store.toggle(id)
        store.toggle(id)

        try await Task.sleep(for: .seconds(0.6))
        XCTAssertEqual(store.openItems.map(\.title), ["changed my mind"])
        XCTAssertTrue(store.history.isEmpty)
    }

    func testCheckingAgainRestartsUndoTime() async throws {
        let store = Store(fileURL: fileURL, archiveDelay: 1.5)
        let id = store.add(title: "twice")
        store.toggle(id)

        try await Task.sleep(for: .seconds(1))
        store.toggle(id)
        store.toggle(id)

        // The first check ran out here, but the second one is only 1 second old.
        try await Task.sleep(for: .seconds(1))
        XCTAssertEqual(store.openItems.map(\.title), ["twice"])
        XCTAssertTrue(store.history.isEmpty)

        try await Task.sleep(for: .seconds(1))
        XCTAssertTrue(store.openItems.isEmpty)
        XCTAssertEqual(store.history.map(\.title), ["twice"])
    }

    func testRecentlyCheckedItemStillArchivesAfterReload() async throws {
        let store = Store(fileURL: fileURL, archiveDelay: 0.1)
        let id = store.add(title: "checked before quit")
        store.toggle(id)

        let reloaded = Store(fileURL: fileURL, archiveDelay: 0.1)
        XCTAssertEqual(reloaded.openItems.map(\.title), ["checked before quit"])
        XCTAssertTrue(reloaded.history.isEmpty)

        try await Task.sleep(for: .seconds(0.6))
        XCTAssertTrue(reloaded.openItems.isEmpty)
        XCTAssertEqual(reloaded.history.map(\.title), ["checked before quit"])
    }

    func testReloadedItemArchivesWhenItsOwnUndoTimeIsOver() async throws {
        let store = Store(fileURL: fileURL, archiveDelay: 2)
        let id = store.add(title: "checked before quit")
        store.toggle(id)

        try await Task.sleep(for: .seconds(1.5))
        let reloaded = Store(fileURL: fileURL, archiveDelay: 2)
        XCTAssertEqual(reloaded.openItems.map(\.title), ["checked before quit"])

        // About 0.5 seconds of undo time was left, not a full 2 seconds.
        try await Task.sleep(for: .seconds(1.2))
        XCTAssertTrue(reloaded.openItems.isEmpty)
        XCTAssertEqual(reloaded.history.map(\.title), ["checked before quit"])
    }

    func testItemCheckedBeforeClockWentBackStillArchives() async throws {
        // The Mac's clock was set back an hour after this item was checked.
        let saved = [Item(title: "checked later", isDone: true, completedAt: Date().addingTimeInterval(3600))]
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try JSONEncoder().encode(saved).write(to: fileURL)

        let store = Store(fileURL: fileURL, archiveDelay: 0.1)
        XCTAssertEqual(store.openItems.map(\.title), ["checked later"])

        try await Task.sleep(for: .seconds(0.6))
        XCTAssertTrue(store.openItems.isEmpty)
        XCTAssertEqual(store.history.map(\.title), ["checked later"])
    }
}
