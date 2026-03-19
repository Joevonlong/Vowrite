import Foundation

/// Platform-specific hotkey — macOS uses Carbon API, iOS uses buttons
public protocol HotkeyProvider {
    func register()
    func unregister()
    var onToggle: (() -> Void)? { get set }
}
