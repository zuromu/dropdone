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
}
