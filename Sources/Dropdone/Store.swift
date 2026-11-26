import Foundation
import Observation
import SwiftUI

/// Holds the checklist and saves it to a JSON file after every change.
@Observable
final class Store {
    private(set) var items: [Item] = []
    /// Updated when the undo time runs out, so the views refresh.
    private(set) var clock: Date

    /// Seconds a checked item stays in the list, so a wrong click can be undone.
    static let archiveDelay: TimeInterval = 5

    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private let archiveDelay: TimeInterval
    @ObservationIgnored private let now: () -> Date
    /// Items already in History this session, so a clock set back does not pull them back into the list.
    @ObservationIgnored private var archivedIDs: Set<Item.ID> = []
    /// When the undo time restarted, for checked items whose undo start is ahead of the clock.
    @ObservationIgnored private var undoRestarts: [Item.ID: Date] = [:]
    @ObservationIgnored private var archiveTask: Task<Void, Never>?

    init(
        fileURL: URL = Store.defaultFileURL,
        archiveDelay: TimeInterval = Store.archiveDelay,
        now: @escaping () -> Date = Date.init
    ) {
        self.fileURL = fileURL
        self.archiveDelay = archiveDelay
        self.now = now
        clock = now()
        load()
    }

    deinit {
        archiveTask?.cancel()
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
        if archivedIDs.contains(item.id) {
            return true
        }
        guard let started = undoStart(of: item) else { return true }
        return now.timeIntervalSince(started) >= archiveDelay
    }

    private func undoStart(of item: Item) -> Date? {
        undoRestarts[item.id] ?? item.completedAt
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
        archiveReadyItems(at: clock)
        items[index].isDone.toggle()
        let current = now()
        items[index].completedAt = items[index].isDone ? current : nil
        archivedIDs.remove(id)
        undoRestarts[id] = nil
        clock = current
        archiveReadyItems(at: clock)
        restartUndoAheadOfClock()
        save()
        scheduleNextArchive()
    }

    /// Moves the clock on when the soonest checked item finishes its undo time.
    private func scheduleNextArchive() {
        archiveTask?.cancel()
        archiveTask = nil
        let nextDelay = items
            .filter { $0.isDone && !isArchived($0, at: clock) }
            .compactMap(undoStart)
            .map { $0.addingTimeInterval(archiveDelay).timeIntervalSince(clock) }
            .min()
        guard let nextDelay else { return }
        archiveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(max(nextDelay, 0)))
            guard !Task.isCancelled, let self else { return }
            archiveTask = nil
            syncClock()
            scheduleNextArchive()
        }
    }

    /// Moves the clock to now while keeping archived items in History and restarting
    /// any pending undo time whose start ended up ahead of the clock.
    private func syncClock() {
        archiveReadyItems(at: clock)
        clock = now()
        archiveReadyItems(at: clock)
        restartUndoAheadOfClock()
    }

    /// Remembers items that have moved to History so setting the clock back does not pull them back out.
    private func archiveReadyItems(at time: Date) {
        for item in items where isArchived(item, at: time) {
            archivedIDs.insert(item.id)
            undoRestarts[item.id] = nil
        }
    }

    /// A clock set back must not keep a checked item waiting longer than the undo time, so its undo time
    /// starts again now. Its real finish date is kept, because the clock may be wrong only for a moment.
    private func restartUndoAheadOfClock() {
        for item in items where item.isDone && !archivedIDs.contains(item.id) {
            guard let started = undoStart(of: item), started > clock else { continue }
            undoRestarts[item.id] = clock
        }
    }

    /// Renames an item. An empty name removes the item, and pasted lines are joined into one.
    func rename(_ id: Item.ID, to title: String) {
        let trimmed = title.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        if trimmed.isEmpty {
            items.remove(at: index)
            archivedIDs.remove(id)
            undoRestarts[id] = nil
            syncClock()
            scheduleNextArchive()
        } else {
            items[index].title = trimmed
        }
        save()
    }

    func delete(_ id: Item.ID) {
        items.removeAll { $0.id == id }
        archivedIDs.remove(id)
        undoRestarts[id] = nil
        syncClock()
        scheduleNextArchive()
        save()
    }

    /// Removes every finished item for good, including one checked a moment ago. Open items stay.
    func clearHistory() {
        items.removeAll { $0.isDone }
        archivedIDs.removeAll()
        undoRestarts.removeAll()
        scheduleNextArchive()
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
        archiveReadyItems(at: clock)
        restartUndoAheadOfClock()
        scheduleNextArchive()
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
