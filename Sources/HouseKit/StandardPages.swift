import AppKit

/// A permission the app needs (Accessibility, Notifications…), shown as a
/// live status row with a button into System Settings.
public struct PermissionRow: Sendable {
    public let title: String
    public let grantedText: String
    public let missingText: String
    public let isGranted: @Sendable @MainActor () -> Bool
    public let openSettings: @Sendable @MainActor () -> Void

    public init(
        title: String,
        grantedText: String,
        missingText: String,
        isGranted: @escaping @Sendable @MainActor () -> Bool,
        openSettings: @escaping @Sendable @MainActor () -> Void
    ) {
        self.title = title
        self.grantedText = grantedText
        self.missingText = missingText
        self.isGranted = isGranted
        self.openSettings = openSettings
    }

    public static let accessibility = PermissionRow(
        title: "Accessibility",
        grantedText: "Granted",
        missingText: "Not granted",
        isGranted: { AXIsProcessTrusted() },
        openSettings: {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    )
}

/// The General page every app has: launch at login, menu bar icon,
/// permissions. App-specific rows go in `extras`, after the standard ones.
@MainActor
public final class GeneralPage: SettingsForm {
    private let launchAtLogin: (get: () -> Bool, set: (Bool) -> Void)
    private let showMenuBarIcon: (get: () -> Bool, set: (Bool) -> Void)?
    private let permissions: [PermissionRow]
    private let extras: (SettingsForm) -> Void
    private var launchSwitch: NSSwitch?
    private var menuBarSwitch: NSSwitch?
    private var permissionViews: [(PermissionRow, NSStackView, NSButton)] = []
    private var pollTimer: Timer?

    public init(
        launchAtLogin: (get: () -> Bool, set: (Bool) -> Void),
        showMenuBarIcon: (get: () -> Bool, set: (Bool) -> Void)? = nil,
        permissions: [PermissionRow] = [],
        extras: @escaping (SettingsForm) -> Void = { _ in }
    ) {
        self.launchAtLogin = launchAtLogin
        self.showMenuBarIcon = showMenuBarIcon
        self.permissions = permissions
        self.extras = extras
        super.init()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        section("Startup")
        launchSwitch = toggle("Launch at login", isOn: launchAtLogin.get()) { [launchAtLogin] in launchAtLogin.set($0) }
        if let showMenuBarIcon {
            menuBarSwitch = toggle("Show menu bar icon", isOn: showMenuBarIcon.get()) { showMenuBarIcon.set($0) }
        }
        if !permissions.isEmpty {
            section("Permissions")
            for permission in permissions {
                let status = SettingsForm.status("", ok: false)
                let button = SettingsForm.button("Open System Settings…", target: nil, action: nil)
                button.target = self
                button.action = #selector(openPermissionSettings(_:))
                button.tag = permissionViews.count
                row(permission.title, [status, button])
                permissionViews.append((permission, status, button))
            }
        }
        extras(self)
    }

    public override func viewWillAppear() {
        super.viewWillAppear()
        refresh()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    public override func viewDidDisappear() {
        super.viewDidDisappear()
        pollTimer?.invalidate()
        pollTimer = nil
    }

    /// Re-reads the getters — call after settings change elsewhere (the status menu toggle).
    public func refresh() {
        launchSwitch?.state = launchAtLogin.get() ? .on : .off
        if let showMenuBarIcon { menuBarSwitch?.state = showMenuBarIcon.get() ? .on : .off }
        for (permission, stack, button) in permissionViews {
            let granted = permission.isGranted()
            (stack.views[1] as? NSTextField)?.stringValue = granted ? permission.grantedText : permission.missingText
            (stack.views[0] as? NSImageView)?.image = NSImage(
                systemSymbolName: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                accessibilityDescription: nil
            )?.withSymbolConfiguration(.init(pointSize: 12, weight: .medium))
            (stack.views[0] as? NSImageView)?.contentTintColor = granted ? .systemGreen : .systemOrange
            button.isHidden = granted
        }
    }

    @objc private func openPermissionSettings(_ sender: NSButton) {
        guard permissionViews.indices.contains(sender.tag) else { return }
        permissionViews[sender.tag].0.openSettings()
    }
}

/// The About page every app has: icon, name, version, where the binary is
/// (the Accessibility grant binds to one exact executable, so this saves
/// confusion between Xcode and script builds), and links.
@MainActor
public final class AboutPage: SettingsForm {
    private let appName: String
    private let tagline: String?
    private let links: [(title: String, url: URL)]
    private let extras: (SettingsForm) -> Void

    public init(
        appName: String,
        tagline: String? = nil,
        links: [(title: String, url: URL)] = [],
        extras: @escaping (SettingsForm) -> Void = { _ in }
    ) {
        self.appName = appName
        self.tagline = tagline
        self.links = links
        self.extras = extras
        super.init()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.widthAnchor.constraint(equalToConstant: 64).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 64).isActive = true
        let name = SettingsForm.label(appName, font: .systemFont(ofSize: 22, weight: .semibold))
        let version = SettingsForm.caption(BuildInfo.label)
        let column = NSStackView(views: [name, version] + (tagline.map { [SettingsForm.label($0, color: .secondaryLabelColor)] } ?? []))
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 2
        let header = NSStackView(views: [icon, column])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 14
        grid.addRow(with: [header, NSGridCell.emptyContentView])
        grid.row(at: 0).mergeCells(in: NSRange(location: 0, length: 2))
        grid.row(at: 0).cell(at: 0).xPlacement = .leading
        grid.row(at: 0).bottomPadding = 8

        section("Build")
        row("Version", SettingsForm.label(BuildInfo.label))
        let path = SettingsForm.label(Bundle.main.executablePath ?? "—", font: .systemFont(ofSize: 11), color: .secondaryLabelColor, wraps: true)
        path.isSelectable = true
        path.preferredMaxLayoutWidth = SettingsForm.contentWidth
        row("Executable", path)
        if !links.isEmpty {
            section("Links")
            for (index, link) in links.enumerated() {
                let button = SettingsForm.button(link.title, target: self, action: #selector(openLink(_:)))
                button.tag = index
                row(nil, button)
            }
        }
        extras(self)
    }

    @objc private func openLink(_ sender: NSButton) {
        guard links.indices.contains(sender.tag) else { return }
        NSWorkspace.shared.open(links[sender.tag].url)
    }
}
