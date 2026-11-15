import AppKit
import SwiftUI

/// Scrollable release notes from a `ChangelogDocument`. Ported from Headroom.
/// The About pane opens it as a sheet; `ChangelogWindow` opens it as a window
/// for a "What's New" menu item.
public struct ChangelogView: View {
    private let document: ChangelogDocument?
    private let onlineURL: URL?

    /// - Parameters:
    ///   - document: Defaults to the bundled `CHANGELOG.md`.
    ///   - onlineURL: Shown as a link when the document is missing or empty.
    public init(document: ChangelogDocument? = Changelog.load(), onlineURL: URL? = nil) {
        self.document = document
        self.onlineURL = onlineURL
    }

    public var body: some View {
        Group {
            if let document, !document.versions.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(document.versions) { version in
                            versionBlock(version)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ContentUnavailableView {
                    Label("No Release Notes", systemImage: "doc.text")
                } description: {
                    Text("This build does not include a changelog.")
                } actions: {
                    if let onlineURL {
                        Link("Changelog on GitHub", destination: onlineURL)
                    }
                }
            }
        }
        .navigationTitle("Changelog")
    }

    private func versionBlock(_ version: ChangelogVersion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(version.title)
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)

            ForEach(Array(version.sections.enumerated()), id: \.offset) { _, section in
                VStack(alignment: .leading, spacing: 6) {
                    if !section.title.isEmpty {
                        Text(section.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .padding(.top, 2)
                    }
                    ForEach(Array(section.items.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•").foregroundStyle(.secondary)
                            Self.markdown(item)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private static func markdown(_ source: String) -> Text {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        if let attributed = try? AttributedString(markdown: source, options: options) {
            return Text(attributed)
        }
        return Text(source)
    }
}

/// The changelog as its own window, for a "What's New…" menu item.
/// One window per app; a second call brings the open one to the front.
@MainActor
public enum ChangelogWindow {
    private static var controller: NSWindowController?

    public static func show(appName: String, document: ChangelogDocument? = Changelog.load(), onlineURL: URL? = nil) {
        if let window = controller?.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let host = NSHostingController(rootView: ChangelogView(document: document, onlineURL: onlineURL)
            .frame(minWidth: 480, idealWidth: 560, minHeight: 420, idealHeight: 600))
        let window = NSWindow(contentViewController: host)
        window.title = "\(appName) Changelog"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setFrameAutosaveName("\(appName).Changelog")
        window.collectionBehavior = [.moveToActiveSpace]
        window.isReleasedWhenClosed = false
        if window.frameAutosaveName.isEmpty || !window.setFrameUsingName(window.frameAutosaveName) { window.center() }
        controller = NSWindowController(window: window)
        controller?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
