import SwiftUI

struct ContentView: View {
    let store: Store
    @State private var editingID: Item.ID?

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(store.items) { item in
                    ItemRow(item: item, store: store, editingID: $editingID)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 3, leading: 10, bottom: 3, trailing: 10))
                }
                .onMove { source, destination in
                    store.move(from: source, to: destination)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

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
        }
        .frame(width: 320, height: 420)
        .background(.clear)
    }
}
