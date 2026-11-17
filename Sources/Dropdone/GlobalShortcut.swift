import AppKit
import Carbon.HIToolbox

/// Opens and closes the panel from any app with Control-Option-D.
enum GlobalShortcut {
    private static var hotKey: EventHotKeyRef?
    private static var onPress: (() -> Void)?

    static func register(onPress: @escaping () -> Void) {
        guard hotKey == nil else { return }
        self.onPress = onPress

        let id = EventHotKeyID(signature: OSType(0x4452_4F50), id: 1) // "DROP"
        let modifiers = UInt32(controlKey | optionKey)
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_D), modifiers, id, GetApplicationEventTarget(), 0, &hotKey
        )
        guard status == noErr else {
            print("Could not register the shortcut: \(status)")
            hotKey = nil
            return
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let installStatus = InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { GlobalShortcut.onPress?() }
            return noErr
        }, 1, &eventType, nil, nil)
        if installStatus != noErr {
            print("Could not install the shortcut handler: \(installStatus)")
            UnregisterEventHotKey(hotKey)
            hotKey = nil
        }
    }
}
