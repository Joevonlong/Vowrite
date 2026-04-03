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
                    action: { state.openContainerApp(path: "settings") }
                )
            case .noFullAccess:
                StatusBanner(
                    icon: "exclamationmark.triangle.fill",
                    message: "Please enable Full Access for Vowrite keyboard",
                    actionLabel: "Open Vowrite",
                    action: { state.openContainerApp(path: "setup") }
                )
            case .noAPIKey:
                StatusBanner(
                    icon: "key.fill",
                    message: "Please configure API Key in Vowrite App",
                    actionLabel: "Open Vowrite",
                    action: { state.openContainerApp(path: "settings") }
                )
            case .bgServiceNotRunning:
                StatusBanner(
                    icon: "antenna.radiowaves.left.and.right.slash",
                    message: "Background Recording is not active. Tap to activate.",
                    actionLabel: "Activate",
                    action: { state.openContainerApp(path: "activate") }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Idle

    private var idleContent: some View {
        VStack(spacing: 16) {
            Text(state.needsActivation ? "点击激活" : "点击说话")
                .font(.subheadline)
                .foregroundStyle(KeyboardTheme.subtitleColor)

            // Pill-shaped mic button
            Button {
                state.startRecording()
            } label: {
                Capsule()
                    .fill(.white)
                    .frame(width: KeyboardTheme.micPillWidth,
                           height: KeyboardTheme.micPillHeight)
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                    .overlay {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(.black)
                    }
            }
            .opacity(state.needsActivation ? 0.6 : 1.0)

            // Return / 换行 button
            Button {
                state.insertReturn()
            } label: {
                Text("换行")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(KeyboardTheme.subtitleColor)
                    .frame(width: KeyboardTheme.returnPillWidth,
                           height: KeyboardTheme.returnPillHeight)
                    .background(KeyboardTheme.buttonFill, in: Capsule())
            }
        }
    }

    // MARK: - Recording

    private var recordingContent: some View {
        ZStack {
            VStack(spacing: 24) {
                // Hint text
                Text("再次点击以完成")
                    .font(.subheadline)
                    .foregroundStyle(KeyboardTheme.subtitleColor)

                // Circle with glow ring + bar waveform
                ZStack {
                    // Outer glow ring
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(white: 0.18),
                                    KeyboardTheme.background
                                ],
                                center: .center,
                                startRadius: KeyboardTheme.recordingCircleDiameter * 0.45,
                                endRadius: KeyboardTheme.recordingCircleDiameter * 0.65
                            )
                        )
                        .frame(
                            width: KeyboardTheme.recordingCircleDiameter + 50,
                            height: KeyboardTheme.recordingCircleDiameter + 50
                        )

                    // White circle
                    Circle()
                        .fill(.white)
                        .frame(
                            width: KeyboardTheme.recordingCircleDiameter,
                            height: KeyboardTheme.recordingCircleDiameter
                        )
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 2)

                    // Bar waveform
                    BarWaveformView(level: state.audioLevel)
                        .frame(
                            width: KeyboardTheme.recordingCircleDiameter * 0.45,
                            height: KeyboardTheme.recordingCircleDiameter * 0.35
                        )
                }
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
            .padding(.bottom, 20)

            // Delete zone (appears when dragging down)
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
        ThinkingPill()
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
}

// MARK: - Bar Waveform (Equalizer)

/// Vertical bar waveform that responds to audio level.
/// Bars follow a bell-curve height pattern and fluctuate per-bar
/// for an organic, living feel.
private struct BarWaveformView: View {
    let level: Float

    private let barCount = 7
    private let baseHeights: [CGFloat] = [0.4, 0.6, 0.8, 1.0, 0.8, 0.6, 0.4]

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate

                HStack(alignment: .center, spacing: 3) {
                    ForEach(0..<barCount, id: \.self) { i in
                        let fluctuation = CGFloat(
                            sin(time * 3.0 + Double(i) * 0.8) * 0.15 + 1.0
                        )
                        let normalizedLevel = CGFloat(min(max(level, 0.15), 1.0))
                        let barH = baseHeights[i] * normalizedLevel * fluctuation * geo.size.height

                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.black.opacity(0.8))
                            .frame(width: 4, height: max(4, barH))
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }
}

// MARK: - Thinking Pill (Shimmer)

/// Capsule with a sliding shimmer highlight, shown during processing.
private struct ThinkingPill: View {
    @State private var shimmerPhase: CGFloat = 0

    var body: some View {
        Capsule()
            .fill(Color(white: 0.90))
            .frame(width: KeyboardTheme.thinkingPillWidth,
                   height: KeyboardTheme.thinkingPillHeight)
            .overlay {
                // Sliding highlight
                GeometryReader { geo in
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .clear,
                                    Color.white.opacity(0.45),
                                    .clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * 0.5)
                        .offset(x: (shimmerPhase - 0.25) * geo.size.width)
                }
                .clipShape(Capsule())
            }
            .overlay {
                Text("Thinking")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color(UIColor.systemGray))
            }
            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.8)
                    .repeatForever(autoreverses: true)
                ) {
                    shimmerPhase = 1.0
                }
            }
    }
}
