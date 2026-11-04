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
}
