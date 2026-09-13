import AppKit

/// One settings page: a two-column grid (label | control) with section
/// headers, in a scroll view. Controls save on change — no Save buttons.
/// Subclass and build rows in `viewDidLoad`, or use it directly.
@MainActor
open class SettingsForm: NSViewController {
    public let grid = NSGridView(numberOfColumns: 2, rows: 0)
    public static let labelColumnWidth: CGFloat = 160
    public static let contentWidth: CGFloat = 440

    public init() {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError() }

    open override func loadView() {
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 10
        grid.columnSpacing = 14
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 0).width = Self.labelColumnWidth
        grid.column(at: 1).xPlacement = .fill
        grid.rowAlignment = .firstBaseline

        let content = FlippedView()
        content.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(grid)

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.documentView = content
        NSLayoutConstraint.activate([
            content.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            grid.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            grid.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -20),
            grid.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20)
        ])
        view = scroll
    }

    // MARK: - Rows

    /// Bold section title spanning both columns.
    public func section(_ title: String) {
        let header = Self.label(title, font: .systemFont(ofSize: 13, weight: .semibold))
        grid.addRow(with: [header, NSGridCell.emptyContentView])
        let row = grid.row(at: grid.numberOfRows - 1)
        row.mergeCells(in: NSRange(location: 0, length: 2))
        row.cell(at: 0).xPlacement = .leading
        if grid.numberOfRows > 1 { row.topPadding = 16 }
    }

    /// `label | views…` laid out horizontally.
    @discardableResult
    public func row(_ title: String?, _ views: [NSView]) -> NSGridRow {
        let stack = NSStackView(views: views)
        stack.orientation = .horizontal
        stack.alignment = .firstBaseline
        stack.spacing = 8
        let label: NSView = title.map {
            let label = Self.label($0, color: .secondaryLabelColor, wraps: true)
            label.alignment = .right
            label.preferredMaxLayoutWidth = Self.labelColumnWidth
            return label
        } ?? NSGridCell.emptyContentView
        grid.addRow(with: [label, stack])
        return grid.row(at: grid.numberOfRows - 1)
    }

    @discardableResult
    public func row(_ title: String?, _ view: NSView) -> NSGridRow {
        row(title, [view])
    }

    /// A switch with its title on the left, like System Settings.
    @discardableResult
    public func toggle(_ title: String, isOn: Bool, onChange: @escaping (Bool) -> Void) -> NSSwitch {
        let control = NSSwitch()
        control.controlSize = .small
        control.state = isOn ? .on : .off
        control.target = ToggleTarget.shared
        control.action = #selector(ToggleTarget.changed(_:))
        ToggleTarget.shared.handlers[ObjectIdentifier(control)] = onChange
        let row = row(title, control)
        row.rowAlignment = .none
        row.yPlacement = .center
        return control
    }

    /// Small secondary text spanning both columns, wrapped.
    public func note(_ text: String) {
        let label = Self.label(text, font: .systemFont(ofSize: 11), color: .secondaryLabelColor, wraps: true)
        label.preferredMaxLayoutWidth = Self.labelColumnWidth + 14 + Self.contentWidth
        grid.addRow(with: [label, NSGridCell.emptyContentView])
        let row = grid.row(at: grid.numberOfRows - 1)
        row.mergeCells(in: NSRange(location: 0, length: 2))
        row.cell(at: 0).xPlacement = .leading
    }

    // MARK: - Control factories (small control size throughout)

    public static func label(
        _ text: String,
        font: NSFont = .systemFont(ofSize: 13),
        color: NSColor = .labelColor,
        wraps: Bool = false
    ) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = color
        label.lineBreakMode = wraps ? .byWordWrapping : .byTruncatingTail
        label.maximumNumberOfLines = wraps ? 0 : 1
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    public static func caption(_ text: String) -> NSTextField {
        label(text, font: .systemFont(ofSize: 11), color: .secondaryLabelColor)
    }

    public static func button(_ title: String, target: AnyObject?, action: Selector?) -> NSButton {
        let button = NSButton(title: title, target: target, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .small
        return button
    }

    public static func textField(placeholder: String? = nil, width: CGFloat = 260) -> NSTextField {
        let field = NSTextField()
        field.controlSize = .small
        field.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        field.placeholderString = placeholder
        field.widthAnchor.constraint(equalToConstant: width).isActive = true
        return field
    }

    public static func popup() -> NSPopUpButton {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.controlSize = .small
        popup.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        return popup
    }

    /// Stepper + live label, e.g. "Remember 100 clippings".
    public static func stepper(
        value: Int,
        range: ClosedRange<Int>,
        step: Int = 1,
        format: @escaping (Int) -> String,
        onChange: @escaping (Int) -> Void
    ) -> NSStackView {
        let stepper = NSStepper()
        stepper.controlSize = .small
        stepper.minValue = Double(range.lowerBound)
        stepper.maxValue = Double(range.upperBound)
        stepper.increment = Double(step)
        stepper.integerValue = value
        let label = SettingsForm.label(format(value))
        stepper.target = StepperTarget.shared
        stepper.action = #selector(StepperTarget.changed(_:))
        StepperTarget.shared.handlers[ObjectIdentifier(stepper)] = { newValue in
            label.stringValue = format(newValue)
            onChange(newValue)
        }
        let stack = NSStackView(views: [label, stepper])
        stack.orientation = .horizontal
        stack.spacing = 6
        return stack
    }

    /// Icon + text status line ("Granted", "Not connected").
    public static func status(_ text: String, ok: Bool) -> NSStackView {
        let symbol = NSImage(
            systemSymbolName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
            accessibilityDescription: nil
        )?.withSymbolConfiguration(.init(pointSize: 12, weight: .medium))
        let icon = NSImageView(image: symbol ?? NSImage())
        icon.contentTintColor = ok ? .systemGreen : .systemOrange
        let stack = NSStackView(views: [icon, label(text)])
        stack.orientation = .horizontal
        stack.spacing = 5
        return stack
    }
}

@MainActor
private final class ToggleTarget: NSObject {
    static let shared = ToggleTarget()
    var handlers: [ObjectIdentifier: (Bool) -> Void] = [:]
    @objc func changed(_ sender: NSSwitch) {
        handlers[ObjectIdentifier(sender)]?(sender.state == .on)
    }
}

@MainActor
private final class StepperTarget: NSObject {
    static let shared = StepperTarget()
    var handlers: [ObjectIdentifier: (Int) -> Void] = [:]
    @objc func changed(_ sender: NSStepper) {
        handlers[ObjectIdentifier(sender)]?(sender.integerValue)
    }
}

/// Top-left origin so a short form sits at the top of its scroll view.
private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
