import AppKit
import SwiftUI

// The house settings shell (the Headroom shape): a fixed 220 pt sidebar of
// panes and a grouped `Form` on the right. Convention: General first, the
// app's own panes after it, About last.

/// One sidebar row and the pane it opens.
public struct SettingsPane: Identifiable {
    /// Stable id. `HouseSettingsWindowController.show(pane:)` selects by it.
    public let id: String
    public let title: String
    /// SF Symbol name for the sidebar row.
    public let symbol: String
    let content: @MainActor () -> AnyView

    /// - Parameter content: The pane body. Usually a `Form { Section … }`;
    ///   the shell applies `.formStyle(.grouped)`.
    public init<Content: View>(
        id: String,
        title: String,
        symbol: String,
        @ViewBuilder content: @escaping @MainActor () -> Content
    ) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.content = { AnyView(content()) }
    }
}

/// A page pushed on top of a pane, with its own Back button in the title bar.
/// Example: one integration under an Integrations pane.
public struct SettingsLeaf: Identifiable, Hashable {
    public let id: String
    public let title: String
    let content: @MainActor () -> AnyView

    public init<Content: View>(id: String, title: String, @ViewBuilder content: @escaping @MainActor () -> Content) {
        self.id = id
        self.title = title
        self.content = { AnyView(content()) }
    }

    public static func == (lhs: SettingsLeaf, rhs: SettingsLeaf) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Which pane and leaf the shell shows. Hold one to select a pane from
/// outside the view (a menu item, a deep link).
@MainActor
@Observable
public final class SettingsNavigation {
    public var selection: String?
    public var leaf: SettingsLeaf?

    public init(selection: String? = nil) {
        self.selection = selection
    }

    /// Selects a pane and drops any pushed leaf.
    public func show(pane id: String) {
        leaf = nil
        selection = id
    }

    public func push(_ leaf: SettingsLeaf) {
        self.leaf = leaf
    }

    public func pop() {
        leaf = nil
    }
}

extension EnvironmentValues {
    /// The shell's navigation. Panes read it to push a leaf.
    @Entry public var settingsNavigation: SettingsNavigation? = nil
}

/// A row that pushes a leaf: label on the left, chevron on the right.
public struct SettingsLeafLink<Label: View>: View {
    @Environment(\.settingsNavigation) private var navigation
    private let leaf: SettingsLeaf
    private let label: Label

    public init(_ leaf: SettingsLeaf, @ViewBuilder label: () -> Label) {
        self.leaf = leaf
        self.label = label()
    }

