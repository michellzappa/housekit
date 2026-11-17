import AppKit

/// The house status-item menu shape:
///
///     ── header (live status, or the app name) ──
///     app actions, with shortcuts
///     ──────────
///     Settings…            ⌘,
///     Check for Updates…   (when the app passes `updates`)
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
        quit: Selector,
        updates: (any UpdateChecking)? = nil
    ) {
        if let last = menu.items.last, !last.isSeparatorItem {
            menu.addItem(.separator())
        }
        let settingsItem = NSMenuItem(title: "Settings…", action: settings, keyEquivalent: ",")
        settingsItem.target = target
        menu.addItem(settingsItem)
        if let updates {
            let updatesItem = NSMenuItem(title: "Check for Updates…", action: #selector(UpdatesMenuTarget.check(_:)), keyEquivalent: "")
            let target = UpdatesMenuTarget(updates)
            updatesItem.target = target
            // NSMenuItem holds its target weakly; the item keeps it alive.
            updatesItem.representedObject = target
            menu.addItem(updatesItem)
        }
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

/// Target for the "Check for Updates…" item.
@MainActor
final class UpdatesMenuTarget: NSObject {
    private let updates: any UpdateChecking

    init(_ updates: any UpdateChecking) {
        self.updates = updates
    }

    @objc func check(_ sender: Any?) {
        updates.checkForUpdatesInteractively()
    }
}
