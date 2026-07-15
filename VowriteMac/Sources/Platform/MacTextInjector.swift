import AppKit
import Carbon.HIToolbox
import os.log
import VowriteKit

private let injectorLog = OSLog(subsystem: "com.vowrite.app", category: "TextInjector")

/// Text injection using the same proven approach as Maccy (12k+ stars).
/// Strategy: clipboard + Cmd+V via cgSessionEventTap with combinedSessionState.
///
/// `@MainActor`-isolated: every method here eventually touches AppKit APIs that
/// are documented main-thread-only (`NSRunningApplication.activate()`,
/// `NSAppleScript.executeAndReturnError`, `NSPasteboard` reads/writes). Isolating
/// the whole type (rather than just the `TextOutputProvider` requirements) keeps
/// the private helpers (`activatePreviousApp`, `pasteViaClipboard`) on the same
/// actor as the public entry points, so there's no isolation mismatch between them.
@MainActor
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
    /// Returns `true` if the paste was actually delivered, `false` if injection
    /// was aborted (target app activation failed — the V-014 guard). On the
    /// `false` path the clipboard has NOT been touched by this call (the guard
    /// runs before any pasteboard write), so the caller cannot assume the text
    /// is on the clipboard for a manual paste.
    func output(text: String) async -> Bool {
        NSLog("[TextInjector] Injecting %d chars, AXTrusted=%d",
              text.count, AXIsProcessTrusted() ? 1 : 0)

        // Step 1: Activate the previous app — abort if activation fails (V-014 guard)
        guard activatePreviousApp() else {
            os_log(.error, log: injectorLog,
                   "V-014: target app activation failed — aborting Cmd+V injection to avoid wrong-app paste")
            NSLog("[TextInjector] ERROR: activation failed, injection aborted (clipboard untouched)")
            return false
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

        return true
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

        // Snapshot the FULL pre-injection clipboard — every item, every type it
        // carries (rich text, images, files, etc.), not just the plain string.
        // NSPasteboardItem instances belong to the current pasteboard contents
        // and can't be reused after clearContents(), so each item's data is
        // deep-copied type-by-type into plain Data before we touch anything.
        let snapshot: [[NSPasteboard.PasteboardType: Data]] = (pasteboard.pasteboardItems ?? []).map { item in
            var typeData: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    typeData[type] = data
                }
            }
            return typeData
        }

        // Write the injection text
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Record the change count right after our own write. The restore below
        // only fires if this is still the most recent write to the pasteboard —
        // if the user (or another app) copies something new before the restore
        // timer fires, changeCount will have advanced and we must not clobber it.
        let changeCountAfterWrite = pasteboard.changeCount

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

        // Restore the pre-injection clipboard after paste completes — but only
        // if nothing has written to it in the meantime (changeCount unchanged).
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            guard ClipboardRestoreDecision.shouldRestore(
                currentChangeCount: pasteboard.changeCount,
                recordedChangeCount: changeCountAfterWrite
            ) else {
                NSLog("[TextInjector] Clipboard changed since injection — skipping restore")
                return
            }

            pasteboard.clearContents()
            guard !snapshot.isEmpty else { return }

            let items: [NSPasteboardItem] = snapshot.map { typeData in
                let item = NSPasteboardItem()
                for (type, data) in typeData {
                    item.setData(data, forType: type)
                }
                return item
            }
            pasteboard.writeObjects(items)
        }
    }
}
