import SwiftUI
import UIKit
import VowriteKit

struct RecordArea: View {
    @ObservedObject var state: KeyboardState

    // Drag-to-cancel state (used during recording)
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    // F-064: Long-press 口述/翻译 selection state.
    // Lives here (not in KeyboardState) because it's a transient gesture-local
    // state — only `isModeSelectionExpanded` is mirrored to KeyboardState so
    // KeyboardView can collapse the TopBar.
    @State private var isPressing = false
    @State private var hoveredArc: ArcChoice = .none
    @State private var expandWorkItem: DispatchWorkItem?

    private let cancelThreshold: CGFloat = 80
    private let longPressThreshold: TimeInterval = 0.35
    private let modeSelectionCoordSpace = "modeSelection"

    enum ArcChoice { case none, dictate, translate }

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

    // Need-activation case keeps the existing static mic-pill Link.
    // Long-press selection only applies to the active recording entry point.
    @ViewBuilder
    private var idleContent: some View {
        if state.needsActivation {
            activationIdleContent
        } else {
            interactiveIdleContent
        }
    }

    private var activationIdleContent: some View {
        VStack(spacing: 16) {
            Text("点击激活")
                .font(.subheadline)
                .foregroundStyle(KeyboardTheme.subtitleColor)
            Link(destination: URL(string: "vowrite://activate")!) {
                micPillLabel
            }
            .opacity(0.6)
            Button {
                state.insertReturn()
            } label: {
                returnPillLabel
            }
        }
    }

