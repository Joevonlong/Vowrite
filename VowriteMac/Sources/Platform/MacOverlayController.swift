import SwiftUI
import AppKit
import VowriteKit

// MARK: - Non-activating panel: accepts clicks but doesn't steal app activation

final class NonActivatingPanel: NSPanel {
    override var canBecomeMain: Bool { false }
}

// MARK: - Overlay Style

enum OverlayStyle: String, CaseIterable {
    case compact = "Compact"
    case normal = "Normal"

    static var current: OverlayStyle {
        get {
            guard let raw = UserDefaults.standard.string(forKey: "overlayStyle"),
                  let style = OverlayStyle(rawValue: raw) else { return .compact }
            return style
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "overlayStyle") }
    }
}

// MARK: - Mac Overlay Provider

final class MacOverlayController: OverlayProvider {
    static let shared = MacOverlayController()

    private var window: NSWindow?
    private var hostingView: NSHostingView<RecordingBarView>?
    var appState: AppState?

    func showRecording() {
        guard let appState = appState else { return }
        show(appState: appState)
    }

    func showProcessing() {
        update()
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
        hostingView = nil
    }

    func updateLevel(_ level: Float) {
        update()
    }

    func show(appState: AppState) {
        self.appState = appState

        if window != nil {
            update()
            window?.orderFront(nil)
            return
        }

        let barView = RecordingBarView(appState: appState)
        let hosting = NSHostingView(rootView: barView)
        let size = overlaySize
        hosting.frame = NSRect(origin: .zero, size: size)

        let win = NonActivatingPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .statusBar + 1
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.hasShadow = true
        win.contentView = hosting
        win.isMovableByWindowBackground = true
        win.ignoresMouseEvents = false

        // Position at bottom center, just above the Dock
        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            let visibleFrame = screen.visibleFrame
            let dockHeight = visibleFrame.minY - screenFrame.minY
            let x = screenFrame.midX - size.width / 2
            let y = screenFrame.minY + dockHeight + 12
            win.setFrameOrigin(NSPoint(x: x, y: y))
        }

        win.orderFront(nil)
        self.window = win
        self.hostingView = hosting
    }

    func update() {
        guard let appState = appState else { return }
        let barView = RecordingBarView(appState: appState)
        hostingView?.rootView = barView
    }

    private var overlaySize: NSSize {
        switch OverlayStyle.current {
        case .compact: return NSSize(width: 200, height: 42)
        case .normal: return NSSize(width: 260, height: 52)
        }
    }
}
