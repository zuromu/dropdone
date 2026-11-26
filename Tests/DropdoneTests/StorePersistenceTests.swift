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

    func testCheckingItemAfterClockWentBackKeepsUndoTime() {
        var current = Date()
        let store = Store(fileURL: fileURL, archiveDelay: 5, now: { current })
        let id = store.add(title: "checked after clock back")

        // The Mac's clock is set back an hour before the user checks the item.
        current = current.addingTimeInterval(-3600)
        store.toggle(id)

        XCTAssertEqual(store.openItems.map(\.title), ["checked after clock back"])
        XCTAssertTrue(store.history.isEmpty)
    }

    @MainActor
    private func waitForClock(
        _ target: Date,
        on store: Store,
        timeout: Duration = .seconds(3),
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let deadline = ContinuousClock.now + timeout
        while store.clock != target, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertEqual(store.clock, target, file: file, line: line)
    }

    @MainActor
    func testArchivedItemStaysInHistoryWhenClockIsSetBack() async throws {
        var current = Date()
        let store = Store(fileURL: fileURL, archiveDelay: 0.2, now: { current })
        let archived = store.add(title: "already archived")
        store.toggle(archived)

        current = current.addingTimeInterval(0.3)
        try await waitForClock(current, on: store)
        XCTAssertEqual(store.history.map(\.title), ["already archived"])

        // The Mac's clock is set back an hour and the user checks a second item.
        current = current.addingTimeInterval(-3600)
        let next = store.add(title: "next item")
        store.toggle(next)

        XCTAssertEqual(store.openItems.map(\.title), ["next item"])
        XCTAssertEqual(store.history.map(\.title), ["already archived"])

        current = current.addingTimeInterval(0.3)
        try await waitForClock(current, on: store)
        XCTAssertTrue(store.openItems.isEmpty)
        XCTAssertEqual(store.history.map(\.title), ["already archived", "next item"])
    }

    @MainActor
    func testCheckedItemArchivesAfterClockIsSetBackTwiceWhileRunning() async throws {
        var current = Date()
        let store = Store(fileURL: fileURL, archiveDelay: 0.2, now: { current })
        let id = store.add(title: "clock back twice")
        store.toggle(id)

        // Clock goes back once before the first timer fires.
        current = current.addingTimeInterval(-3600)
        try await waitForClock(current, on: store)
        XCTAssertEqual(store.openItems.map(\.title), ["clock back twice"])

        // Clock goes back a second time before the restarted undo time finishes.
        current = current.addingTimeInterval(-3600)
        try await waitForClock(current, on: store)
        XCTAssertEqual(store.openItems.map(\.title), ["clock back twice"])

        current = current.addingTimeInterval(0.3)
        try await waitForClock(current, on: store)
        XCTAssertTrue(store.openItems.isEmpty)
        XCTAssertEqual(store.history.map(\.title), ["clock back twice"])
    }

    @MainActor
    func testCheckedItemStillArchivesAfterSmallClockStepBack() async throws {
        var current = Date()
        let store = Store(fileURL: fileURL, archiveDelay: 0.2, now: { current })
        let id = store.add(title: "small step back")
        store.toggle(id)

        // Only 0.05s has passed on the wall clock when the first timer fires (0.15s left).
        current = current.addingTimeInterval(0.05)
        try await waitForClock(current, on: store)
        XCTAssertEqual(store.openItems.map(\.title), ["small step back"])

        current = current.addingTimeInterval(0.2)
        try await waitForClock(current, on: store)
        XCTAssertTrue(store.openItems.isEmpty)
        XCTAssertEqual(store.history.map(\.title), ["small step back"])
    }

    @MainActor
    func testDeletingAnotherItemDoesNotResetUndoTimer() async throws {
        var current = Date()
        let store = Store(fileURL: fileURL, archiveDelay: 1.5, now: { current })
        let checked = store.add(title: "checked")
        let other = store.add(title: "other")
        store.toggle(checked)

        // 1.2s of the 1.5s undo time has passed when another item is deleted (0.3s left).
        current = current.addingTimeInterval(1.2)
        store.delete(other)

        current = current.addingTimeInterval(0.4)
        try await waitForClock(current, on: store, timeout: .seconds(0.9))
        XCTAssertTrue(store.openItems.isEmpty)
        XCTAssertEqual(store.history.map(\.title), ["checked"])
    }

    @MainActor
    func testUncheckingAnotherItemDoesNotResetUndoTimer() async throws {
        var current = Date()
        let store = Store(fileURL: fileURL, archiveDelay: 1.5, now: { current })
        let first = store.add(title: "first")
        let second = store.add(title: "second")
        store.toggle(first)
        store.toggle(second)

        // 1.2s of the 1.5s undo time has passed when the second item is unchecked (0.3s left).
        current = current.addingTimeInterval(1.2)
        store.toggle(second)

        current = current.addingTimeInterval(0.4)
        try await waitForClock(current, on: store, timeout: .seconds(0.9))
        XCTAssertEqual(store.openItems.map(\.title), ["second"])
        XCTAssertEqual(store.history.map(\.title), ["first"])
    }

    func testRestoredItemGetsUndoTimeWhenCheckedAgain() throws {
        let old = [Item(title: "old done", isDone: true, completedAt: Date().addingTimeInterval(-60))]
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try JSONEncoder().encode(old).write(to: fileURL)

        let store = Store(fileURL: fileURL)
        let id = store.history[0].id
        store.toggle(id)
        store.toggle(id)

        XCTAssertEqual(store.openItems.map(\.title), ["old done"])
        XCTAssertTrue(store.history.isEmpty)
    }
}
