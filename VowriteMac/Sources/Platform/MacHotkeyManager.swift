import Carbon.HIToolbox
import Foundation
import VowriteKit

final class MacHotkeyManager: HotkeyProvider {
    var onToggle: (() -> Void)?
    var onModeSwitch: ((Int) -> Void)?  // F-018: mode index callback
    var onTranslateToggle: (() -> Void)?  // F-063: dedicated translate hotkey
    private var hotkeyRef: EventHotKeyRef?
    private var translateHotkeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var modeHotkeyRefs: [EventHotKeyRef] = []

    private static var shared: MacHotkeyManager?

    private static let defaultKeyCode: UInt32 = UInt32(kVK_Space)
    private static let defaultModifiers: UInt32 = UInt32(optionKey)

    // F-063 default: Shift+Option+Space (variant of the main hotkey).
    private static let defaultTranslateKeyCode: UInt32 = UInt32(kVK_Space)
    private static let defaultTranslateModifiers: UInt32 = UInt32(optionKey | shiftKey)

    // UserDefaults keys
    private static let keyCodeKey = "hotkeyKeyCode"
    private static let modifiersKey = "hotkeyModifiers"
    private static let pushToTalkKey = "pushToTalkEnabled"
    private static let translateKeyCodeKey = "translateHotkeyKeyCode"        // F-063
    private static let translateModifiersKey = "translateHotkeyModifiers"    // F-063

