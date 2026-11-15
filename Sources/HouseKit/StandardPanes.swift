import AppKit
import SwiftUI

// The General and About panes every app has, in the SwiftUI shell.

// MARK: - Updates

/// What the Updates section needs from an app's update checker. Each app
/// keeps its own feed and installer; it adds a small conformance.
/// The checker must be `@Observable` so the section redraws on change.
@MainActor
public protocol UpdateChecking: AnyObject, Observable {
    /// The running version, e.g. "0.5.1".
    var installedVersion: String { get }
    /// The newest version the feed named. Nil before the first check.
    var latestVersion: String? { get }
    /// A newer version that this copy can install. Nil when up to date.
    var availableVersion: String? { get }
    var isChecking: Bool { get }
    var lastChecked: Date? { get }
    /// A short reason the last check failed. Nil when it worked.
    var lastError: String? { get }
    /// The automatic check switch.
    var automaticChecks: Bool { get set }
    /// False when this copy must not replace itself (not in /Applications).
    var canInstall: Bool { get }
    /// One sentence on how the app checks, e.g. "Sift asks GitHub once a day…".
    var policyNote: String { get }
    func checkForUpdates() async
    func installUpdate() throws
}

/// "Updates" section: this version, latest, automatic switch, Check Now,
/// Install. Put it in General (see `GeneralSettingsPane`) or in any Form.
public struct UpdatesSection: View {
    private let checker: any UpdateChecking
    @State private var installMessage: String?

    public init(checker: any UpdateChecking) {
        self.checker = checker
    }

    public var body: some View {
        Section {
            LabeledContent("This version") {
                Text(checker.installedVersion).foregroundStyle(.secondary).textSelection(.enabled)
            }
            LabeledContent("Latest") {
                Text(checker.latestVersion ?? "Not checked yet").foregroundStyle(.secondary).textSelection(.enabled)
            }
            Toggle("Check for updates automatically", isOn: Binding(
                get: { checker.automaticChecks },
                set: { checker.automaticChecks = $0 }
            ))
            HStack {
                Button(checker.isChecking ? "Checking…" : "Check Now") {
                    Task { await checker.checkForUpdates() }
                }
                .disabled(checker.isChecking)
                if let version = checker.availableVersion, checker.canInstall {
                    Button("Update to \(version)") {
                        do {
                            try checker.installUpdate()
                        } catch {
                            installMessage = error.localizedDescription
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                if checker.isChecking { ProgressView().controlSize(.small) }
            }
        } header: {
            Text("Updates")
        } footer: {
            Text(footer)
        }
    }

    private var footer: String {
        if let installMessage { return installMessage }
        if !checker.canInstall { return "Only the copy in Applications updates itself. This copy runs from somewhere else." }
        if let error = checker.lastError { return "The last check failed: \(error)" }
        if checker.availableVersion == nil, checker.lastChecked != nil { return "This is the latest version." }
        return checker.policyNote
    }
}

// MARK: - General

/// The General pane: launch at login, menu bar icon, permissions, updates,
/// then the app's own sections.
public struct GeneralSettingsPane<Extras: View>: View {
    private let launchAtLogin: Binding<Bool>?
    private let showMenuBarIcon: Binding<Bool>?
    private let permissions: [PermissionRow]
    private let updates: (any UpdateChecking)?
    private let extras: Extras

    @State private var systemLaunchAtLogin = LaunchAtLogin.isRequested
    @State private var needsApproval = LaunchAtLogin.needsApproval
    @State private var launchMessage: String?
    @State private var tick = 0

    /// - Parameters:
    ///   - launchAtLogin: The app's stored preference, for apps that apply it
    ///     to `LaunchAtLogin` themselves. Nil reads and writes `SMAppService`
    ///     directly, as Headroom does.
    ///   - showMenuBarIcon: Nil hides the row.
    ///   - permissions: Live rows with a button into System Settings.
    ///   - updates: Nil hides the Updates section.
    ///   - extras: More `Section`s, after the standard ones.
    public init(
        launchAtLogin: Binding<Bool>? = nil,
        showMenuBarIcon: Binding<Bool>? = nil,
        permissions: [PermissionRow] = [],
        updates: (any UpdateChecking)? = nil,
        @ViewBuilder extras: () -> Extras
    ) {
        self.launchAtLogin = launchAtLogin
        self.showMenuBarIcon = showMenuBarIcon
        self.permissions = permissions
        self.updates = updates
        self.extras = extras()
    }

    public var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: launchBinding)
                if needsApproval {
                    Button("Open Login Items Settings…") { LaunchAtLogin.openLoginItemsSettings() }
                }
                if let showMenuBarIcon {
                    Toggle("Show menu bar icon", isOn: showMenuBarIcon)
                }
            } header: {
                Text("Startup")
            } footer: {
                if let launchMessage {
                    Text(launchMessage)
                } else if needsApproval {
                    Text("macOS waits for you to allow the app in Login Items.")
                }
            }

            if !permissions.isEmpty {
                Section("Permissions") {
                    ForEach(Array(permissions.enumerated()), id: \.offset) { _, permission in
                        PermissionStatusRow(permission: permission, tick: tick)
                    }
                }
            }

            if let updates {
                UpdatesSection(checker: updates)
            }

            extras
        }
        .formStyle(.grouped)
        .task {
            // Grants change in System Settings, outside the app: read again each second.
            while !Task.isCancelled {
                refreshLaunchState()
                tick &+= 1
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private var launchBinding: Binding<Bool> {
        if let launchAtLogin {
            return Binding(
                get: { launchAtLogin.wrappedValue },
                set: { launchAtLogin.wrappedValue = $0; refreshLaunchState() }
            )
        }
        return Binding(
            get: { systemLaunchAtLogin },
            set: { setSystemLaunchAtLogin($0) }
        )
    }

    private func setSystemLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLogin.setEnabled(enabled)
            launchMessage = nil
        } catch {
            launchMessage = error.localizedDescription
        }
        refreshLaunchState()
    }

