import SwiftUI

@main
struct DropdoneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // The menu bar item and its panel live in AppDelegate, so there is no window scene.
        Settings { EmptyView() }
            .commands {
                // Nothing to set here, so Command-comma must not open an empty window.
                CommandGroup(replacing: .appSettings) {}
            }
    }
}
