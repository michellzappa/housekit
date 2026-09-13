import AppKit
import ApplicationServices
import UserNotifications

/// Accessibility (AX API, event taps, synthetic keystrokes). The grant is
/// keyed to the code signature — see the signing notes in every README.
public enum Accessibility {
    public static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt once; later calls are silent.
    public static func requestTrust() {
        let options = ["AXTrustedCheckOptionPrompt" as CFString: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    @MainActor
    public static func openSettings() {
        openPrivacyPane("Privacy_Accessibility")
    }
}

/// User notifications. Authorization is async on the system side; this keeps
/// the last known answer so a settings row can read it synchronously.
public enum Notifications {
    nonisolated(unsafe) private static var cachedGranted = false

    public static var isGranted: Bool {
        refresh()
        return cachedGranted
    }

    public static func refresh() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            cachedGranted = [.authorized, .provisional].contains(settings.authorizationStatus)
        }
    }

    public static func request() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in refresh() }
    }

    @MainActor
    public static func openSettings() {
        openPrivacyPane("Privacy_Notifications")
    }
}

@MainActor
func openPrivacyPane(_ anchor: String) {
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
        NSWorkspace.shared.open(url)
    }
}
