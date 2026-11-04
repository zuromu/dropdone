import SwiftUI

struct ContentView: View {
    let store: Store
    @State private var editingID: Item.ID?
    @State private var showHistory = false

    private let rowHeight: CGFloat = 40
    private let topPadding: CGFloat = 8
    private let footerHeight: CGFloat = 48
    private let maxListHeight: CGFloat = 360

    /// The panel grows with the list, but stops growing at maxListHeight.
    private var listHeight: CGFloat {
        let count = showHistory ? store.history.count : store.openItems.count
        if count == 0 {
            return 80
        }
        return min(CGFloat(count) * rowHeight + topPadding, maxListHeight)
    }

    var body: some View {
        VStack(spacing: 0) {
            if showHistory {
                HistoryView(store: store)
                    .padding(.top, topPadding)
                    .frame(height: listHeight)
            } else {
                List {
                    ForEach(store.openItems) { item in
                        ItemRow(item: item, store: store, editingID: $editingID)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 3, leading: 0, bottom: 3, trailing: 0))
                    }
                    .onMove { source, destination in
                        store.move(from: source, to: destination)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .contentMargins(.horizontal, 12, for: .scrollContent)
                .padding(.top, topPadding)
                .frame(height: listHeight)
                .overlay {
                    if store.openItems.isEmpty {
                        Text("Nothing to do")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 16) {
                if showHistory {
                    Button("Clear") {
                        store.clearHistory()
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        editingID = store.add()
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button(showHistory ? "Back" : "History") {
                    editingID = nil
                    showHistory.toggle()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .keyboardShortcut("q")
            }
            .padding(12)
            .frame(height: footerHeight)
        }
        .frame(width: 320)
        .background(.clear)
    }
}
