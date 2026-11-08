import AppKit
import Observation
import SwiftUI

/// Owns the menu bar item and its panel, so the global shortcut can open and close it.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = Store()
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ContentView(store: store))

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "Dropdone")
        item.button?.imagePosition = .imageLeading
        item.button?.target = self
        item.button?.action = #selector(togglePanel)
        statusItem = item

        updateCount()
        GlobalShortcut.register { [weak self] in self?.togglePanel() }
    }

    /// Shows how many items are left next to the icon, and runs again whenever that number changes.
    private func updateCount() {
        let count = withObservationTracking {
            store.remainingCount
        } onChange: { [weak self] in
            DispatchQueue.main.async { self?.updateCount() }
        }
        statusItem?.button?.title = count > 0 ? " \(count)" : ""
    }

    @objc private func togglePanel() {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