    private func refreshLaunchState() {
        systemLaunchAtLogin = LaunchAtLogin.isRequested
        needsApproval = LaunchAtLogin.needsApproval
    }
}

extension GeneralSettingsPane where Extras == EmptyView {
    public init(
        launchAtLogin: Binding<Bool>? = nil,
        showMenuBarIcon: Binding<Bool>? = nil,
        permissions: [PermissionRow] = [],
        updates: (any UpdateChecking)? = nil
    ) {
        self.init(
            launchAtLogin: launchAtLogin,
            showMenuBarIcon: showMenuBarIcon,
            permissions: permissions,
            updates: updates
        ) { EmptyView() }
    }
}

private struct PermissionStatusRow: View {
    let permission: PermissionRow
    /// Changes every second, so the row reads the grant again.
    let tick: Int

    var body: some View {
        let granted = permission.isGranted()
        LabeledContent(permission.title) {
            HStack(spacing: 8) {
                Label(granted ? permission.grantedText : permission.missingText,
                      systemImage: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(granted ? .green : .orange)
                if !granted {
                    Button("Open System Settings…") { permission.openSettings() }
                }
            }
        }
    }
}

// MARK: - About

/// A link on the About pane.
public struct AboutLink: Identifiable, Sendable {
    public let title: String
    public let url: URL
    public var id: String { url.absoluteString }

    public init(_ title: String, url: URL) {
        self.title = title
        self.url = url
    }
}

/// The About pane: icon, name, version (build), tagline, changelog, GitHub
/// source and stars, more links, and the executable path.
public struct AboutSettingsPane<Extras: View>: View {
    private let appName: String
    private let tagline: String?
    private let credit: String?
    private let repository: String?
    private let links: [AboutLink]
    private let changelog: ChangelogDocument?
    private let showsExecutable: Bool
    private let extras: Extras

    @State private var starCount: Int?
    @State private var showingChangelog = false

    /// - Parameters:
    ///   - repository: "owner/name" on GitHub. Adds "Source on GitHub", the
    ///     live star count and the online changelog link.
    ///   - links: More links, e.g. Community Pulse.
    ///   - changelog: Defaults to the bundled `CHANGELOG.md`. Nil hides the button.
    ///   - showsExecutable: Shows the binary path. The Accessibility grant
    ///     binds to one exact executable, so this tells Xcode and script builds apart.
    public init(
        appName: String,
        tagline: String? = nil,
        credit: String? = nil,
        repository: String? = nil,
        links: [AboutLink] = [],
        changelog: ChangelogDocument? = Changelog.load(),
        showsExecutable: Bool = false,
        @ViewBuilder extras: () -> Extras
    ) {
        self.appName = appName
        self.tagline = tagline
        self.credit = credit
        self.repository = repository
        self.links = links
        self.changelog = changelog
        self.showsExecutable = showsExecutable
        self.extras = extras()
    }