    /// Push to Talk: hold to record, release to stop
    var pushToTalkEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.pushToTalkKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.pushToTalkKey) }
    }

    var keyCode: UInt32 {
        get {
            let stored = UserDefaults.standard.integer(forKey: Self.keyCodeKey)
            return stored == 0 ? Self.defaultKeyCode : UInt32(stored)
        }
        set { UserDefaults.standard.set(Int(newValue), forKey: Self.keyCodeKey) }
    }

    var modifiers: UInt32 {
        get {
            let stored = UserDefaults.standard.integer(forKey: Self.modifiersKey)
            return stored == 0 ? Self.defaultModifiers : UInt32(stored)
        }
        set { UserDefaults.standard.set(Int(newValue), forKey: Self.modifiersKey) }
    }

    // MARK: - F-063 Translate hotkey

    var translateKeyCode: UInt32 {
        get {
            let stored = UserDefaults.standard.integer(forKey: Self.translateKeyCodeKey)
            return stored == 0 ? Self.defaultTranslateKeyCode : UInt32(stored)
        }
        set { UserDefaults.standard.set(Int(newValue), forKey: Self.translateKeyCodeKey) }
    }

    var translateModifiers: UInt32 {
        get {
            let stored = UserDefaults.standard.integer(forKey: Self.translateModifiersKey)
            return stored == 0 ? Self.defaultTranslateModifiers : UInt32(stored)
        }
        set { UserDefaults.standard.set(Int(newValue), forKey: Self.translateModifiersKey) }
    }

    /// Returns true if the given (keyCode, modifiers) combo collides with the
    /// main dictate hotkey. Settings UI calls this to refuse conflicting
    /// translate hotkey assignments.
    func translateConflictsWithDictate(keyCode: UInt32, modifiers: UInt32) -> Bool {
        return self.keyCode == keyCode && self.modifiers == modifiers
    }

    /// Inverse check used when the user changes the main hotkey: refuse if it
    /// would collide with the translate hotkey already on file.
    func dictateConflictsWithTranslate(keyCode: UInt32, modifiers: UInt32) -> Bool {
        return self.translateKeyCode == keyCode && self.translateModifiers == modifiers
    }

    func register() {
        MacHotkeyManager.shared = self

        if handlerRef == nil {
            var eventTypes = [
                EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
                EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
            ]
            InstallEventHandler(
                GetApplicationEventTarget(),
                { _, event, _ -> OSStatus in
                    guard let event = event else { return OSStatus(eventNotHandledErr) }
                    var hotkeyID = EventHotKeyID()
                    GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                      EventParamType(typeEventHotKeyID), nil,
                                      MemoryLayout<EventHotKeyID>.size, nil, &hotkeyID)

                    let kind = Int(GetEventKind(event))

                    if hotkeyID.id == 1 {
                        // Main recording hotkey
                        if kind == kEventHotKeyPressed {
                            MacHotkeyManager.shared?.onToggle?()
                        } else if kind == kEventHotKeyReleased {
                            // Push to Talk: release stops recording
                            if MacHotkeyManager.shared?.pushToTalkEnabled == true {
                                MacHotkeyManager.shared?.onPushToTalkRelease?()
                            }
                        }
                    } else if hotkeyID.id == 2 {
                        // F-063: Translate hotkey (toggle-only; release ignored in v1)
                        if kind == kEventHotKeyPressed {
                            MacHotkeyManager.shared?.onTranslateToggle?()
                        }
                    } else if hotkeyID.id >= 100 && hotkeyID.id < 110, kind == kEventHotKeyPressed {
                        // Mode switch hotkeys (⌃1 through ⌃9)
                        let modeIndex = Int(hotkeyID.id - 100)
                        MacHotkeyManager.shared?.onModeSwitch?(modeIndex)
                    }

                    return noErr
                },
                2, &eventTypes, nil, &handlerRef
            )
        }

        registerHotKey()
        registerTranslateHotKey()
        registerModeHotkeys()
    }

    /// Callback for Push to Talk release
    var onPushToTalkRelease: (() -> Void)?

    func update(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        unregisterHotKey()
        registerHotKey()
    }

    /// F-063: Update the translate hotkey at runtime.
    func updateTranslate(keyCode: UInt32, modifiers: UInt32) {
        self.translateKeyCode = keyCode
        self.translateModifiers = modifiers
        unregisterTranslateHotKey()
        registerTranslateHotKey()
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

    // MARK: - F-063 Translate hotkey registration

    private func registerTranslateHotKey() {
        let hotkeyID = EventHotKeyID(signature: OSType(0x564F5841), id: 2)
        RegisterEventHotKey(translateKeyCode, translateModifiers, hotkeyID, GetApplicationEventTarget(), 0, &translateHotkeyRef)
    }

    private func unregisterTranslateHotKey() {
        if let ref = translateHotkeyRef {
            UnregisterEventHotKey(ref)
            translateHotkeyRef = nil
        }
    }

    /// Register ⌃1 through ⌃9 for mode switching
    func registerModeHotkeys() {
        unregisterModeHotkeys()

        // Key codes for number keys 1-9
        let keyCodes: [UInt32] = [
            UInt32(kVK_ANSI_1), UInt32(kVK_ANSI_2), UInt32(kVK_ANSI_3),
            UInt32(kVK_ANSI_4), UInt32(kVK_ANSI_5), UInt32(kVK_ANSI_6),
            UInt32(kVK_ANSI_7), UInt32(kVK_ANSI_8), UInt32(kVK_ANSI_9)
        ]

        for (i, kc) in keyCodes.enumerated() {
            var ref: EventHotKeyRef?
            let hotkeyID = EventHotKeyID(signature: OSType(0x564F5841), id: UInt32(100 + i))
            RegisterEventHotKey(kc, UInt32(controlKey), hotkeyID, GetApplicationEventTarget(), 0, &ref)
            if let ref = ref { modeHotkeyRefs.append(ref) }
        }
    }

    private func unregisterModeHotkeys() {
        for ref in modeHotkeyRefs {
            UnregisterEventHotKey(ref)
        }
        modeHotkeyRefs.removeAll()
    }

    func unregister() {
        unregisterHotKey()
        unregisterTranslateHotKey()
        unregisterModeHotkeys()
        if let ref = handlerRef {
            RemoveEventHandler(ref)
            handlerRef = nil
        }
    }

    deinit { unregister() }
}
