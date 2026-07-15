import Foundation

/// Platform-specific text output — macOS injects at cursor, iOS copies to clipboard.
///
/// `@MainActor`-isolated at the protocol level so every conformer inherits the
/// isolation: on macOS, `output(text:)` drives `NSRunningApplication.activate()`,
/// `NSAppleScript.executeAndReturnError`, and `NSPasteboard` mutations, all of
/// which are documented main-thread-only. Before this annotation, the protocol
/// requirement was `nonisolated`, so `DictationEngine`'s `await textOutput.output(...)`
/// hopped OFF the main actor to call in — this keeps the whole call on the main
/// actor instead. Internal `await`s (e.g. `Task.sleep`) still suspend without
/// blocking the main thread, so the UI stays responsive.
@MainActor
public protocol TextOutputProvider {
    /// Delivers `text` to the user (macOS: paste at cursor; iOS: clipboard/keyboard insert).
    /// Returns `true` if delivery was completed, `false` if it was aborted
    /// (e.g. macOS target-app activation failed) — callers should surface this
    /// to the user rather than silently reporting success.
    func output(text: String) async -> Bool
    func prepareForOutput()
}

/// Pure decision helper for the post-paste clipboard restore in `MacTextInjector`.
/// Extracted here (rather than left inline) so the changeCount-equality check —
/// the crux of the clipboard-race fix — is unit-testable from `VowriteKitTests`;
/// `VowriteMac` has no test target.
public enum ClipboardRestoreDecision {
    /// `true` only when nothing has written to the pasteboard since
    /// `recordedChangeCount` was captured right after writing the injection
    /// text — i.e. it's still safe to restore the pre-injection snapshot.
    /// Any other value means the user (or another app) copied something new
    /// in the meantime, and restoring now would silently clobber it.
    public static func shouldRestore(currentChangeCount: Int, recordedChangeCount: Int) -> Bool {
        currentChangeCount == recordedChangeCount
    }
}
