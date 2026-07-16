import AppKit

/// Lightweight, non-interactive HUD-style toast anchored above the Dock.
///
/// Extracted from `CorrectionMonitor`'s F-053 "✓ 已加入词库" notification so
/// BUG-017's polish/translate-failure warning can reuse the exact same
/// visual language (and window-management code) instead of forking a second
/// toast implementation. `CorrectionMonitor` now calls through here too.
enum ToastPresenter {
    /// Show `message` centered above the Dock for ~3 seconds, then fade out.
    /// Safe to call from any polish/translate-failure or vocabulary-learn
    /// callback — builds and tears down its own `NSPanel` per call.
    static func show(_ message: String) {
        guard let screen = NSScreen.main else { return }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 40),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        panel.isReleasedWhenClosed = false
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]

        let label = NSTextField(labelWithString: message)
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
