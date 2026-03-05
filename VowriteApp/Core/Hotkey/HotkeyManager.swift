import Carbon.HIToolbox
import Foundation

final class HotkeyManager {
    var onToggle: (() -> Void)?
    var onModeSwitch: ((Int) -> Void)?  // F-018: mode index callback
    private var hotkeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var modeHotkeyRefs: [EventHotKeyRef] = []

    private static var shared: HotkeyManager?

    private static let defaultKeyCode: UInt32 = UInt32(kVK_Space)
    private static let defaultModifiers: UInt32 = UInt32(optionKey)

    // UserDefaults keys
    private static let keyCodeKey = "hotkeyKeyCode"
    private static let modifiersKey = "hotkeyModifiers"
    private static let pushToTalkKey = "pushToTalkEnabled"

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

    func register() {
        HotkeyManager.shared = self

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
                            HotkeyManager.shared?.onToggle?()
                        } else if kind == kEventHotKeyReleased {
                            // Push to Talk: release stops recording
                            if HotkeyManager.shared?.pushToTalkEnabled == true {
                                HotkeyManager.shared?.onPushToTalkRelease?()
                            }
                        }
                    } else if hotkeyID.id >= 100 && hotkeyID.id < 110, kind == kEventHotKeyPressed {
                        // Mode switch hotkeys (⌃1 through ⌃9)
                        let modeIndex = Int(hotkeyID.id - 100)
                        HotkeyManager.shared?.onModeSwitch?(modeIndex)
                    }

                    return noErr
                },
                2, &eventTypes, nil, &handlerRef
            )
        }

        registerHotKey()
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
        unregisterModeHotkeys()
        if let ref = handlerRef {
            RemoveEventHandler(ref)
            handlerRef = nil
        }
    }

    deinit { unregister() }
}
