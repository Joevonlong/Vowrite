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
        hosting.frame = NSRect(x: 0, y: 0, width: 220, height: 42)

        let win = NonActivatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 42),
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
            let x = screenFrame.midX - 110
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
            // Cancel button
            Button {
                appState.cancelRecording()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)

            // Waveform
            WaveformView(level: appState.audioLevel)
                .frame(maxWidth: .infinity)
                .frame(height: 22)
                .padding(.horizontal, 6)

            // Confirm button
            Button {
                appState.stopRecording()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
        }
        .frame(width: 220, height: 42)
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
    let barCount = 10

    @State private var animatedLevels: [Float] = Array(repeating: 0, count: 10)
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 3, height: barHeight(for: index))
            }
        }
        .onAppear { startAnimation() }
        .onDisappear { timer?.invalidate() }
        .onChange(of: level) { _, _ in updateLevels() }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let minHeight: CGFloat = 3
        let maxHeight: CGFloat = 18
        let level = CGFloat(animatedLevels[index])
        return minHeight + (maxHeight - minHeight) * level
    }

    private func startAnimation() {
        // Update at 15fps for smooth animation
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 15.0, repeats: true) { _ in
            Task { @MainActor in
                updateLevels()
            }
        }
    }

    private func updateLevels() {
        withAnimation(.easeOut(duration: 0.08)) {
            for i in 0..<barCount {
                // Create wave pattern: center bars react more to audio level
                let centerDistance = abs(Float(i) - Float(barCount) / 2.0) / (Float(barCount) / 2.0)
                let baseLevel = level * (1.0 - centerDistance * 0.5)

                // Add randomness for natural feel
                let randomFactor = Float.random(in: 0.3...1.0)
                let targetLevel = baseLevel * randomFactor

                // Smooth towards target
                animatedLevels[i] = animatedLevels[i] * 0.3 + targetLevel * 0.7
            }
        }
    }
}
