import AppKit
import ApplicationServices
import VowriteKit

/// Monitors user corrections after text injection to auto-learn vocabulary words.
/// Best-effort: any failure silently exits without affecting the user experience.
final class CorrectionMonitor {
    static let shared = CorrectionMonitor()
    private init() {}

    private var sessionID = UUID()

    // MARK: - Public API

    /// Capture the currently focused AXUIElement before paste.
    /// Must be called on any thread; returns immediately (<1ms).
    func captureElement() -> AXUIElement? {
        guard AXIsProcessTrusted() else { return nil }
        guard UserDefaults.standard.object(forKey: "autoLearnCorrections") as? Bool ?? true else { return nil }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        ) == .success, let focusedRef else {
            return nil
        }
        // CFGetTypeID guard: AX may return a non-AXUIElement on some hosts
        // (Electron/Catalyst/web views). The typeID check above ensures safety for CF cast.
        guard CFGetTypeID(focusedRef) == AXUIElementGetTypeID() else {
            return nil
        }
        // swiftlint:disable:next force_cast
        return (focusedRef as! AXUIElement)
    }

    /// Start monitoring for corrections on the given element.
    /// Non-blocking: schedules two delayed reads on a background queue.
    func start(element: AXUIElement, injectedText: String) {
        let session = UUID()
        sessionID = session

        let queue = DispatchQueue.global(qos: .utility)

        // Snapshot 1: baseline at 1s after paste
        queue.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self, self.sessionID == session else { return }
            guard let baseline = self.readValue(from: element) else { return }

            // Snapshot 2: current at 5s after paste
            queue.asyncAfter(deadline: .now() + 4.0) { [weak self] in
                guard let self, self.sessionID == session else { return }
                guard let current = self.readValue(from: element) else { return }

                self.processDiff(baseline: baseline, current: current, injectedText: injectedText)
            }
        }
    }

    // MARK: - AX Reading (with timeout)

    private func readValue(from element: AXUIElement) -> String? {
        final class Box: @unchecked Sendable { var value: String?; init() {} }
        let box = Box()
        let semaphore = DispatchSemaphore(value: 0)

        DispatchQueue.global(qos: .utility).async {
            var valueRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(
                element,
                kAXValueAttribute as CFString,
                &valueRef
            ) == .success {
                box.value = valueRef as? String
            }
            semaphore.signal()
        }

        if semaphore.wait(timeout: .now() + .milliseconds(200)) == .timedOut {
            return nil
        }
        return box.value
    }

    // MARK: - Diff & Learn

    private func processDiff(baseline: String, current: String, injectedText: String) {
        guard baseline != current else { return }

        // Common prefix/suffix extraction
        let prefixLen = baseline.commonPrefix(with: current).count
        let baselineRev = String(baseline.reversed())
        let currentRev = String(current.reversed())
        let suffixLen = baselineRev.commonPrefix(with: currentRev).count

        let baseChars = Array(baseline)
        let currChars = Array(current)

        // Ensure ranges don't overlap
        guard prefixLen + suffixLen <= baseChars.count,
              prefixLen + suffixLen <= currChars.count else { return }

        let trigger = String(baseChars[prefixLen..<(baseChars.count - suffixLen)])
        let replacement = String(currChars[prefixLen..<(currChars.count - suffixLen)])

        // Validate the correction
        guard isValidCorrection(trigger: trigger, replacement: replacement, injectedText: injectedText) else { return }

        // Learn the word
        DispatchQueue.main.async {
            VocabularyManager.shared.add(replacement)
            self.showToast(word: replacement)
        }
    }

    private func isValidCorrection(trigger: String, replacement: String, injectedText: String) -> Bool {
        let t = trigger.trimmingCharacters(in: .whitespacesAndNewlines)
        let r = replacement.trimmingCharacters(in: .whitespacesAndNewlines)

        // Both must be non-empty
        guard !t.isEmpty, !r.isEmpty else { return false }

        // Length limit
        guard t.count <= 30, r.count <= 30 else { return false }

        // Must not be whitespace/punctuation-only difference
        let punctAndSpace = CharacterSet.punctuationCharacters.union(.whitespaces)
        if t.unicodeScalars.allSatisfy({ punctAndSpace.contains($0) }) &&
           r.unicodeScalars.allSatisfy({ punctAndSpace.contains($0) }) {
            return false
        }

        // Trigger should appear in the injected text (user corrected something we pasted)
        guard injectedText.contains(t) else { return false }

        return true
    }

    // MARK: - Toast

    private func showToast(word: String) {
        guard let screen = NSScreen.main else { return }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 40),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]

        let label = NSTextField(labelWithString: "✓ 已加入词库：\(word)")
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.alignment = .center

        let container = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 300, height: 40))
        container.material = .hudWindow
        container.state = .active
        container.wantsLayer = true
        container.layer?.cornerRadius = 10
        container.layer?.masksToBounds = true

        label.frame = container.bounds
        container.addSubview(label)
        panel.contentView = container

        // Size to fit
        label.sizeToFit()
        let width = max(label.frame.width + 40, 200)
        let panelFrame = NSRect(
            x: screen.frame.midX - width / 2,
            y: screen.frame.minY + 80,
            width: width,
            height: 40
        )
        panel.setFrame(panelFrame, display: true)
        label.frame = container.bounds

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            panel.animator().alphaValue = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.3
                panel.animator().alphaValue = 0
            }) {
                panel.close()
            }
        }
    }
}
