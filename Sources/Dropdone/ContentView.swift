import SwiftUI

struct ContentView: View {
    let store: Store

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(store.items) { item in
                    ItemRow(item: item, store: store)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            Divider()

            HStack {
                Button {
                    store.add(title: "New item")
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
    }
}
