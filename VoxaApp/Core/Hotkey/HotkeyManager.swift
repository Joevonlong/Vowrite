import Carbon.HIToolbox
import Foundation

final class HotkeyManager {
    var onToggle: (() -> Void)?
    private var hotkeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    private static var shared: HotkeyManager?

    private static let defaultKeyCode: UInt32 = UInt32(kVK_Space)
    private static let defaultModifiers: UInt32 = UInt32(optionKey)

    // UserDefaults keys
    private static let keyCodeKey = "hotkeyKeyCode"
    private static let modifiersKey = "hotkeyModifiers"

    /// Current key code
    var keyCode: UInt32 {
        get {
            let stored = UserDefaults.standard.integer(forKey: Self.keyCodeKey)
            return stored == 0 ? Self.defaultKeyCode : UInt32(stored)
        }
        set {
            UserDefaults.standard.set(Int(newValue), forKey: Self.keyCodeKey)
        }
    }

    /// Current modifiers
    var modifiers: UInt32 {
        get {
            let stored = UserDefaults.standard.integer(forKey: Self.modifiersKey)
            return stored == 0 ? Self.defaultModifiers : UInt32(stored)
        }
        set {
            UserDefaults.standard.set(Int(newValue), forKey: Self.modifiersKey)
        }
    }

    func register() {
        HotkeyManager.shared = self

        // Install handler only once
        if handlerRef == nil {
            var eventType = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )
            InstallEventHandler(
                GetApplicationEventTarget(),
                { _, event, _ -> OSStatus in
                    HotkeyManager.shared?.onToggle?()
                    return noErr
                },
                1, &eventType, nil, &handlerRef
            )
        }

        // Register the hotkey
        registerHotKey()
    }

    /// Re-register with new key code and modifiers
    func update(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        unregisterHotKey()
        registerHotKey()
    }

    private func registerHotKey() {
        let hotkeyID = EventHotKeyID(signature: OSType(0x564F5841), id: 1)
        RegisterEventHotKey(keyCode, modifiers, hotkeyID, GetApplicationEventTarget(), 0, &hotkeyRef)
    }

    private func unregisterHotKey() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
    }

    func unregister() {
        unregisterHotKey()
        if let ref = handlerRef {
            RemoveEventHandler(ref)
            handlerRef = nil
        }
    }

    deinit {
        unregister()
    }
}
