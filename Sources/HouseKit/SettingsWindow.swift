import AppKit

/// One page in the settings sidebar.
@MainActor
public struct SettingsPage {
    public let title: String
    public let symbol: String
    public let controller: NSViewController

    public init(_ title: String, symbol: String, controller: NSViewController) {
        self.title = title
        self.symbol = symbol
        self.controller = controller
    }
}

/// The house settings window: source-list sidebar on the left, one page on
/// the right, "<App> Settings" title. Every app opens it from ⌘, in the
/// status menu. Convention: app pages first, then `GeneralPage`, then `AboutPage`.
@MainActor
public final class SettingsWindowController: NSWindowController {
    private let split = SettingsSplitViewController()

    public init(appName: String, pages: [SettingsPage], size: NSSize = NSSize(width: 720, height: 500)) {
        split.pages = pages
        let window = NSWindow(contentViewController: split)
        window.title = "\(appName) Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarSeparatorStyle = .automatic
        window.toolbarStyle = .unified
        window.toolbar = NSToolbar(identifier: "housekit.settings.toolbar")
        window.toolbar?.showsBaselineSeparator = false
        window.setContentSize(size)
        window.contentMinSize = NSSize(width: 600, height: 400)
        window.setFrameAutosaveName("\(appName).Settings")
        window.collectionBehavior = [.moveToActiveSpace]
        window.isReleasedWhenClosed = false
        // Pages are swapped in and out; the loop is rebuilt on every swap (see show(index:)).
        window.autorecalculatesKeyViewLoop = true
        super.init(window: window)
        split.select(index: 0)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError() }

    public func show(page index: Int? = nil) {
        if let index { split.select(index: index) }
        if window?.isVisible != true, window?.frameAutosaveName.isEmpty != false { window?.center() }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        split.focusFirstControl()
    }
}

@MainActor
private final class SettingsSplitViewController: NSSplitViewController {
    var pages: [SettingsPage] = [] {
        didSet { sidebar.pages = pages }
    }
    private let sidebar = SettingsSidebarController()
    private let detail = NSViewController()

    override func viewDidLoad() {
        super.viewDidLoad()
        detail.view = NSView()
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebar)
        sidebarItem.minimumThickness = 170
        sidebarItem.maximumThickness = 220
        sidebarItem.canCollapse = false
        addSplitViewItem(sidebarItem)
        addSplitViewItem(NSSplitViewItem(viewController: detail))
        sidebar.onSelect = { [weak self] index in self?.show(index: index) }
    }

    func select(index: Int) {
        _ = view
        sidebar.select(index: index)
    }

    private func show(index: Int) {
        guard pages.indices.contains(index) else { return }
        for child in detail.children {
            child.view.removeFromSuperview()
            child.removeFromParent()
        }
        let page = pages[index].controller
        detail.addChild(page)
        page.view.translatesAutoresizingMaskIntoConstraints = false
        detail.view.addSubview(page.view)
        NSLayoutConstraint.activate([
            page.view.topAnchor.constraint(equalTo: detail.view.topAnchor),
            page.view.bottomAnchor.constraint(equalTo: detail.view.bottomAnchor),
            page.view.leadingAnchor.constraint(equalTo: detail.view.leadingAnchor),
            page.view.trailingAnchor.constraint(equalTo: detail.view.trailingAnchor)
        ])
        page.view.layoutSubtreeIfNeeded()
        view.window?.recalculateKeyViewLoop()
        focusFirstControl()
    }

    /// Tab starts at the page's first control, not in the sidebar.
    func focusFirstControl() {
        guard let window = view.window, let page = detail.children.first?.view else { return }
        page.layoutSubtreeIfNeeded()
        window.recalculateKeyViewLoop()
        if let first = Self.firstKeyView(in: page) {
            window.initialFirstResponder = first
            window.makeFirstResponder(first)
        }
    }

    /// Depth-first, in layout order (top to bottom), the first view that takes keyboard focus.
    private static func firstKeyView(in view: NSView) -> NSView? {
        let ordered = view.subviews.sorted { a, b in
            let fa = a.superview!.convert(a.frame, to: nil), fb = b.superview!.convert(b.frame, to: nil)
            return fa.maxY == fb.maxY ? fa.minX < fb.minX : fa.maxY > fb.maxY
        }
        for child in ordered where !child.isHidden {
            if child.canBecomeKeyView, child is NSControl || child is NSTextView { return child }
            if let nested = firstKeyView(in: child) { return nested }
        }
        return nil
    }
}

@MainActor
private final class SettingsSidebarController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    var pages: [SettingsPage] = [] {
        didSet { table.reloadData() }
    }
    var onSelect: (Int) -> Void = { _ in }
    private let table = NSTableView()

    override func loadView() {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("page"))
        table.addTableColumn(column)
        table.headerView = nil
        table.style = .sourceList
        table.rowHeight = 28
        table.allowsEmptySelection = false
        // Navigate with the mouse or ⌘1…; Tab stays inside the page.
        table.refusesFirstResponder = true
        table.dataSource = self
        table.delegate = self
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        view = scroll
    }

    func select(index: Int) {
        _ = view
        // The table has no rows until it has loaded once; selecting before
        // that is a no-op and the detail stays blank.
        if table.numberOfRows != pages.count { table.reloadData() }
        table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        if table.selectedRow == index { onSelect(index) }
    }

    func numberOfRows(in tableView: NSTableView) -> Int { pages.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("SidebarRow")
        let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView ?? {
            let cell = NSTableCellView()
            cell.identifier = identifier
            let image = NSImageView()
            image.translatesAutoresizingMaskIntoConstraints = false
            let text = NSTextField(labelWithString: "")
            text.translatesAutoresizingMaskIntoConstraints = false
            text.lineBreakMode = .byTruncatingTail
            cell.addSubview(image)
            cell.addSubview(text)
            cell.imageView = image
            cell.textField = text
            NSLayoutConstraint.activate([
                image.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                image.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                image.widthAnchor.constraint(equalToConstant: 20),
                text.leadingAnchor.constraint(equalTo: image.trailingAnchor, constant: 6),
                text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                text.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
            return cell
        }()
        let page = pages[row]
        cell.textField?.stringValue = page.title
        cell.imageView?.image = NSImage(systemSymbolName: page.symbol, accessibilityDescription: page.title)?
            .withSymbolConfiguration(.init(pointSize: 14, weight: .medium))
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard table.selectedRow >= 0 else { return }
        onSelect(table.selectedRow)
    }
}
