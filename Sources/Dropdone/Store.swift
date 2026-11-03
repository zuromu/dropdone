import Foundation
import Observation
import SwiftUI

/// Holds the checklist and saves it to a JSON file after every change.
@Observable
final class Store {
    private(set) var items: [Item] = []

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
        save()
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

    func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        save()
    }

    // MARK: - Saving and loading

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let saved = try? JSONDecoder().decode([Item].self, from: data)
        else { return }
        items = saved
    }

    private func save() {
        do {
            let folder = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(items)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Could not save items: \(error)")
        }
    }
}
