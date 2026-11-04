import Foundation

/// One line on the checklist.
struct Item: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var isDone = false
    /// When the item was checked off. Nil while it is still open.
    var completedAt: Date?
}
