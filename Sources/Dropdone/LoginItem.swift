import ServiceManagement

/// Starts the app when you log in, using the system's login item list.
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) {
        guard enabled else {
            do {
                try SMAppService.mainApp.unregister()
            } catch {
                print("Could not change the login item: \(error)")
            }
            return
        }

        // Already registered and waiting on the user, so go straight to Login Items.
        if SMAppService.mainApp.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
            return
        }

        do {
            try SMAppService.mainApp.register()
        } catch {
            // register() throws when the user has not approved the item yet.
            if SMAppService.mainApp.status != .requiresApproval {
                print("Could not change the login item: \(error)")
                return
            }
        }

        if SMAppService.mainApp.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
    }
}
