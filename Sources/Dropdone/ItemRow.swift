import SwiftUI

struct ItemRow: View {
    let item: Item
    let store: Store
    @Binding var editingID: Item.ID?

    @State private var draft = ""
    @FocusState private var isFocused: Bool

    private var isEditing: Bool {
        editingID == item.id
    }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                store.toggle(item.id)
            } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isDone ? Color.accentColor : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)

            if isEditing {
                TextField("What needs doing?", text: $draft)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onSubmit(finishEditing)
                    .onExitCommand(perform: finishEditing)
                    .onAppear {
                        draft = item.title
                        isFocused = true
                    }
                    .onChange(of: isFocused) { _, focused in
                        if !focused {
                            finishEditing()
                        }
                    }
            } else {
                Text(item.title)
                    .strikethrough(item.isDone)
                    .foregroundStyle(item.isDone ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        editingID = item.id
                    }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
        // A checked row fades while the undo time runs, then leaves the list.
        .opacity(item.isDone ? 0.55 : 1)
        .animation(.smooth, value: item.isDone)
        .contextMenu {
            Button("Delete", role: .destructive) {
                store.delete(item.id)
            }
        }
    }

    private func finishEditing() {
        // Both Return and losing focus end up here, so only run once.
        guard isEditing else { return }
        editingID = nil
        store.rename(item.id, to: draft)
    }
}
