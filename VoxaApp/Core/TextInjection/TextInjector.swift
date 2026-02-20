import AppKit
import Carbon.HIToolbox

final class TextInjector {
    private var previousApp: NSRunningApplication?
    private var previousBundleID: String?

    /// Call when recording STARTS to remember where to paste later.
    func saveFrontmostApp() {
        let myBundleID = Bundle.main.bundleIdentifier ?? "com.voxa.app"
        
        if let app = NSWorkspace.shared.frontmostApplication,
           app.bundleIdentifier != myBundleID {
            previousApp = app
            previousBundleID = app.bundleIdentifier
            NSLog("[TextInjector] Saved frontmost: %@ [%@]",
                  app.localizedName ?? "?", app.bundleIdentifier ?? "?")
        }
    }

    /// Inject text into the previously active app
    func inject(text: String) {
        NSLog("[TextInjector] Injecting %d chars, target=%@",
              text.count, previousApp?.localizedName ?? "nil")

        // Step 1: Activate the previous app
        activatePreviousApp()

        // Step 2: Wait for activation, then type/paste
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if AXIsProcessTrusted() {
                NSLog("[TextInjector] Have Accessibility, using clipboard+paste")
                self.pasteViaClipboard(text: text)
            } else {
                NSLog("[TextInjector] No Accessibility, using Unicode typing")
                self.typeViaUnicode(text: text)
            }
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

    // MARK: - Method 1: Clipboard + Cmd+V (fast, needs Accessibility)

    private func pasteViaClipboard(text: String) {
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        usleep(50_000)
        keyUp?.post(tap: .cghidEventTap)
        NSLog("[TextInjector] Cmd+V posted")

        // Restore clipboard
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            pasteboard.clearContents()
            if let prev = previousContents {
                pasteboard.setString(prev, forType: .string)
            }
        }
    }

    // MARK: - Method 2: Unicode character typing (no Accessibility needed!)
    // Uses CGEvent Unicode input which works without special permissions.

    private func typeViaUnicode(text: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            for char in text {
                let str = String(char)
                let utf16 = Array(str.utf16)

                let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)
                keyDown?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
                keyDown?.post(tap: .cghidEventTap)

                let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)
                keyUp?.post(tap: .cghidEventTap)

                usleep(3_000) // 3ms per char — fast enough for most text
            }
            NSLog("[TextInjector] Unicode typing complete (%d chars)", text.count)
        }
    }
}
