import XCTest

final class StorePersistenceTests: XCTestCase {
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

    func testMoveIsSaved() {
        let store = Store(fileURL: fileURL)
        store.add(title: "a")
        store.add(title: "b")
        store.add(title: "c")
        store.move(from: IndexSet(integer: 0), to: 3)

        XCTAssertEqual(Store(fileURL: fileURL).items.map(\.title), ["b", "c", "a"])
    }

    func testMoveIncludesJustCheckedItemAndKeepsHistory() throws {
        let old = [
            Item(title: "a"),
            Item(title: "archived", isDone: true, completedAt: Date().addingTimeInterval(-60)),
            Item(title: "b"),
        ]
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try JSONEncoder().encode(old).write(to: fileURL)

        let store = Store(fileURL: fileURL)
        store.toggle(store.openItems[0].id)
        store.move(from: IndexSet(integer: 1), to: 0)

        XCTAssertEqual(store.openItems.map(\.title), ["b", "a"])
        XCTAssertEqual(store.history.map(\.title), ["archived"])
        XCTAssertEqual(Store(fileURL: fileURL).items.map(\.title), ["b", "a", "archived"])
    }

    func testRestoreFromHistoryIsSaved() throws {
        let old = [Item(title: "old done", isDone: true, completedAt: Date().addingTimeInterval(-60))]
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try JSONEncoder().encode(old).write(to: fileURL)

        let store = Store(fileURL: fileURL)
        store.toggle(store.history[0].id)

        let reloaded = Store(fileURL: fileURL)
        XCTAssertEqual(reloaded.openItems.map(\.title), ["old done"])
        XCTAssertTrue(reloaded.history.isEmpty)
        XCTAssertNil(reloaded.items[0].completedAt)
    }

    func testRenameToEmptyIsSaved() {
        let store = Store(fileURL: fileURL)
        let first = store.add(title: "temp")
        store.add(title: "keep")
        store.rename(first, to: "   ")

        XCTAssertEqual(Store(fileURL: fileURL).items.map(\.title), ["keep"])
    }

    func testRenameWithPastedLinesIsSavedAsOneLine() {
        let store = Store(fileURL: fileURL)
        let id = store.add()
        store.rename(id, to: "Buy  milk\r\n\n  eggs\nbread ")

        XCTAssertEqual(Store(fileURL: fileURL).items.map(\.title), ["Buy  milk eggs bread"])
    }

    func testFinishDatesAheadOfTheClockAreKept() throws {
        // The Mac started with its clock set back, so both items look like they were finished later than now.
        let now = Date()
        let saved = [
            Item(title: "older", isDone: true, completedAt: now.addingTimeInterval(3600)),
            Item(title: "newer", isDone: true, completedAt: now.addingTimeInterval(7200)),
        ]
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try JSONEncoder().encode(saved).write(to: fileURL)

        let store = Store(fileURL: fileURL)
        store.add(title: "new item")

        let onDisk = try JSONDecoder().decode([Item].self, from: Data(contentsOf: fileURL))
        XCTAssertEqual(onDisk.map(\.completedAt), saved.map(\.completedAt) + [nil])
    }

    func testEachReloadedItemArchivesWhenItsOwnUndoTimeIsOver() async throws {
        let now = Date()
        let saved = [
            Item(title: "checked first", isDone: true, completedAt: now.addingTimeInterval(-57)),
            Item(title: "checked second", isDone: true, completedAt: now),
        ]
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try JSONEncoder().encode(saved).write(to: fileURL)

        let store = Store(fileURL: fileURL, archiveDelay: 60)
        XCTAssertEqual(store.openItems.map(\.title), ["checked first", "checked second"])

        // The first item had about 3 seconds left, so it must not wait for the second one.
        try await Task.sleep(for: .seconds(5))
        XCTAssertEqual(store.openItems.map(\.title), ["checked second"])
        XCTAssertEqual(store.history.map(\.title), ["checked first"])
    }

    func testUnreadableFileReplacesExistingBackup() throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let backup = fileURL.appendingPathExtension("bak")
        try Data("older broken".utf8).write(to: backup)
        try Data("newer broken".utf8).write(to: fileURL)

        let store = Store(fileURL: fileURL)
        store.add(title: "Fresh")

        XCTAssertEqual(try String(contentsOf: backup, encoding: .utf8), "newer broken")
        XCTAssertEqual(Store(fileURL: fileURL).items.map(\.title), ["Fresh"])
    }

    func testCheckedItemArchivesAfterClockIsSetBackWhileRunning() async throws {
        var current = Date()
        let store = Store(fileURL: fileURL, archiveDelay: 0.5, now: { current })
        let id = store.add(title: "checked, then clock back")
        store.toggle(id)

        // The Mac's clock is set back an hour before the undo timer fires.
        current = current.addingTimeInterval(-3600)
        try await Task.sleep(for: .seconds(0.7))
        XCTAssertEqual(store.openItems.map(\.title), ["checked, then clock back"])

        // The undo time starts again at the new clock, so one undo time later it is archived.
        current = current.addingTimeInterval(0.6)
        try await Task.sleep(for: .seconds(0.8))
        XCTAssertTrue(store.openItems.isEmpty)
        XCTAssertEqual(store.history.map(\.title), ["checked, then clock back"])
    }
}
