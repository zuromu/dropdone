import Foundation
import Observation
import SwiftUI

/// Holds the checklist and saves it to a JSON file after every change.
@Observable
final class Store {
    private(set) var items: [Item] = []
    /// Updated when the undo time runs out, so the views refresh.
    private(set) var clock = Date()

    /// Seconds a checked item stays in the list, so a wrong click can be undone.
    static let archiveDelay: TimeInterval = 5

    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private let archiveDelay: TimeInterval

    init(fileURL: URL = Store.defaultFileURL, archiveDelay: TimeInterval = Store.archiveDelay) {
        self.fileURL = fileURL
        self.archiveDelay = archiveDelay
        load()
    }

    /// ~/Library/Application Support/Dropdone/items.json
    static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Dropdone", isDirectory: true)
            .appendingPathComponent("items.json")
    }

    // MARK: - Open items and history

    /// Items that are not done yet, plus ones checked off a moment ago.
    var openItems: [Item] {
        items.filter { !isArchived($0, at: clock) }
    }

    /// Finished items, newest first. Items from an old file have no date and go last.
    var history: [Item] {
        items.filter { isArchived($0, at: clock) }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    /// How many items are still to do. Checked items and unnamed ones are not counted.
    var remainingCount: Int {
        items.filter { !$0.isDone && !$0.title.isEmpty }.count
    }

    /// A checked item moves to history once the undo time has passed.
    func isArchived(_ item: Item, at now: Date) -> Bool {
        guard item.isDone else { return false }
        guard let finished = item.completedAt else { return true }
        return now.timeIntervalSince(finished) >= archiveDelay
    }

    // MARK: - Changing the list

    /// Adds a new item at the end and returns its id.
    @discardableResult
    func add(title: String = "") -> Item.ID {
        let item = Item(title: title)
        items.append(item)
        save()
        return item.id
    }

    func toggle(_ id: Item.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isDone.toggle()
        items[index].completedAt = items[index].isDone ? Date() : nil
        save()

        if items[index].isDone {
            scheduleArchive(after: archiveDelay)
        }
    }

    /// Moves the clock on after the given seconds, so checked items leave the list.
    private func scheduleArchive(after delay: TimeInterval) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            clock = Date()
        }
    }

    /// Renames an item. An empty name removes the item.
    func rename(_ id: Item.ID, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        if trimmed.isEmpty {
            items.remove(at: index)
        } else {
            items[index].title = trimmed
        }
        save()
    }

    func delete(_ id: Item.ID) {
        items.removeAll { $0.id == id }
        save()
    }

    /// Removes every finished item for good, including one checked a moment ago. Open items stay.
    func clearHistory() {
        items.removeAll { $0.isDone }
        save()
    }

    /// The list shows open items only, so the offsets count those, not history.
    func move(from source: IndexSet, to destination: Int) {
        var open = openItems
        open.move(fromOffsets: source, toOffset: destination)
        items = open + history
        save()
    }

    // MARK: - Saving and loading

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        guard let data = try? Data(contentsOf: fileURL),
              let saved = try? JSONDecoder().decode([Item].self, from: data)
        else {
            // Keep the unreadable file, so the next save does not overwrite the old list.
            let backup = fileURL.appendingPathExtension("bak")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: fileURL, to: backup)
            return
        }
        items = saved.filter { !$0.title.isEmpty }
        // A clock set back since quitting must not keep the item waiting longer than the undo time.
        for index in items.indices where (items[index].completedAt ?? .distantPast) > clock {
            items[index].completedAt = clock
        }
        // Wait only for the undo time that is left on the most recently checked item.
        let pending = items.filter { $0.isDone && !isArchived($0, at: clock) }.compactMap(\.completedAt)
        if let latest = pending.max() {
            let left = latest.addingTimeInterval(archiveDelay).timeIntervalSince(clock)
            scheduleArchive(after: left)
        }
    }

    private func save() {
        do {
            let folder = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            // A new item has no name until it is typed, so it stays out of the file.
            let data = try JSONEncoder().encode(items.filter { !$0.title.isEmpty })
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Could not save items: \(error)")
        }
    }
}
