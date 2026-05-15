import AppKit
import Carbon.HIToolbox
import os.log
import VowriteKit

private let injectorLog = OSLog(subsystem: "com.vowrite.app", category: "TextInjector")

/// Text injection using the same proven approach as Maccy (12k+ stars).
/// Strategy: clipboard + Cmd+V via cgSessionEventTap with combinedSessionState.
final class MacTextInjector: TextOutputProvider {
    private var previousApp: NSRunningApplication?
    private var previousBundleID: String?

    /// Call when recording STARTS to remember where to paste later.
    func prepareForOutput() {
        let myBundleID = Bundle.main.bundleIdentifier ?? "com.vowrite.app"

        if let app = NSWorkspace.shared.frontmostApplication,
           app.bundleIdentifier != myBundleID {
            previousApp = app
            previousBundleID = app.bundleIdentifier
            NSLog("[TextInjector] Saved frontmost: %@ [%@]",
                  app.localizedName ?? "?", app.bundleIdentifier ?? "?")
        }
    }

    /// Inject text into the previously active app at the cursor position.
    func output(text: String) async {
        NSLog("[TextInjector] Injecting %d chars, AXTrusted=%d",
              text.count, AXIsProcessTrusted() ? 1 : 0)

        // Step 1: Activate the previous app — abort if activation fails (V-014 guard)
        guard activatePreviousApp() else {
            os_log(.error, log: injectorLog,
                   "V-014: target app activation failed — aborting Cmd+V injection to avoid wrong-app paste")
            NSLog("[TextInjector] ERROR: activation failed, injection aborted (clipboard untouched)")
            return
        }

        // Step 2: Wait for focus to settle
        try? await Task.sleep(for: .milliseconds(300))

        // Step 3: Capture focused element before paste (for correction monitoring)
        let element = CorrectionMonitor.shared.captureElement()

        // Step 4: Paste
        pasteViaClipboard(text: text)

        // Step 5: Start correction monitoring (async, non-blocking)
        if let element {
            CorrectionMonitor.shared.start(element: element, injectedText: text)
        }
    }

    // MARK: - App Activation

    /// Attempts to activate the previously recorded app.
    /// Returns `true` only when the target process is confirmed reachable:
    ///   • NSRunningApplication.activate() succeeds (primary path), OR
    ///   • AppleScript activate executes without error (fallback).
    /// Returns `false` if both paths fail — caller MUST NOT inject in this case.
    @discardableResult
    private func activatePreviousApp() -> Bool {
        // Primary: direct NSRunningApplication activation
        if let app = previousApp, !app.isTerminated {
            if app.activate() {
                NSLog("[TextInjector] Activated %@ (NSRunningApplication)", app.localizedName ?? "?")
                return true
            }
            os_log(.error, log: injectorLog,
                   "V-014: NSRunningApplication.activate() returned false for %{public}@",
                   app.localizedName ?? "?")
        }

        // Fallback: AppleScript activation with explicit error-checking
        if let bundleID = previousBundleID {
            let script = NSAppleScript(source: "tell application id \"\(bundleID)\" to activate")
            var error: NSDictionary?
            script?.executeAndReturnError(&error)
            if let error {
                os_log(.error, log: injectorLog,
                       "V-014: AppleScript activation failed for %{public}@: %{public}@",
                       bundleID, error.description)
                return false
            }
            NSLog("[TextInjector] Activated %@ (AppleScript fallback)", bundleID)
            return true
        }

        // No target app was recorded
        os_log(.error, log: injectorLog,
               "V-014: no target app recorded — injection aborted")
        return false
    }

    // MARK: - Clipboard + Cmd+V (Maccy-proven approach)

    private func pasteViaClipboard(text: String) {
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        // Write text to clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        let source = CGEventSource(stateID: .combinedSessionState)
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )

        let cmdFlag = CGEventFlags(rawValue: UInt64(CGEventFlags.maskCommand.rawValue) | 0x000008)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        keyDown?.flags = cmdFlag
        keyUp?.flags = cmdFlag
        keyDown?.post(tap: .cgSessionEventTap)
        keyUp?.post(tap: .cgSessionEventTap)

        NSLog("[TextInjector] Cmd+V posted (combinedSessionState + cgSessionEventTap)")

        // Restore clipboard after paste completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            pasteboard.clearContents()
            if let prev = previousContents {
                pasteboard.setString(prev, forType: .string)
            }
        }
    }
}
