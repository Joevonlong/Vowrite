import SwiftUI
import AppKit

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

// MARK: - Floating Recording Bar

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

    func hide() {
        window?.orderOut(nil)
        window = nil
        hostingView = nil
        appState = nil
    }

    private var overlaySize: NSSize {
        switch OverlayStyle.current {
        case .compact: return NSSize(width: 200, height: 42)
        case .normal: return NSSize(width: 260, height: 52)
        }
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

    private var durationText: String {
        let total = Int(appState.recordingDuration)
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: Recording state

    private var recordingBar: some View {
        let isCompact = OverlayStyle.current == .compact
        return HStack(spacing: 0) {
            // Cancel button
            Button { appState.cancelRecording() } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: isCompact ? 32 : 38, height: isCompact ? 32 : 38)
                    Image(systemName: "xmark")
                        .font(.system(size: isCompact ? 13 : 15, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            .padding(.leading, 5)

            // Duration
            Text(durationText)
                .font(.system(size: isCompact ? 11 : 13, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: isCompact ? 32 : 40)

            // Waveform
            WaveformView(level: appState.audioLevel)
                .frame(width: isCompact ? 56 : 80, height: isCompact ? 22 : 28)

            // Recording dot
            Circle()
                .fill(Color.red)
                .frame(width: 6, height: 6)
                .opacity(appState.audioLevel > 0.1 ? 1 : 0.5)
                .padding(.trailing, 4)

            // Confirm button
            Button { appState.stopRecording() } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: isCompact ? 32 : 38, height: isCompact ? 32 : 38)
                    Image(systemName: "checkmark")
                        .font(.system(size: isCompact ? 13 : 15, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            .padding(.trailing, 5)
        }
        .frame(
            width: isCompact ? 200 : 260,
            height: isCompact ? 42 : 52
        )
        .background(
            Capsule()
                .fill(Color.black.opacity(0.85))
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: Processing state

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
    @State private var targetLevels: [Float] = Array(repeating: 0, count: 13)
    @State private var targetTimer: Timer?

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
        let center = Double(barCount) / 2.0
        let dist = abs(Double(index) - center) / center
        return 1.0 - dist * 0.3
    }

    private func startAnimation() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            Task { @MainActor in interpolateLevels() }
        }
        targetTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
            Task { @MainActor in updateTargets() }
        }
    }

    private func updateTargets() {
        let speaking = level > 0.5
        for i in 0..<barCount {
            let center = Float(barCount) / 2.0
            let centerDistance = abs(Float(i) - center) / center
            if speaking {
                let bellCurve: Float = 1.0 - centerDistance * 0.6
                targetLevels[i] = bellCurve * Float.random(in: 0.6...1.0)
            } else {
                targetLevels[i] = 0.05
            }
        }
    }

    private func interpolateLevels() {
        withAnimation(.easeInOut(duration: 0.016)) {
            for i in 0..<barCount {
                animatedLevels[i] += (targetLevels[i] - animatedLevels[i]) * 0.15
            }
        }
    }
}
