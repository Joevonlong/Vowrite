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

    var barSize: NSSize {
        switch self {
        case .compact: return NSSize(width: 184, height: 40)
        case .normal: return NSSize(width: 232, height: 48)
        }
    }

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
    private var hostingView: NSHostingView<RecordingIndicatorView>?
    // Weak: MacOverlayController is a static singleton with app lifetime; a strong
    // back-pointer here would keep whatever AppState was last assigned alive forever.
    weak var appState: AppState?

    func showRecording() {
        guard let appState = appState else { return }
        show(appState: appState)
    }

    func showProcessing() {
        // No-op by design (P-6 perf fix). `RecordingIndicatorView` (installed as
        // `hostingView.rootView` by `show()`) holds `@ObservedObject var appState`.
        // `appState.state` is `@Published` and is already `.processing` by the time
        // this is called (DictationEngine sets `state` before invoking
        // `overlay.showProcessing()`), so Combine's `objectWillChange` already
        // re-evaluates the installed view's body — reconstructing a new
        // RecordingIndicatorView and reassigning rootView here would just force a
        // redundant identity loss + full rebuild of the same content.
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
        hostingView = nil
    }

    func updateLevel(_ level: Float) {
        // No-op by design (P-6 perf fix, was firing at 20 Hz). `appState.audioLevel`
        // is `@Published` and already updated by the caller before this is invoked
        // (DictationEngine sets `audioLevel` then calls `overlay.updateLevel`), so
        // the same Combine-driven re-render described in `showProcessing()` above
        // already redraws the waveform/level-reactive UI. See MacOverlayController
        // fix-1 notes for the full property trace.
    }

    func show(appState: AppState) {
        self.appState = appState

        if window != nil {
            update()
            window?.orderFront(nil)
            return
        }

        let indicatorView = RecordingIndicatorView(appState: appState)
        let hosting = NSHostingView(rootView: indicatorView)
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
            let y = screenFrame.minY + dockHeight + 24
            win.setFrameOrigin(NSPoint(x: x, y: y))
        }

        win.orderFront(nil)
        self.window = win
        self.hostingView = hosting
    }

    func update() {
        guard let appState, let window, let hostingView else { return }
        let oldFrame = window.frame
        let size = overlaySize
        let indicatorView = RecordingIndicatorView(appState: appState)
        hostingView.rootView = indicatorView
        window.setContentSize(size)
        hostingView.frame = NSRect(origin: .zero, size: size)
        // Keep the user's dragged position anchored at the bottom center.
        window.setFrameOrigin(NSPoint(x: oldFrame.midX - size.width / 2, y: oldFrame.minY))
    }

    private var overlaySize: NSSize {
        switch IndicatorPreset.current {
        case .orbPulse:
            return NSSize(width: 100, height: 100)
        case .rippleRing:
            return NSSize(width: 100, height: 100)
        case .spectrumArc:
            return NSSize(width: 120, height: 120)
        case .minimalDot:
            return NSSize(width: 60, height: 60)
        case .classicBar:
            let barSize = OverlayStyle.current.barSize
            return NSSize(width: barSize.width, height: barSize.height + 12)
        }
    }
}
