import ServiceManagement

/// Launch-at-login via `SMAppService`, the same three lines every app had.
public enum LaunchAtLogin {
    public static var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    /// True only when macOS will launch the app at login.
    public static var isEnabled: Bool {
        status == .enabled
    }

    /// True when the app is registered or waits for Login Items approval.
    /// Both states mean the person asked for launch at login.
    public static var isRequested: Bool {
        switch status {
        case .enabled, .requiresApproval: return true
        case .notRegistered, .notFound: return false
        @unknown default: return false
        }
    }

    /// True when macOS waits for the person to allow the app in Login Items.
    public static var needsApproval: Bool {
        status == .requiresApproval
    }

    public static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    /// Opens System Settings → General → Login Items.
    public static func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
