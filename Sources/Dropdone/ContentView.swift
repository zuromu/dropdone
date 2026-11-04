import SwiftUI

struct ContentView: View {
    let store: Store
    @State private var editingID: Item.ID?

    private let rowHeight: CGFloat = 44
    private let footerHeight: CGFloat = 48
    private let maxListHeight: CGFloat = 360

    // The panel grows with the list, but stops growing at maxListHeight.
    private var listHeight: CGFloat {
        if store.items.isEmpty {
            return 80
        }
        return min(CGFloat(store.items.count) * rowHeight + 12, maxListHeight)
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(store.items) { item in
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
            .contentMargins(.top, 6, for: .scrollContent)
            .frame(height: listHeight)
            .overlay {
                if store.items.isEmpty {
                    Text("Nothing to do")
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Button {
                    editingID = store.add()
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.plain)

                Spacer()

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
