import AppKit
import Carbon.HIToolbox
import Foundation
import HouseKit
import Testing

@Suite struct KeyBindingTests {
    @Test func displayStringOrdersModifiersTheAppleWay() {
        let binding = KeyBinding(keyCode: UInt16(kVK_ANSI_V), modifiers: UInt(cmdKey | shiftKey | optionKey | controlKey))
        #expect(binding.displayString == "⌃⌥⇧⌘V")
    }

    @Test func specialKeysUseGlyphs() {
        #expect(KeyBinding(keyCode: UInt16(kVK_Space), modifiers: UInt(optionKey)).displayString == "⌥Space")
        #expect(KeyBinding(keyCode: UInt16(kVK_LeftArrow), modifiers: 0).displayString == "←")
        #expect(KeyBinding(keyCode: UInt16(kVK_Tab), modifiers: UInt(cmdKey)).displayString == "⌘⇥")
        #expect(KeyBinding(keyCode: 122, modifiers: 0).displayString == "F1")
    }

    @Test func flagsRoundTrip() {
        let flags: NSEvent.ModifierFlags = [.command, .shift]
        let binding = KeyBinding(keyCode: 9, flags: flags)
        #expect(binding.modifiers == UInt(cmdKey | shiftKey))
        #expect(binding.modifierFlags == flags)
        #expect(binding.hasModifiers)
        #expect(!KeyBinding(keyCode: 9, modifiers: 0).hasModifiers)
    }

    @Test func menuKeyEquivalents() {
        let v = KeyBinding(keyCode: UInt16(kVK_ANSI_V), modifiers: UInt(cmdKey | shiftKey)).menuKeyEquivalent
        #expect(v?.0 == "v")
        #expect(v?.1 == [.command, .shift])
        let arrow = KeyBinding(keyCode: UInt16(kVK_UpArrow), modifiers: UInt(controlKey | optionKey)).menuKeyEquivalent
        #expect(arrow?.0 == String(UnicodeScalar(NSUpArrowFunctionKey)!))
        #expect(KeyBinding(keyCode: 200, modifiers: 0).menuKeyEquivalent == nil)
    }

    @Test func codableShapeIsStable() throws {
        // Apps stored `{"keyCode":9,"modifiers":768}` before KeyBinding existed; keep decoding it.
        let data = Data(#"{"keyCode":9,"modifiers":768}"#.utf8)
        let binding = try JSONDecoder().decode(KeyBinding.self, from: data)
        #expect(binding == KeyBinding(keyCode: 9, modifiers: UInt(cmdKey | shiftKey)))
        let encoded = String(decoding: try JSONEncoder().encode(binding), as: UTF8.self)
        #expect(encoded.contains(#""keyCode":9"#) && encoded.contains(#""modifiers":768"#))
    }

    @Test func everyPickableKeyHasAName() {
        for key in KeyBinding.pickableKeys {
            #expect(!KeyBinding.keyName(key.keyCode).hasPrefix("Key "), "\(key.name)")
        }
    }
}
