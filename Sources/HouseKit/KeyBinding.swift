import AppKit
import Carbon.HIToolbox

/// A keyboard shortcut as the Carbon hotkey API and `CGEvent` taps see it:
/// hardware key code plus Carbon modifier flags. Stored, so it survives
/// keyboard-layout changes the way the user expects.
public struct KeyBinding: Codable, Equatable, Hashable, Sendable {
    public var keyCode: UInt16
    public var modifiers: UInt

    public init(keyCode: UInt16, modifiers: UInt) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public init(keyCode: UInt16, flags: NSEvent.ModifierFlags) {
        self.init(keyCode: keyCode, modifiers: KeyBinding.carbonModifiers(from: flags))
    }

    public var hasModifiers: Bool { modifiers & UInt(cmdKey | optionKey | controlKey | shiftKey) != 0 }

    public var modifierFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers & UInt(cmdKey) != 0 { flags.insert(.command) }
        if modifiers & UInt(optionKey) != 0 { flags.insert(.option) }
        if modifiers & UInt(controlKey) != 0 { flags.insert(.control) }
        if modifiers & UInt(shiftKey) != 0 { flags.insert(.shift) }
        return flags
    }

    public static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt {
        var result: UInt = 0
        if flags.contains(.command) { result |= UInt(cmdKey) }
        if flags.contains(.option) { result |= UInt(optionKey) }
        if flags.contains(.control) { result |= UInt(controlKey) }
        if flags.contains(.shift) { result |= UInt(shiftKey) }
        return result
    }

    /// "⌥⇧Space", the single human-readable form used by menus and settings.
    public var displayString: String {
        var parts: [String] = []
        if modifiers & UInt(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt(cmdKey) != 0 { parts.append("⌘") }
        parts.append(KeyBinding.keyName(keyCode))
        return parts.joined()
    }

    /// AppKit menu form: key-equivalent string plus modifier mask. Nil for
    /// keys a menu cannot show, so the item is left without a misleading one.
    public var menuKeyEquivalent: (String, NSEvent.ModifierFlags)? {
        guard let key = KeyBinding.menuCharacter(keyCode) else { return nil }
        return (key, modifierFlags)
    }

    // MARK: - Key tables

    /// Keys that can be picked from a menu (the ones AppKit tends to eat while
    /// recording — Tab, arrows — plus the rest), in display order.
    public static let pickableKeys: [(keyCode: UInt16, name: String)] = [
        (UInt16(kVK_Space), "Space"), (UInt16(kVK_Tab), "⇥ Tab"), (UInt16(kVK_Return), "↩ Return"),
        (UInt16(kVK_Escape), "⎋ Escape"), (UInt16(kVK_Delete), "⌫ Delete"), (UInt16(kVK_ForwardDelete), "⌦ Forward Delete"),
        (UInt16(kVK_LeftArrow), "← Left Arrow"), (UInt16(kVK_RightArrow), "→ Right Arrow"),
        (UInt16(kVK_UpArrow), "↑ Up Arrow"), (UInt16(kVK_DownArrow), "↓ Down Arrow"),
        (UInt16(kVK_Home), "Home"), (UInt16(kVK_End), "End"), (UInt16(kVK_PageUp), "Page Up"), (UInt16(kVK_PageDown), "Page Down"),
        (122, "F1"), (120, "F2"), (99, "F3"), (118, "F4"), (96, "F5"), (97, "F6"),
        (98, "F7"), (100, "F8"), (101, "F9"), (109, "F10"), (103, "F11"), (111, "F12")
    ] + characterKeys.sorted { $0.value < $1.value }.map { ($0.key, $0.value.uppercased()) }

    static let characterKeys: [UInt16: String] = [
        0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x", 8: "c", 9: "v",
        11: "b", 12: "q", 13: "w", 14: "e", 15: "r", 16: "y", 17: "t",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "o", 32: "u", 33: "i", 34: "p", 35: "[", 37: "l", 38: "j", 39: "'", 40: "k",
        41: ";", 42: "\\", 43: ",", 44: "n", 45: "m", 46: ".", 47: "/", 50: "`"
    ]

    public static func keyName(_ keyCode: UInt16) -> String {
        if let special = pickableKeys.first(where: { $0.keyCode == keyCode && characterKeys[keyCode] == nil }) {
            // Strip the glyph prefix ("⇥ Tab" → "⇥") for compact display.
            let name = special.name
            if let space = name.firstIndex(of: " "), name[name.startIndex].unicodeScalars.first!.value > 0x2000 {
                return String(name[..<space])
            }
            return name
        }
        return characterKeys[keyCode]?.uppercased() ?? "Key \(keyCode)"
    }

    static func menuCharacter(_ keyCode: UInt16) -> String? {
        switch Int(keyCode) {
        case kVK_Space: return " "
        case kVK_Return: return "\r"
        case kVK_Tab: return "\t"
        case kVK_Delete: return String(UnicodeScalar(NSBackspaceCharacter)!)
        case kVK_ForwardDelete: return String(UnicodeScalar(NSDeleteCharacter)!)
        case kVK_Escape: return "\u{1B}"
        case kVK_LeftArrow: return String(UnicodeScalar(NSLeftArrowFunctionKey)!)
        case kVK_RightArrow: return String(UnicodeScalar(NSRightArrowFunctionKey)!)
        case kVK_UpArrow: return String(UnicodeScalar(NSUpArrowFunctionKey)!)
        case kVK_DownArrow: return String(UnicodeScalar(NSDownArrowFunctionKey)!)
        case kVK_Home: return String(UnicodeScalar(NSHomeFunctionKey)!)
        case kVK_End: return String(UnicodeScalar(NSEndFunctionKey)!)
        case kVK_PageUp: return String(UnicodeScalar(NSPageUpFunctionKey)!)
        case kVK_PageDown: return String(UnicodeScalar(NSPageDownFunctionKey)!)
        case 122: return String(UnicodeScalar(NSF1FunctionKey)!)
        case 120: return String(UnicodeScalar(NSF2FunctionKey)!)
        case 99: return String(UnicodeScalar(NSF3FunctionKey)!)
        case 118: return String(UnicodeScalar(NSF4FunctionKey)!)
        case 96: return String(UnicodeScalar(NSF5FunctionKey)!)
        case 97: return String(UnicodeScalar(NSF6FunctionKey)!)
        case 98: return String(UnicodeScalar(NSF7FunctionKey)!)
        case 100: return String(UnicodeScalar(NSF8FunctionKey)!)
        case 101: return String(UnicodeScalar(NSF9FunctionKey)!)
        case 109: return String(UnicodeScalar(NSF10FunctionKey)!)
        case 103: return String(UnicodeScalar(NSF11FunctionKey)!)
        case 111: return String(UnicodeScalar(NSF12FunctionKey)!)
        default: return characterKeys[keyCode]
        }
    }
}