    public var body: some View {
        Button {
            navigation?.push(leaf)
        } label: {
            HStack {
                label
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension SettingsLeafLink where Label == SwiftUI.Label<Text, Image> {
    /// A row with the leaf's title and an SF Symbol.
    public init(_ leaf: SettingsLeaf, symbol: String) {
        self.init(leaf) { SwiftUI.Label(leaf.title, systemImage: symbol) }
    }
}

/// The sidebar + detail scaffold. Use it in a SwiftUI `Settings` scene, or
/// through `HouseSettingsWindowController` in an AppKit menu-bar app.
public struct HouseSettingsView: View {
    public static let sidebarWidth: CGFloat = 220
    public static let defaultSize = CGSize(width: 820, height: 600)

    private let appName: String
    private let panes: [SettingsPane]
    private let size: CGSize
    private let floats: Bool
    private let external: SettingsNavigation?
    @State private var owned = SettingsNavigation()
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    /// - Parameters:
    ///   - appName: The window title reads "<appName> Settings".
    ///   - panes: Sidebar order. General first, About last.
    ///   - navigation: Pass one to select panes from outside the view. Without
    ///     it the view keeps its own.
    ///   - size: Fixed content size. Headroom uses 820 × 600.
    ///   - floats: Keeps the window above other windows, as Headroom does, so
    ///     a menu-bar app's settings do not disappear behind the front app.
    public init(
        appName: String,
        panes: [SettingsPane],
        navigation: SettingsNavigation? = nil,
        size: CGSize = HouseSettingsView.defaultSize,
        floats: Bool = true
    ) {
        self.appName = appName
        self.panes = panes
        self.external = navigation
        self.size = size
        self.floats = floats
    }

    private var navigation: SettingsNavigation { external ?? owned }

    private var selection: Binding<String?> {
        let navigation = navigation
        return Binding(get: { navigation.selection }, set: { navigation.selection = $0 })
    }

    private var current: SettingsPane? {
        panes.first { $0.id == navigation.selection } ?? panes.first
    }

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: selection) {
                Section {
                    ForEach(panes) { pane in
                        Label(pane.title, systemImage: pane.symbol).tag(pane.id)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Settings")
            .toolbar(removing: .sidebarToggle)
            .navigationSplitViewColumnWidth(min: Self.sidebarWidth, ideal: Self.sidebarWidth, max: Self.sidebarWidth)
        } detail: {
            Group {
                if let leaf = navigation.leaf {
                    leaf.content()
                        .navigationTitle(leaf.title)
                        .toolbar {
                            ToolbarItem(placement: .navigation) {
                                Button {
                                    navigation.pop()
                                } label: {
                                    Image(systemName: "chevron.left")
                                }
                                .help("Back to \(current?.title ?? "Settings")")
                            }
                        }
                } else if let pane = current {
                    pane.content()
                        .navigationTitle(pane.title)
                }
            }
            // A new identity per pane and leaf, so a sidebar click always
            // rebuilds the detail. Without it SwiftUI can keep the previous
            // pane's body when the selection change races a leftover leaf.
            .id(navigation.leaf.map { "leaf-\($0.id)" } ?? "pane-\(current?.id ?? "")")
        }
        .frame(width: size.width, height: size.height)
        .formStyle(.grouped)
        .environment(\.settingsNavigation, navigation)
        .background(SettingsWindowConfigurator(title: "\(appName) Settings", floats: floats))
        .onAppear {
            if navigation.selection == nil { navigation.selection = panes.first?.id }
        }
        .onChange(of: navigation.selection) { _, _ in
            // The sidebar changed the pane: drop the leaf so Back does not
            // point at a pane that is no longer selected. Do not put a tap
            // gesture on sidebar rows: on macOS it races List(selection:).
            navigation.leaf = nil
        }
    }
}

/// Makes the window that hosts the shell behave like a settings window in a
/// menu-bar app: titled, does not hide on deactivate, moves to the active
/// Space, comes to the front.
struct SettingsWindowConfigurator: NSViewRepresentable {
    let title: String
    let floats: Bool

    func makeNSView(context: Context) -> NSView {
        SettingsWindowObserverView(title: title, floats: floats)
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class SettingsWindowObserverView: NSView {
    private let title: String
    private let floats: Bool

    init(title: String, floats: Bool) {
        self.title = title
        self.floats = floats
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        window.title = title
        if floats { window.level = .floating }
        window.hidesOnDeactivate = false
        window.collectionBehavior.insert(.moveToActiveSpace)
        window.styleMask.insert([.titled, .closable, .miniaturizable])
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

/// The shell in its own window, for AppKit menu-bar apps that have no
/// SwiftUI `Settings` scene. Open it from ⌘, in the status menu and on reopen.
@MainActor
public final class HouseSettingsWindowController: NSWindowController {
    public let navigation: SettingsNavigation

    public init(
        appName: String,
        panes: [SettingsPane],
        size: CGSize = HouseSettingsView.defaultSize,
        floats: Bool = true
    ) {
        let navigation = SettingsNavigation(selection: panes.first?.id)
        self.navigation = navigation
        let host = NSHostingController(rootView: HouseSettingsView(
            appName: appName, panes: panes, navigation: navigation, size: size, floats: floats
        ))
        // Lets the split view put the sidebar title, the Back button and the
        // pane title into the window's own toolbar.
        host.sceneBridgingOptions = [.toolbars, .title]
        let window = NSWindow(contentViewController: host)
        window.title = "\(appName) Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.toolbarStyle = .unified
        window.setFrameAutosaveName("\(appName).Settings")
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError() }

    /// Brings the window to the front, optionally on a given pane id.
    public func show(pane id: String? = nil) {
        if let id { navigation.show(pane: id) }
        if window?.isVisible != true, window?.setFrameUsingName(window?.frameAutosaveName ?? "") != true {
            window?.center()
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
