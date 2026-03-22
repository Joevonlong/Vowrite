import SwiftUI
import VowriteKit

struct RecordArea: View {
    @ObservedObject var state: KeyboardState

    // Drag-to-cancel state
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    private let cancelThreshold: CGFloat = 80

    var body: some View {
        Group {
            switch state.viewState {
            case .idle:
                idleContent
            case .recording:
                recordingContent
            case .processing:
                processingContent
            case .error(let message):
                errorContent(message)
            case .noMicAccess:
                StatusBanner(
                    icon: "mic.slash.fill",
                    message: "Microphone access denied. Go to Settings → Vowrite → Microphone to enable.",
                    actionLabel: "Open Settings",
                    action: { openContainerApp(path: "settings") }
                )
            case .noFullAccess:
                StatusBanner(
                    icon: "exclamationmark.triangle.fill",
                    message: "Please enable Full Access for Vowrite keyboard",
                    actionLabel: "Open Vowrite",
                    action: { openContainerApp() }
                )
            case .noAPIKey:
                StatusBanner(
                    icon: "key.fill",
                    message: "Please configure API Key in Vowrite App",
                    actionLabel: "Open Vowrite",
                    action: { openContainerApp(path: "settings") }
                )
            case .bgServiceNotRunning:
                StatusBanner(
                    icon: "antenna.radiowaves.left.and.right.slash",
                    message: "Background Recording is not active. Tap to activate.",
                    actionLabel: "Activate",
                    action: { openContainerApp(path: "activate") }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Idle

    private var idleContent: some View {
        VStack(spacing: 12) {
            Text("点击说话")
                .font(.subheadline)
                .foregroundStyle(KeyboardTheme.subtitleColor)

            OrbView(mode: .idle, audioLevel: 0)
                .onTapGesture {
                    state.startRecording()
                }
        }
    }

    // MARK: - Recording

    private var recordingContent: some View {
        ZStack {
            VStack(spacing: 12) {
                // Timer
                Text(formatDuration(state.recordingDuration))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(KeyboardTheme.subtitleColor)

                // Orb with drag gesture
                OrbView(mode: .recording, audioLevel: state.audioLevel)
                    .scaleEffect(isDragging && isInDeleteZone ? 0.7 : 1.0)
                    .offset(y: isDragging ? min(dragOffset, cancelThreshold + 20) : 0)
                    .onTapGesture {
                        state.stopRecording()
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 10)
                            .onChanged { value in
                                let yOffset = value.translation.height
                                if yOffset > 0 {
                                    isDragging = true
                                    dragOffset = yOffset
                                }
                            }
                            .onEnded { _ in
                                if isInDeleteZone {
                                    state.cancelRecording()
                                }
                                withAnimation(.spring(response: 0.3)) {
                                    isDragging = false
                                    dragOffset = 0
                                }
                            }
                    )
                    .animation(.interactiveSpring(), value: isDragging)
            }

            // Delete zone (appears when dragging)
            if isDragging {
                VStack {
                    Spacer()
                    deleteZone
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var isInDeleteZone: Bool {
        dragOffset > cancelThreshold
    }

    private var deleteZone: some View {
        HStack(spacing: 6) {
            Image(systemName: "trash.fill")
                .font(.caption)
            Text("松手取消")
                .font(.caption)
        }
        .foregroundStyle(isInDeleteZone ? .white : Color(UIColor.secondaryLabel))
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isInDeleteZone ? Color.red.opacity(0.8) : Color(UIColor.tertiarySystemFill))
        )
        .padding(.bottom, 4)
    }

    // MARK: - Processing

    private var processingContent: some View {
        VStack(spacing: 12) {
            Text("处理中...")
                .font(.subheadline)
                .foregroundStyle(KeyboardTheme.subtitleColor)

            OrbView(mode: .processing, audioLevel: 0)
        }
    }

    // MARK: - Error

    private func errorContent(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.red)
            Text(message)
                .font(.caption2)
                .foregroundStyle(KeyboardTheme.subtitleColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if case .error = state.viewState {
                    state.reloadConfiguration()
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int((duration - Double(Int(duration))) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }

    private func openContainerApp(path: String = "setup") {
        guard let url = URL(string: "vowrite://\(path)") else { return }
        let selectorModern = NSSelectorFromString("open:options:completionHandler:")
        let selectorLegacy = NSSelectorFromString("openURL:")
        var responder: UIResponder? = state.inputViewController
        while let r = responder {
            if r.responds(to: selectorModern) {
                r.perform(selectorModern, with: url, with: NSDictionary())
                return
            }
            if r.responds(to: selectorLegacy) {
                r.perform(selectorLegacy, with: url)
                return
            }
            responder = r.next
        }
    }
}

// MARK: - Orb View

private struct OrbView: View {
    let mode: OrbMode
    let audioLevel: Float

    enum OrbMode {
        case idle, recording, processing
    }

    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Outer pulse ring (recording only)
            if mode == .recording {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 2)
                    .frame(width: KeyboardTheme.orbDiameter + 16,
                           height: KeyboardTheme.orbDiameter + 16)
                    .scaleEffect(pulseScale)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                            pulseScale = 1.1
                        }
                    }
            }

            // White orb
            Circle()
                .fill(KeyboardTheme.orbFill)
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                .frame(width: KeyboardTheme.orbDiameter,
                       height: KeyboardTheme.orbDiameter)

            // Content inside orb
            Group {
                switch mode {
                case .idle:
                    WaveformView(level: 0, color: KeyboardTheme.orbWaveformColor)
                case .recording:
                    WaveformView(level: audioLevel, color: KeyboardTheme.waveformActiveColor)
                case .processing:
                    ProgressView()
                        .tint(KeyboardTheme.orbWaveformColor)
                        .scaleEffect(1.2)
                }
            }
            .frame(width: KeyboardTheme.orbDiameter * 0.65)
            .clipShape(Circle())
        }
    }
}

// MARK: - Waveform (Sine Wave)

private struct WaveformView: View {
    let level: Float
    var color: Color = Color(UIColor.systemGray)

    @State private var phase: CGFloat = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            SineWaveShape(
                amplitude: amplitude,
                frequency: 2.5,
                phase: phase
            )
            .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            .onChange(of: timeline.date) { _ in
                if level > 0.05 {
                    phase += 0.08
                }
            }
        }
    }

    private var amplitude: CGFloat {
        let normalized = CGFloat(min(max(level, 0), 1))
        let idle: CGFloat = 0.15
        let active: CGFloat = 0.85
        return idle + (active - idle) * normalized
    }
}

private struct SineWaveShape: Shape {
    var amplitude: CGFloat
    var frequency: CGFloat
    var phase: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(amplitude, phase) }
        set {
            amplitude = newValue.first
            phase = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        let maxAmp = rect.height * 0.45 * amplitude
        let steps = Int(rect.width)

        for x in 0...steps {
            let normalizedX = CGFloat(x) / CGFloat(steps)
            // Composite wave: primary + harmonic for organic feel
            let primary = sin(normalizedX * frequency * 2 * .pi + phase)
            let harmonic = sin(normalizedX * frequency * 1.5 * 2 * .pi + phase * 1.3) * 0.3
            // Envelope: fade at edges
            let envelope = sin(normalizedX * .pi)
            let y = midY + maxAmp * (primary + harmonic) * envelope

            if x == 0 {
                path.move(to: CGPoint(x: CGFloat(x), y: y))
            } else {
                path.addLine(to: CGPoint(x: CGFloat(x), y: y))
            }
        }
        return path
    }
}
