import AppKit
import Carbon

/// One global hotkey through Carbon's `RegisterEventHotKey`. Register again
/// to rebind; `nil` unbinds. Fires `onPress` on the main actor.
@MainActor
public final class GlobalHotkey {
    private var hotkeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let signature: OSType
    private let id: UInt32
    public var onPress: () -> Void = {}

    /// `signature` is a four-char code unique to the app ("STRA").
    public init(signature: String, id: UInt32 = 1) {
        self.signature = signature.utf8.reduce(0) { ($0 << 8) | OSType($1) }
        self.id = id
    }

    public func register(_ binding: KeyBinding?) {
        installEventHandler()
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
        guard let binding else { return }
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(binding.keyCode),
            UInt32(binding.modifiers),
            EventHotKeyID(signature: signature, id: id),
            // Must match the target the handler is installed on.
            GetEventDispatcherTarget(),
            0,
            &ref
        )
        if status == noErr {
            hotkeyRef = ref
        } else {
            NSLog("HouseKit: hotkey \(binding.displayString) failed to register status=\(status) (in use by another app?)")
        }
    }

    /// Unregisters; the object is expected to live as long as the app otherwise.
    public func stop() {
        if let ref = hotkeyRef { UnregisterEventHotKey(ref) }
        if let handler = eventHandler { RemoveEventHandler(handler) }
        hotkeyRef = nil
        eventHandler = nil
    }

    private func installEventHandler() {
        guard eventHandler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, userData -> OSStatus in
                guard let userData, let event else { return noErr }
                var hotkeyID = EventHotKeyID()
                GetEventParameter(
                    event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                    nil, MemoryLayout<EventHotKeyID>.size, nil, &hotkeyID
                )
                let hotkey = Unmanaged<GlobalHotkey>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in
                    guard hotkeyID.signature == hotkey.signature, hotkeyID.id == hotkey.id else { return }
                    hotkey.onPress()
                }
                return noErr
            },
            1,
            &spec,
            selfPtr,
            &eventHandler
        )
    }
}
