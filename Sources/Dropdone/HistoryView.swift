import SwiftUI

/// The finished items, newest first. Restore puts one back on the list.
struct HistoryView: View {
    let store: Store

    var body: some View {
        List {
            ForEach(store.history) { item in
                HStack(spacing: 10) {
                    Button {
                        store.toggle(item.id)
                    } label: {
                        Image(systemName: "arrow.uturn.backward.circle")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Put back on the list")

                    Text(item.title)
                        .strikethrough()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let date = item.completedAt {
                        Text(date, format: .dateTime.day().month().hour().minute())
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                .contextMenu {
                    Button("Delete", role: .destructive) {
                        store.delete(item.id)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .animation(.smooth, value: store.history)
        .overlay {
            if store.history.isEmpty {
                Text("No history yet")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
