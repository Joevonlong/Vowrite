import AppKit
import Carbon.HIToolbox

/// Text injection using the same proven approach as Maccy (12k+ stars).
/// Strategy: clipboard + Cmd+V via cgSessionEventTap with combinedSessionState.
final class TextInjector {
    private var previousApp: NSRunningApplication?
    private var previousBundleID: String?

    /// Call when recording STARTS to remember where to paste later.
    func saveFrontmostApp() {
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
    /// Called AFTER the overlay has been hidden (so system restores focus automatically).
    func inject(text: String) {
        NSLog("[TextInjector] Injecting %d chars, AXTrusted=%d",
              text.count, AXIsProcessTrusted() ? 1 : 0)

        // Step 1: Activate the previous app
        activatePreviousApp()

        // Step 2: Wait for focus to settle, then paste
        // The overlay is already hidden at this point, so the system is restoring focus.
        // We give it a moment then paste via clipboard + Cmd+V (Maccy approach).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.pasteViaClipboard(text: text)
        }
    }

    // MARK: - App Activation

    private func activatePreviousApp() {
        if let app = previousApp, !app.isTerminated {
            app.activate()
            NSLog("[TextInjector] Activated %@", app.localizedName ?? "?")
        }
        // Backup: AppleScript activation
        if let bundleID = previousBundleID {
            let script = NSAppleScript(source: "tell application id \"\(bundleID)\" to activate")
            var error: NSDictionary?
            script?.executeAndReturnError(&error)
        }
    }

    // MARK: - Clipboard + Cmd+V (Maccy-proven approach)

    private func pasteViaClipboard(text: String) {
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        // Write text to clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Simulate Cmd+V using Maccy's proven parameters:
        // - CGEventSource: .combinedSessionState (not .hidSystemState)
        // - Event tap: .cgSessionEventTap (not .cghidEventTap)
        // - Modifier flags: include 0x000008 left-key marker
        // - Suppress local keyboard events during paste
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
