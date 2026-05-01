import Foundation

/// Platform-specific hotkey — macOS uses Carbon API, iOS uses buttons.
public protocol HotkeyProvider {
    func register()
    func unregister()
    var onToggle: (() -> Void)? { get set }

    /// F-063: Optional dedicated translate hotkey callback. Platforms without
    /// global hotkeys (iOS) can leave this unimplemented / nil.
    var onTranslateToggle: (() -> Void)? { get set }
}

public extension HotkeyProvider {
    // Default empty implementation so existing iOS placeholders don't have to
    // implement the new property.
    var onTranslateToggle: (() -> Void)? {
        get { nil }
        set { _ = newValue }
    }
}
