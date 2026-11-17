import AppKit
import Foundation
import HouseKit
import Observation
@preconcurrency import Sparkle

/// Sparkle behind HouseKit's `UpdateChecking`, so `UpdatesSection`,
/// `GeneralSettingsPane(updates:)` and `StatusMenu.appendStandardTail(updates:)`
/// work the same in every app.
///
/// An app opts in with two Info.plist keys and one instance:
///
///     SUFeedURL       https://github.com/michellzappa/<repo>/releases/latest/download/appcast.xml
///     SUPublicEDKey   <the app's EdDSA public key>
///
///     let updates = SparkleUpdater()
///
/// The shared release workflow (`.github/workflows/release-mac.yml` in this
/// repo) signs each zip with the matching private key and attaches
/// `appcast.xml` to the GitHub Release. Sparkle checks the EdDSA signature
/// and Apple's code signature before it installs anything.
///
/// The updater starts only in a copy that can replace itself: in
/// /Applications, with both keys present. A build from Xcode, a worktree or
/// the mini never offers to overwrite the installed app.
@MainActor
@Observable
public final class SparkleUpdater: UpdateChecking {
    public let installedVersion: String
    public private(set) var latestVersion: String?
    public private(set) var availableVersion: String?
    public private(set) var isChecking = false
    public private(set) var lastChecked: Date?
    public private(set) var lastError: String?
    public let canInstall: Bool
    public let policyNote: String

    @ObservationIgnored private var controller: SPUStandardUpdaterController?
    @ObservationIgnored private let bridge = DelegateBridge()
    @ObservationIgnored private var waiting: [CheckedContinuation<Void, Never>] = []

    /// - Parameters:
    ///   - appName: Used in the policy note. Defaults to the bundle name.
    ///   - enabled: False keeps Sparkle off, for example in a demo mode.
    ///   - bundle: The app bundle. Tests pass another one.
    public init(appName: String? = nil, enabled: Bool = true, bundle: Bundle = .main) {
        let name = appName
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "The app"
        installedVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        policyNote = "\(name) checks GitHub for a signed update once a day. Sparkle checks the update's signature and Apple's notarization, then installs it and opens \(name) again."

        let config = SparkleConfig(bundle: bundle)
        canInstall = enabled && config.isComplete && SparkleConfig.isInApplications(bundle)
        if !config.isComplete {
            lastError = "This build has no update feed."
        }
        guard canInstall else { return }

        bridge.owner = self
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: bridge,
            userDriverDelegate: bridge
        )
        lastChecked = controller?.updater.lastUpdateCheckDate
    }

    public var automaticChecks: Bool {
        get {
            access(keyPath: \.automaticChecks)
            return controller?.updater.automaticallyChecksForUpdates ?? false
        }
        set {
            withMutation(keyPath: \.automaticChecks) {
                controller?.updater.automaticallyChecksForUpdates = newValue
            }
        }
    }

    /// Asks the feed without showing Sparkle's window. The Updates section
    /// shows the result.
    public func checkForUpdates() async {
        guard let updater = controller?.updater else { return }
        guard updater.canCheckForUpdates else { return }
        isChecking = true
        lastError = nil
        await withCheckedContinuation { continuation in
            waiting.append(continuation)
            updater.checkForUpdateInformation()
        }
    }

    /// Sparkle's own window: release notes, download, install, relaunch.
    public func installUpdate() throws {
        guard let controller else { throw UpdateError.unavailable }
        controller.checkForUpdates(nil)
    }

    /// "Check for Updates…" in a menu: Sparkle's window, which also says
    /// "up to date".
    public func checkForUpdatesInteractively() {
        controller?.checkForUpdates(nil)
    }

    // MARK: Delegate results, on the main thread

    fileprivate func found(version: String) {
        latestVersion = version
        availableVersion = version
    }

    fileprivate func foundNothing(latest: String?) {
        latestVersion = latest ?? installedVersion
        availableVersion = nil
    }

    fileprivate func finished(error: String?) {
        isChecking = false
        lastChecked = controller?.updater.lastUpdateCheckDate ?? Date()
        lastError = error
        let resume = waiting
        waiting = []
        resume.forEach { $0.resume() }
    }

    public enum UpdateError: LocalizedError {
        case unavailable
        public var errorDescription: String? {
            "Updates are off in this copy. Only the copy in Applications updates itself."
        }
    }
}

/// The Info.plist keys Sparkle needs. Without both, starting Sparkle shows an
/// error window, so the updater stays off instead.
struct SparkleConfig {
    let feedURL: URL?
    let publicKey: String?

    init(bundle: Bundle) {
        feedURL = (bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String).flatMap(URL.init(string:))
        let key = (bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String)?
            .trimmingCharacters(in: .whitespaces)
        publicKey = key?.isEmpty == false ? key : nil
    }

    var isComplete: Bool {
        guard let feedURL, feedURL.scheme == "https", let publicKey else { return false }
        // An Ed25519 public key is 32 bytes.
        return Data(base64Encoded: publicKey)?.count == 32
    }

    static func isInApplications(_ bundle: Bundle) -> Bool {
        bundle.bundleURL.resolvingSymlinksInPath().deletingLastPathComponent().standardizedFileURL.path == "/Applications"
    }
}

/// Sparkle's delegates are Objective-C protocols without actor annotations.
/// Sparkle calls them on the main thread; this class hops to the main actor
/// and passes plain values on.
private final class DelegateBridge: NSObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate, @unchecked Sendable {
    @MainActor weak var owner: SparkleUpdater?

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let version = item.displayVersionString
        MainActor.assumeIsolated { owner?.found(version: version) }
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: any Error) {
        let latest = ((error as NSError).userInfo[SPULatestAppcastItemFoundKey] as? SUAppcastItem)?.displayVersionString
        MainActor.assumeIsolated { owner?.foundNothing(latest: latest) }
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        var message: String?
        if let error = error as NSError?,
           !(error.domain == SUSparkleErrorDomain && error.code == Int(SUError.noUpdateError.rawValue)) {
            message = error.localizedDescription
        }
        MainActor.assumeIsolated { owner?.finished(error: message) }
    }

    // Menu-bar apps (LSUIElement) have no Dock icon. Sparkle then shows a
    // scheduled update without stealing focus, and the Updates section and
    // the status menu show it too.
    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }
}
