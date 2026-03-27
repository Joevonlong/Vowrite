#if canImport(AppKit)
import AppKit
import ApplicationServices
#endif

/// Captures context variables available for prompt template expansion.
/// Captured at recording start so `{selected}` reflects the user's selection
/// before any text injection occurs.
public struct PromptContext: Sendable {
    public let selectedText: String
    public let clipboardText: String

    public init(selectedText: String = "", clipboardText: String = "") {
        self.selectedText = selectedText
        self.clipboardText = clipboardText
    }

    /// Capture the current selected text (via Accessibility) and clipboard content.
    /// Clipboard is read on MainActor (AppKit requirement).
    /// AX calls run on a background thread with a short timeout.
    @MainActor
    public static func capture() -> PromptContext {
        #if canImport(AppKit)
        let clipboard = NSPasteboard.general.string(forType: .string) ?? ""
        let selected = readSelectedTextWithTimeout(ms: 200) ?? ""
        return PromptContext(selectedText: selected, clipboardText: clipboard)
        #else
        return PromptContext()
        #endif
    }

    /// Expand context variables (`{selected}`, `{clipboard}`) in a prompt string.
    /// Uses single-pass replacement to prevent user content containing `{clipboard}`
    /// or `{text}` from being expanded as variables.
    public func expandContextVariables(_ prompt: String) -> String {
        var result = ""
        var remaining = prompt[...]

        while let openRange = remaining.range(of: "{") {
            result += remaining[remaining.startIndex..<openRange.lowerBound]
            remaining = remaining[openRange.lowerBound...]

            if remaining.hasPrefix("{selected}") {
                result += selectedText
                remaining = remaining[remaining.index(remaining.startIndex, offsetBy: 10)...]
            } else if remaining.hasPrefix("{clipboard}") {
                result += clipboardText
                remaining = remaining[remaining.index(remaining.startIndex, offsetBy: 11)...]
            } else {
                result += "{"
                remaining = remaining[remaining.index(after: remaining.startIndex)...]
            }
        }
        result += remaining
        return result
    }

    /// Expand `{text}`, `{selected}`, and `{clipboard}` in a single safe pass.
    /// Used when mode prompts contain `{text}` as a transcript placeholder.
    public func expandAll(_ prompt: String, text: String) -> String {
        var result = ""
        var remaining = prompt[...]

        while let openRange = remaining.range(of: "{") {
            result += remaining[remaining.startIndex..<openRange.lowerBound]
            remaining = remaining[openRange.lowerBound...]

            if remaining.hasPrefix("{text}") {
                result += text
                remaining = remaining[remaining.index(remaining.startIndex, offsetBy: 6)...]
            } else if remaining.hasPrefix("{selected}") {
                result += selectedText
                remaining = remaining[remaining.index(remaining.startIndex, offsetBy: 10)...]
            } else if remaining.hasPrefix("{clipboard}") {
                result += clipboardText
                remaining = remaining[remaining.index(remaining.startIndex, offsetBy: 11)...]
            } else {
                result += "{"
                remaining = remaining[remaining.index(after: remaining.startIndex)...]
            }
        }
        result += remaining
        return result
    }

    // MARK: - Private

    #if canImport(AppKit)
    /// Read selected text with a hard timeout to prevent UI hangs.
    /// AXUIElementCopyAttributeValue is synchronous IPC — if the target app's
    /// accessibility implementation is slow or deadlocked, it blocks indefinitely.
    /// Uses a heap-allocated box to avoid write-after-return on the stack.
    private static func readSelectedTextWithTimeout(ms: Int) -> String? {
        guard AXIsProcessTrusted() else { return nil }

        final class Box: @unchecked Sendable { var value: String?; init() {} }
        let box = Box()
        let semaphore = DispatchSemaphore(value: 0)

        DispatchQueue.global(qos: .userInitiated).async {
            box.value = readSelectedText()
            semaphore.signal()
        }

        let timeout = DispatchTime.now() + .milliseconds(ms)
        if semaphore.wait(timeout: timeout) == .timedOut {
            return nil
        }
        return box.value
    }

    private static func readSelectedText() -> String? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        ) == .success, let focusedRef else {
            return nil
        }

        let element = unsafeDowncast(focusedRef, to: AXUIElement.self)
        var selectedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &selectedRef
        ) == .success else {
            return nil
        }

        return selectedRef as? String
    }
    #endif
}