    private var repositoryURL: URL? {
        repository.flatMap { URL(string: "https://github.com/\($0)") }
    }

    public var body: some View {
        Form {
            Section {
                header
            }
            if showsExecutable {
                Section("Build") {
                    LabeledContent("Executable") {
                        Text(Bundle.main.executablePath ?? "Unknown")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            extras
        }
        .formStyle(.grouped)
        .task { await loadStarCount() }
        .sheet(isPresented: $showingChangelog) {
            NavigationStack {
                ChangelogView(document: changelog, onlineURL: changelogURL)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingChangelog = false }
                        }
                    }
            }
            .frame(minWidth: 480, minHeight: 420)
        }
    }

    private var changelogURL: URL? {
        repositoryURL?.appendingPathComponent("blob/main/CHANGELOG.md")
    }

    private var header: some View {
        VStack(spacing: 6) {
            Image(nsImage: Self.appIcon)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)
            Text(appName).font(.headline)
            Text(BuildInfo.aboutLabel).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            if let tagline {
                Text(tagline).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            if let credit {
                Text(credit).font(.caption).foregroundStyle(.tertiary).multilineTextAlignment(.center)
            }
            VStack(spacing: 4) {
                if changelog != nil {
                    Button("Changelog") { showingChangelog = true }
                        .font(.caption.weight(.medium))
                        .buttonStyle(.plain)
                        .foregroundStyle(.tint)
                }
                if let repositoryURL {
                    Link(destination: repositoryURL) {
                        Text("Source on GitHub").font(.caption.weight(.medium))
                    }
                    if let starCount {
                        Text(starCount == 1 ? "1 star" : "\(starCount) stars")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                ForEach(links) { link in
                    Link(destination: link.url) {
                        Text(link.title).font(.caption.weight(.medium))
                    }
                }
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    /// `AboutAppIcon` from the asset catalog when the app has one. An
    /// `LSUIElement` app can get the generic icon from `applicationIconImage`.
    private static var appIcon: NSImage {
        NSImage(named: "AboutAppIcon") ?? NSApp.applicationIconImage
    }

    private func loadStarCount() async {
        guard let repository, let url = URL(string: "https://api.github.com/repos/\(repository)") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        // Not returnCacheDataElseLoad: it ignores expiry and keeps the first
        // count forever. The protocol policy obeys GitHub's max-age=60.
        request.cachePolicy = .useProtocolCachePolicy
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let payload = try? JSONDecoder().decode(GitHubStars.self, from: data)
        else { return }
        starCount = payload.stargazersCount
    }
}

extension AboutSettingsPane where Extras == EmptyView {
    public init(
        appName: String,
        tagline: String? = nil,
        credit: String? = nil,
        repository: String? = nil,
        links: [AboutLink] = [],
        changelog: ChangelogDocument? = Changelog.load(),
        showsExecutable: Bool = false
    ) {
        self.init(
            appName: appName, tagline: tagline, credit: credit, repository: repository,
            links: links, changelog: changelog, showsExecutable: showsExecutable
        ) { EmptyView() }
    }
}

private struct GitHubStars: Decodable {
    let stargazersCount: Int

    enum CodingKeys: String, CodingKey {
        case stargazersCount = "stargazers_count"
    }
}

// MARK: - Registry shortcuts

extension SettingsPane {
    /// The standard ids, so `show(pane:)` callers do not spell them by hand.
    public static let generalID = "general"
    public static let aboutID = "about"

    /// General, id "general", symbol "gearshape".
    public static func general<Content: View>(@ViewBuilder _ content: @escaping @MainActor () -> Content) -> SettingsPane {
        SettingsPane(id: generalID, title: "General", symbol: "gearshape", content: content)
    }

    /// About, id "about", symbol "info.circle".
    public static func about<Content: View>(@ViewBuilder _ content: @escaping @MainActor () -> Content) -> SettingsPane {
        SettingsPane(id: aboutID, title: "About", symbol: "info.circle", content: content)
    }
}
