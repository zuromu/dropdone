import SwiftUI

struct ContentView: View {
    let store: Store
    @State private var editingID: Item.ID?
    @State private var showHistory = false
    @State private var opensAtLogin = LoginItem.isEnabled
    /// Clear asks for a second click, because it deletes for good.
    @State private var confirmClear = false

    private let rowHeight: CGFloat = 40
    private let minRows: CGFloat = 3
    private let topPadding: CGFloat = 8
    private let footerHeight: CGFloat = 48
    private let maxListHeight: CGFloat = 360

    /// The panel grows with the list, but stops growing at maxListHeight.
    private var listHeight: CGFloat {
        let count = showHistory ? store.history.count : store.openItems.count
        // Never smaller than minRows, so the window does not jump on every change.
        let rows = max(CGFloat(count), minRows)
        return min(rows * rowHeight + topPadding, maxListHeight)
    }

    var body: some View {
        VStack(spacing: 0) {
            if showHistory {
                HistoryView(store: store)
                    .padding(.top, topPadding)
                    .frame(height: listHeight)
                    .transition(.opacity)
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
                .animation(.smooth, value: store.openItems)
                .overlay {
                    if store.openItems.isEmpty {
                        Text("Nothing to do")
                            .foregroundStyle(.secondary)
                    }
                }
                .transition(.opacity)
            }

            HStack(spacing: 16) {
                if showHistory {
                    Button(confirmClear ? "Clear all?" : "Clear") {
                        if confirmClear {
                            store.clearHistory()
                            confirmClear = false
                        } else {
                            confirmClear = true
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(confirmClear ? Color.red : Color.primary)
                    .disabled(store.history.isEmpty)
                } else {
                    Button {
                        editingID = store.add()
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("n")
                    .help("Add an item (Command-N)")
                }

                Spacer()

                Button(showHistory ? "Back" : "History") {
                    editingID = nil
                    confirmClear = false
                    showHistory.toggle()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Menu {
                    Toggle("Open at login", isOn: $opensAtLogin)
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .foregroundStyle(.secondary)
                .accessibilityLabel("More options")
                .onChange(of: opensAtLogin) { _, wanted in
                    LoginItem.set(wanted)
                    // If the system said no, show the real state again.
                    opensAtLogin = LoginItem.isEnabled
                }

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
        .animation(.smooth, value: showHistory)
        .frame(width: 320)
        .background(.clear)
    }
}
