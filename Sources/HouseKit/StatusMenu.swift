import AppKit

/// The house status-item menu shape:
///
///     ── header (live status, or the app name) ──
///     app actions, with shortcuts
///     ──────────
///     Settings…            ⌘,
///     Launch at Login      ✓
///     ──────────
///     Quit <App>           ⌘Q
///
/// Apps build the middle; `appendStandardTail` adds the rest so it never drifts.
@MainActor
public enum StatusMenu {
    public static func sectionHeader(_ title: String) -> NSMenuItem {
        NSMenuItem.sectionHeader(title: title)
    }

    public static func appendStandardTail(
        to menu: NSMenu,
        appName: String,
        target: AnyObject,
        settings: Selector,
        launchAtLogin: Selector,
        launchAtLoginEnabled: Bool,
        quit: Selector
    ) {
        if let last = menu.items.last, !last.isSeparatorItem {
            menu.addItem(.separator())
        }
        let settingsItem = NSMenuItem(title: "Settings…", action: settings, keyEquivalent: ",")
        settingsItem.target = target
        menu.addItem(settingsItem)
        let launchItem = NSMenuItem(title: "Launch at Login", action: launchAtLogin, keyEquivalent: "")
        launchItem.state = launchAtLoginEnabled ? .on : .off
        launchItem.target = target
        menu.addItem(launchItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit \(appName)", action: quit, keyEquivalent: "q")
        quitItem.target = target
        menu.addItem(quitItem)
    }
}
