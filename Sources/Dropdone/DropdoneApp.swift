import SwiftUI

@main
struct DropdoneApp: App {
    @State private var store = Store()

    var body: some Scene {
        MenuBarExtra("Dropdone", systemImage: "checklist") {
            ContentView(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}
