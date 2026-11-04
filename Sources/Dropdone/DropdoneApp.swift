import SwiftUI

@main
struct DropdoneApp: App {
    @State private var store = Store()

    var body: some Scene {
        MenuBarExtra {
            ContentView(store: store)
        } label: {
            Image(systemName: "checklist")
            if store.remainingCount > 0 {
                Text("\(store.remainingCount)")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
