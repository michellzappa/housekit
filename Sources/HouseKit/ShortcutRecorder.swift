import AppKit
import Carbon.HIToolbox

/// The house shortcut control: a pill showing the binding. Click to record
/// (type the shortcut; ⎋ cancels, ⌫ clears), or use the ▾ menu to pick the
/// key and modifiers deterministically — for keys AppKit eats while typing,
/// like Tab and the arrows, and for people who would rather not guess.
@MainActor
public final class ShortcutRecorder: NSControl {
    public var binding: KeyBinding? {
        didSet { needsDisplay = true }
    }
    public var onChange: (KeyBinding?) -> Void = { _ in }
    public var placeholder = "Unbound"
    /// Reject unmodified keys (a global hotkey without modifiers is unusable).
    public var requiresModifiers = false
    public var allowsUnbound = true

    private var isRecording = false { didSet { needsDisplay = true } }
    private var monitor: Any?
    private let chevronWidth: CGFloat = 18

    public init(binding: KeyBinding? = nil, onChange: @escaping (KeyBinding?) -> Void = { _ in }) {
        self.binding = binding
        self.onChange = onChange
        super.init(frame: NSRect(x: 0, y: 0, width: 120, height: 24))
        translatesAutoresizingMaskIntoConstraints = false
        setContentHuggingPriority(.required, for: .horizontal)
        widthAnchor.constraint(greaterThanOrEqualToConstant: 110).isActive = true
        heightAnchor.constraint(equalToConstant: 24).isActive = true
        setAccessibilityRole(.button)
        setAccessibilityLabel("Shortcut")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    public override var intrinsicContentSize: NSSize {
        let text = (isRecording ? "Type shortcut…" : (binding?.displayString ?? placeholder)) as NSString
        let width = text.size(withAttributes: [.font: NSFont.systemFont(ofSize: 13)]).width
        return NSSize(width: max(110, width + 24 + chevronWidth), height: 24)
    }

    public override var acceptsFirstResponder: Bool { true }
    public override var canBecomeKeyView: Bool { true }

    // MARK: - Drawing

    public override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
        (isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.18) : NSColor.labelColor.withAlphaComponent(0.08)).setFill()
        path.fill()
        (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = 1
        path.stroke()

        let text: String
        let color: NSColor
        if isRecording {
            text = "Type shortcut…"
            color = .controlAccentColor
        } else if let binding {
            text = binding.displayString
            color = .labelColor
        } else {
            text = placeholder
            color = .secondaryLabelColor
        }
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: color]
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(
            at: NSPoint(x: 10, y: (bounds.height - size.height) / 2),
            withAttributes: attributes
        )
        let chevronConfiguration = NSImage.SymbolConfiguration(pointSize: 9, weight: .semibold)
            .applying(.init(paletteColors: [.secondaryLabelColor]))
        if let chevron = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: nil)?
            .withSymbolConfiguration(chevronConfiguration) {
            let origin = NSPoint(x: bounds.maxX - chevronWidth + 3, y: (bounds.height - chevron.size.height) / 2)
            chevron.draw(at: origin, from: .zero, operation: .sourceOver, fraction: 1)
        }
    }

    // MARK: - Interaction

    public override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if point.x > bounds.maxX - chevronWidth - 6 || event.modifierFlags.contains(.control) {
            showMenu(event)
        } else if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    public override func rightMouseDown(with event: NSEvent) {
        showMenu(event)
    }

    private func startRecording() {
        window?.makeFirstResponder(self)
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self, self.isRecording else { return event }
            self.handle(event)
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
    }

    public override func resignFirstResponder() -> Bool {
        stopRecording()
        return super.resignFirstResponder()
    }

    private func handle(_ event: NSEvent) {
        let code = event.keyCode
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        if Int(code) == kVK_Escape, flags.isEmpty {
            stopRecording()
            return
        }
        if (Int(code) == kVK_Delete || Int(code) == kVK_ForwardDelete), flags.isEmpty, allowsUnbound {
            stopRecording()
            set(nil)
            return
        }
        let candidate = KeyBinding(keyCode: code, flags: flags)
        if requiresModifiers, !candidate.hasModifiers {
            NSSound.beep()
            return
        }
        stopRecording()
        set(candidate)
    }

    private func set(_ new: KeyBinding?) {
        guard new != binding else { return }
        binding = new
        invalidateIntrinsicContentSize()
        onChange(new)
        sendAction(action, to: target)
    }

    // MARK: - Menu fallback

    private func showMenu(_ event: NSEvent) {
        let menu = NSMenu()
        menu.addItem(withTitle: "Record…", action: #selector(recordFromMenu), keyEquivalent: "").target = self
        if allowsUnbound {
            let clear = menu.addItem(withTitle: "Clear", action: #selector(clearFromMenu), keyEquivalent: "")
            clear.target = self
            clear.isEnabled = binding != nil
        }
        menu.addItem(.separator())

        let modifiers = NSMenu()
        for (title, flag) in [("⌃ Control", UInt(controlKey)), ("⌥ Option", UInt(optionKey)), ("⇧ Shift", UInt(shiftKey)), ("⌘ Command", UInt(cmdKey))] {
            let item = modifiers.addItem(withTitle: title, action: #selector(toggleModifier(_:)), keyEquivalent: "")
            item.target = self
            item.tag = Int(flag)
            item.state = (binding?.modifiers ?? 0) & flag != 0 ? .on : .off
        }
        menu.addItem(withTitle: "Modifiers", action: nil, keyEquivalent: "").submenu = modifiers

        let keys = NSMenu()
        for key in KeyBinding.pickableKeys {
            let item = keys.addItem(withTitle: key.name, action: #selector(pickKey(_:)), keyEquivalent: "")
            item.target = self
            item.tag = Int(key.keyCode)
            item.state = binding?.keyCode == key.keyCode ? .on : .off
        }
        menu.addItem(withTitle: "Key", action: nil, keyEquivalent: "").submenu = keys

        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func recordFromMenu() { startRecording() }
    @objc private func clearFromMenu() { set(nil) }

    @objc private func toggleModifier(_ sender: NSMenuItem) {
        let flag = UInt(sender.tag)
        let current = binding ?? KeyBinding(keyCode: UInt16(kVK_Space), modifiers: 0)
        let next = KeyBinding(keyCode: current.keyCode, modifiers: current.modifiers ^ flag)
        if requiresModifiers, !next.hasModifiers { NSSound.beep(); return }
        set(next)
    }

    @objc private func pickKey(_ sender: NSMenuItem) {
        let next = KeyBinding(keyCode: UInt16(sender.tag), modifiers: binding?.modifiers ?? 0)
        if requiresModifiers, !next.hasModifiers { NSSound.beep(); return }
        set(next)
    }
}
