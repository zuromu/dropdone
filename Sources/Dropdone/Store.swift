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

    init(fileURL: URL = Store.defaultFileURL) {
        self.fileURL = fileURL
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

    /// A checked item moves to history once the undo time has passed.
    func isArchived(_ item: Item, at now: Date) -> Bool {
        guard item.isDone else { return false }
        guard let finished = item.completedAt else { return true }
        return now.timeIntervalSince(finished) >= Self.archiveDelay
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
            // Once the undo time is over, the clock moves on and the item leaves the list.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(Self.archiveDelay))
                clock = Date()
            }
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

    /// The list shows open items only, so the offsets count those, not history.
    /// Removes every finished item for good. Open items stay.
    func clearHistory() {
        items.removeAll { isArchived($0, at: clock) }
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        var open = openItems
        open.move(fromOffsets: source, toOffset: destination)
        items = open + history
        save()
    }

    // MARK: - Saving and loading

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let saved = try? JSONDecoder().decode([Item].self, from: data)
        else { return }
        items = saved.filter { !$0.title.isEmpty }
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
