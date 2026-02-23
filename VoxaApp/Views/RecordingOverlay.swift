import SwiftUI
import AppKit

// MARK: - Non-activating panel: accepts clicks but doesn't steal app activation

final class NonActivatingPanel: NSPanel {
    override var canBecomeMain: Bool { false }
    // canBecomeKey is true so buttons work, but nonactivatingPanel style
    // prevents the owning app from becoming frontmost
}

// MARK: - Floating Recording Bar (like Typeless)

final class RecordingOverlayController {
    static let shared = RecordingOverlayController()

    private var window: NSWindow?
    private var hostingView: NSHostingView<RecordingBarView>?
    private var appState: AppState?

    func show(appState: AppState) {
        self.appState = appState

        if window != nil {
            update()
            window?.orderFront(nil)
            return
        }

        let barView = RecordingBarView(appState: appState)
        let hosting = NSHostingView(rootView: barView)
        hosting.frame = NSRect(x: 0, y: 0, width: 158, height: 42)

        let win = NonActivatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 158, height: 42),
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
            // Dock height = difference between screen bottom and visible frame bottom
            let dockHeight = visibleFrame.minY - screenFrame.minY
            let x = screenFrame.midX - 79
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

    func hide() {
        window?.orderOut(nil)
        window = nil
        hostingView = nil
        appState = nil
    }
}

// MARK: - Recording Bar SwiftUI View

struct RecordingBarView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Group {
            switch appState.state {
            case .recording:
                recordingBar
            case .processing:
                processingBar
            default:
                EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appState.state)
    }

    // MARK: Recording state — X [waveform] ✓

    private var recordingBar: some View {
        HStack(spacing: 0) {
            // Cancel button — large, prominent
            Button {
                appState.cancelRecording()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            .padding(.leading, 5)

            // Waveform — compact center
            WaveformView(level: appState.audioLevel)
                .frame(width: 70)
                .frame(height: 22)
                .padding(.horizontal, 4)

            // Confirm button — large, prominent
            Button {
                appState.stopRecording()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            .padding(.trailing, 5)
        }
        .frame(width: 158, height: 42)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.85))
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: Processing state — "Thinking"

    private var processingBar: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
                .colorScheme(.dark)
            Text("Thinking")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(width: 140, height: 36)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.75))
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Waveform Visualization

struct WaveformView: View {
    let level: Float
    let barCount = 13

    @State private var animatedLevels: [Float] = Array(repeating: 0, count: 13)
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.white.opacity(barOpacity(for: index)))
                    .frame(width: 3, height: barHeight(for: index))
            }
        }
        .onAppear { startAnimation() }
        .onDisappear { timer?.invalidate(); targetTimer?.invalidate() }
        .onChange(of: level) { _, _ in updateTargets() }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let minHeight: CGFloat = 3
        let maxHeight: CGFloat = 18
        let level = CGFloat(animatedLevels[index])
        return minHeight + (maxHeight - minHeight) * level
    }

    private func barOpacity(for index: Int) -> Double {
        // Outer bars slightly more transparent for fade effect
        let center = Double(barCount) / 2.0
        let dist = abs(Double(index) - center) / center
        return 1.0 - dist * 0.3
    }

    // Slow-moving targets that each bar drifts toward
    @State private var targetLevels: [Float] = Array(repeating: 0, count: 13)
    @State private var targetTimer: Timer?

    private func startAnimation() {
        // Render at 60fps for silky smooth interpolation
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            Task { @MainActor in
                interpolateLevels()
            }
        }
        // Update targets at ~4Hz for slow, organic movement
        targetTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
            Task { @MainActor in
                updateTargets()
            }
        }
    }

    /// Pick new random target heights (called ~4x per second)
    private func updateTargets() {
        let speaking = level > 0.5

        for i in 0..<barCount {
            let center = Float(barCount) / 2.0
            let centerDistance = abs(Float(i) - center) / center

            if speaking {
                // Bell curve: center bars reach full height, edges ~40%
                let bellCurve: Float = 1.0 - centerDistance * 0.6
                targetLevels[i] = bellCurve * Float.random(in: 0.6...1.0)
            } else {
                targetLevels[i] = 0.05
            }
        }
    }

    /// Smoothly drift toward targets (called 60fps)
    private func interpolateLevels() {
        withAnimation(.easeInOut(duration: 0.016)) {
            for i in 0..<barCount {
                // Smooth lerp: ~15% per frame → takes ~15 frames (~250ms) to reach target
                animatedLevels[i] += (targetLevels[i] - animatedLevels[i]) * 0.15
            }
        }
    }
}