    /// F-064: Idle layout that supports both quick-tap (start dictation) and
    /// long-press → 口述/翻译 arc selection. The two arcs render above the
    /// mic pill location once the press exceeds `longPressThreshold`; finger
    /// position picks the action on release. Releasing in the middle (or
    /// before expansion) without long-pressing falls back to direct dictation.
    private var interactiveIdleContent: some View {
        GeometryReader { geo in
            ZStack {
                // Layer 1 — main column. Mic pill stays mounted as the gesture
                // anchor; it just fades out when arcs take over.
                VStack(spacing: 16) {
                    Text(state.isModeSelectionExpanded ? "向上滑动以选择" : "点击说话")
                        .font(.subheadline)
                        .foregroundStyle(KeyboardTheme.subtitleColor)
                        .animation(.easeInOut(duration: 0.18), value: state.isModeSelectionExpanded)

                    micPillLabel
                        .opacity(state.isModeSelectionExpanded ? 0.0 : 1.0)
                        .scaleEffect(isPressing && !state.isModeSelectionExpanded ? 0.96 : 1.0)
                        .animation(.easeOut(duration: 0.18), value: state.isModeSelectionExpanded)
                        .animation(.easeOut(duration: 0.12), value: isPressing)
                        .contentShape(Capsule())
                        .gesture(modeSelectionGesture(in: geo.size))

                    if !state.isModeSelectionExpanded {
                        Button {
                            state.insertReturn()
                        } label: {
                            returnPillLabel
                        }
                        .transition(.opacity)
                    } else {
                        // Reserve the same vertical space the 换行 button used,
                        // so the mic pill doesn't jump when arcs animate in.
                        Color.clear.frame(height: KeyboardTheme.returnPillHeight)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Layer 2 — arc selection overlay (口述 / 翻译 + cancel hint).
                if state.isModeSelectionExpanded {
                    arcsOverlay
                        .transition(
                            .opacity.combined(with: .scale(scale: 0.92, anchor: .bottom))
                        )
                }
            }
            .coordinateSpace(name: modeSelectionCoordSpace)
        }
    }

    /// Shared mic pill appearance used by Link, gesture target, etc.
    private var micPillLabel: some View {
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

    private var returnPillLabel: some View {
        Text("换行")
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(KeyboardTheme.subtitleColor)
            .frame(width: KeyboardTheme.returnPillWidth,
                   height: KeyboardTheme.returnPillHeight)
            .background(KeyboardTheme.buttonFill, in: Capsule())
    }

    // MARK: - F-064 Mode Selection Arcs

    private var arcsOverlay: some View {
        ZStack {
            VStack(spacing: 0) {
                HStack(spacing: 18) {
                    arcCapsule(label: "口述", choice: .dictate)
                    arcCapsule(label: "翻译", choice: .translate)
                }
                .padding(.top, 18)
                Spacer()
                Text("松开以取消")
                    .font(.subheadline)
                    .foregroundStyle(KeyboardTheme.subtitleColor)
                    .opacity(hoveredArc == .none ? 1.0 : 0.35)
                    .animation(.easeInOut(duration: 0.15), value: hoveredArc)
                    .padding(.bottom, 56)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func arcCapsule(label: String, choice: ArcChoice) -> some View {
        let isHovered = hoveredArc == choice
        return Capsule()
            .fill(isHovered ? Color.white : Color.white.opacity(0.78))
            .frame(width: 138, height: 64)
            .shadow(color: .black.opacity(isHovered ? 0.20 : 0.10), radius: 8, y: 3)
            .overlay {
                Text(label)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.black)
            }
            .scaleEffect(isHovered ? 1.06 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.85), value: isHovered)
    }

    private func modeSelectionGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(modeSelectionCoordSpace))
            .onChanged { value in handleModeGestureChanged(value: value, in: size) }
            .onEnded { value in handleModeGestureEnded(value: value, in: size) }
    }

    private func handleModeGestureChanged(value: DragGesture.Value, in size: CGSize) {
        if !isPressing {
            isPressing = true
            scheduleExpansion()
        }
        if state.isModeSelectionExpanded {
            let newHovered = computeHoveredArc(at: value.location, in: size)
            if newHovered != hoveredArc {
                hoveredArc = newHovered
                if newHovered != .none {
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }
        }
    }

    private func handleModeGestureEnded(value: DragGesture.Value, in size: CGSize) {
        expandWorkItem?.cancel()
        expandWorkItem = nil

        let wasExpanded = state.isModeSelectionExpanded
        let pickedArc = hoveredArc

        // Reset gesture-local state regardless of outcome.
        isPressing = false
        hoveredArc = .none
        if wasExpanded {
            withAnimation(.easeOut(duration: 0.18)) {
                state.isModeSelectionExpanded = false
            }
        }

        if wasExpanded {
            switch pickedArc {
            case .dictate:
                state.startRecording()
            case .translate:
                state.startTranslateRecording()
            case .none:
                // Released in the middle / outside both arcs → cancel cleanly.
                break
            }
        } else {
            // Quick tap (no long-press threshold reached) → direct dictation,
            // preserving the pre-F-064 muscle memory.
            state.startRecording()
        }
    }

    private func scheduleExpansion() {
        let work = DispatchWorkItem { [self] in
            // Only expand if the user is still pressing.
            guard isPressing, !state.isModeSelectionExpanded else { return }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                state.isModeSelectionExpanded = true
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        expandWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + longPressThreshold, execute: work)
    }

    /// Translate the gesture's current location into one of three zones:
    /// left arc (口述), right arc (翻译), or cancel zone. The arc band sits
    /// in the upper portion of the keyboard area; below it is the cancel zone.
    private func computeHoveredArc(at location: CGPoint, in size: CGSize) -> ArcChoice {
        let arcZoneBottom = size.height * 0.55
        if location.y > arcZoneBottom { return .none }
        let midX = size.width / 2
        let deadZone: CGFloat = 28
        if abs(location.x - midX) < deadZone { return .none }
        return location.x < midX ? .dictate : .translate
    }

    // MARK: - Recording

    private var recordingContent: some View {
        ZStack {
            // F-064: Translation banner at top — shown only when this
            // recording was started via the 翻译 arc.
            if state.isInTranslateSession {
                VStack {
                    translationBanner
                        .padding(.top, 12)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1)
            }

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
                                    Color(UIColor.systemGray4),
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

    // MARK: - F-064 Translation Banner

    private var translationBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "globe")
                .font(.footnote)
            Text("Translating to \(state.translationTargetName)")
                .font(.footnote)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color.black.opacity(0.85)))
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
