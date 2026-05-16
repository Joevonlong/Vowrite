// swiftlint:disable file_length
import SwiftUI
import UIKit
import VowriteKit

struct RecordArea: View {
    @ObservedObject var state: KeyboardState

    // Drag-to-cancel state (used during recording)
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    // F-070: Long-press chip-selection state. Gesture-local (only
    // `isModeSelectionExpanded` is mirrored to KeyboardState).
    @State private var isPressing = false
    @State private var hoveredPosition: KeyboardChipDescriptor.Position? = nil
    @State private var expandWorkItem: DispatchWorkItem?

    private let cancelThreshold: CGFloat = 80
    private let longPressThreshold: TimeInterval = 0.35
    private let modeSelectionCoordSpace = "modeSelection"

    /// F-070: Chip metadata. `Position` reserves all four corners so future
    /// modes can be added by appending to `enabledChips` with no layout or
    /// gesture changes. `Action` is the dispatch payload on release.
    struct KeyboardChipDescriptor: Identifiable {
        enum Position: Hashable { case topLeft, topRight, bottomLeft, bottomRight }
        enum Action { case dictate, translate }

        let id = UUID()
        let position: Position
        let label: String
        let action: Action
    }

    /// Currently rendered chips. Top-left = 口述, top-right = 翻译.
    /// Bottom-left / bottom-right are reserved (not rendered, not hit-tested) —
    /// per F-070 spec § 2.6 and joe's "暂时不显示任何东西" requirement.
    private var enabledChips: [KeyboardChipDescriptor] {
        [
            .init(position: .topLeft,  label: "口述", action: .dictate),
            .init(position: .topRight, label: "翻译", action: .translate),
        ]
    }

    private func chip(at position: KeyboardChipDescriptor.Position) -> KeyboardChipDescriptor? {
        enabledChips.first { $0.position == position }
    }

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
        }
    }

    /// F-070: Idle layout that supports both quick-tap (start dictation) and
    /// long-press → chip selection. After expansion, the mic pill morphs into
    /// a small circle at the bottom, and large chips appear in the top corners.
    /// Hit testing is by quadrant — finger anywhere in the top-left/top-right
    /// quadrant triggers the corresponding chip; everything else is cancel.
    /// Quick tap (no long-press) falls back to direct dictation.
    ///
    /// The mic is a single, persistent View whose frame and position animate
    /// when `isModeSelectionExpanded` toggles — instead of swapping between
    /// two separate views inside an `if/else`. The previous structure caused
    /// SwiftUI to tear down the idle mic mid-press, canceling the active
    /// DragGesture and silently breaking hover detection / chip selection.
    /// Visual layers are non-interactive so touches always reach the mic's
    /// gesture recognizer; the chips' `.glassEffect(.interactive())` would
    /// otherwise intercept the drag once it crossed into a chip on iOS 26+.
    private var interactiveIdleContent: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack(alignment: .topLeading) {
                hintsLayer(in: size)
                    .allowsHitTesting(false)

                if state.isModeSelectionExpanded {
                    chipsLayer
                        .allowsHitTesting(false)
                        .transition(
                            .opacity.combined(with: .scale(scale: 0.92, anchor: .top))
                        )

                    Ripple()
                        .position(x: size.width / 2, y: micCenterY(in: size))
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }

                micShape(
                    width: state.isModeSelectionExpanded ? 56 : 170,
                    height: state.isModeSelectionExpanded ? 56 : 60,
                    shadowOpacity: state.isModeSelectionExpanded ? 0.18 : 0.10
                )
                .scaleEffect(isPressing && !state.isModeSelectionExpanded ? 0.96 : 1.0)
                .animation(.easeOut(duration: 0.12), value: isPressing)
                .position(x: size.width / 2, y: micCenterY(in: size))
                .contentShape(Capsule())
                .gesture(modeSelectionGesture(in: size))

            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .coordinateSpace(name: modeSelectionCoordSpace)
        }
    }

    /// Idle mic sits in the upper third (so the Return pill below remains
    /// visible); expanded mic sits 28pt above the bottom edge with the ripple
    /// ringing it.
    private func micCenterY(in size: CGSize) -> CGFloat {
        state.isModeSelectionExpanded
            ? size.height - 28 - 28
            : 56 + 30
    }

    /// Top hint sits at a fixed Y; the "松开以取消" mid-hint, when expanded,
    /// is anchored above the ripple via an explicit Y rather than a fixed
    /// `Spacer(height:)`. The 232pt content area (280pt keyboard − 48pt
    /// TopBar) is too short for the spec's relative spacing, so absolute
    /// positioning is the only reliable way to keep the hint clear of the
    /// ripple/mic at the bottom.
    @ViewBuilder
    private func hintsLayer(in size: CGSize) -> some View {
        VStack(spacing: 0) {
            Text(state.isModeSelectionExpanded ? "向上滑动以选择" : "点击说话")
                .font(.subheadline)
                .foregroundStyle(KeyboardTheme.subtitleColor)
                .padding(.top, state.isModeSelectionExpanded ? 14 : 28)
                .animation(.easeInOut(duration: 0.18), value: state.isModeSelectionExpanded)
            Spacer()
        }
        .frame(maxWidth: .infinity)

        if state.isModeSelectionExpanded {
            Text("松开以取消")
                .font(.subheadline)
                .foregroundStyle(
                    hoveredPosition == nil
                        ? KeyboardTheme.subtitleColor
                        : Color(UIColor.quaternaryLabel)
                )
                .frame(maxWidth: .infinity)
                .position(x: size.width / 2, y: 105)
                .animation(.easeInOut(duration: 0.15), value: hoveredPosition)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var chipsLayer: some View {
        VStack {
            HStack(spacing: 0) {
                if let leftChip = chip(at: .topLeft) {
                    chipPill(leftChip)
                } else {
                    chipPlaceholder
                }
                Spacer(minLength: 32)
                if let rightChip = chip(at: .topRight) {
                    chipPill(rightChip)
                } else {
                    chipPlaceholder
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 38)

            Spacer()
        }
    }

    /// Empty slot for a not-yet-enabled corner chip. Keeps the HStack layout
    /// stable when only one of the top chips is enabled.
    private var chipPlaceholder: some View {
        Color.clear.frame(width: 140, height: 52)
    }

    /// Single source of truth for the mic visual. Capsule is intentional —
    /// at width == height it renders as a circle, so the same shape spans
    /// the pill (170×60) and circle (56×56) endpoints; SwiftUI animates the
    /// frame change directly when `isModeSelectionExpanded` flips.
    private func micShape(width: CGFloat, height: CGFloat, shadowOpacity: Double) -> some View {
        Capsule()
            .fill(KeyboardTheme.accentFill)
            .frame(width: width, height: height)
            .shadow(color: .black.opacity(shadowOpacity), radius: 8, y: 4)
            .overlay {
                Image(systemName: "mic.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(KeyboardTheme.accentText)
            }
    }

    /// Shared mic pill appearance used by activation Link.
    private var micPillLabel: some View {
        Capsule()
            .fill(KeyboardTheme.accentFill)
            .frame(width: KeyboardTheme.micPillWidth,
                   height: KeyboardTheme.micPillHeight)
            .shadow(color: .black.opacity(0.14), radius: 8, y: 4)
            .overlay {
                Image(systemName: "mic.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(KeyboardTheme.accentText)
            }
    }

    // MARK: - F-070 Chip + Gesture

    private func chipPill(_ descriptor: KeyboardChipDescriptor) -> some View {
        let isActive = (hoveredPosition == descriptor.position)
        return Text(descriptor.label)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(isActive ? KeyboardTheme.chipActiveText : Color(UIColor.label))
            .frame(width: 140, height: 52)
            .modifier(KeyboardChipBackground(isActive: isActive))
            .offset(y: isActive ? -2 : 0)
            .animation(.spring(response: 0.22, dampingFraction: 0.85), value: isActive)
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
            let newPosition = computeHoveredPosition(at: value.location, in: size)
            // Only emit hover for positions that map to an enabled chip.
            let resolved = (newPosition != nil && chip(at: newPosition!) != nil)
                ? newPosition
                : nil
            if resolved != hoveredPosition {
                hoveredPosition = resolved
                if resolved != nil {
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }
        }
    }

    private func handleModeGestureEnded(value: DragGesture.Value, in size: CGSize) {
        expandWorkItem?.cancel()
        expandWorkItem = nil

        let wasExpanded = state.isModeSelectionExpanded
        let pickedAction = hoveredPosition.flatMap { chip(at: $0)?.action }

        // Reset gesture-local state regardless of outcome.
        isPressing = false
        hoveredPosition = nil
        if wasExpanded {
            withAnimation(.easeOut(duration: 0.22)) {
                state.isModeSelectionExpanded = false
            }
        }

        if wasExpanded {
            switch pickedAction {
            case .dictate:
                state.startRecording()
            case .translate:
                state.startTranslateRecording()
            case .none:
                // Released in cancel zone (bottom half / disabled corner) →
                // dismiss without action.
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

    /// F-070: Quadrant-based hit testing. The content area is split into
    /// 4 corner quadrants by the midline cross; the bottom half (regardless
    /// of left/right) is the cancel zone. Returns the quadrant the finger is
    /// in; whether it triggers a chip is decided by the caller (only enabled
    /// chips count). No central dead zone — joe explicitly requested simple
    /// quadrant judgment ("不要做过细的点按判定").
    private func computeHoveredPosition(at location: CGPoint, in size: CGSize) -> KeyboardChipDescriptor.Position? {
        let midY = size.height / 2
        guard location.y < midY else { return nil }
        let midX = size.width / 2
        return location.x < midX ? .topLeft : .topRight
    }

    // MARK: - Recording

    /// Dictation and translation share the same recording primitives (mic
    /// circle + waveform + drag-to-cancel) but need different vertical
    /// compositions: dictation runs the original "hint above circle" VStack;
    /// translation needs banner-top / circle-center / hint-bottom with all
    /// three sitting in their own band.
    ///
    /// The 232pt content area is too tight to compose both with the same
    /// VStack — a 150pt circle + 50pt glow already eats 200pt, leaving only
    /// 32pt for the banner *and* hint, so SwiftUI's centering pushes the
    /// glow ring up under the banner. Splitting the layouts lets the
    /// translate variant shrink the circle (110+26 glow → 136pt) and pin
    /// the banner / hint to the top / bottom edges where they can't overlap
    /// the glow.
    @ViewBuilder
    private var recordingContent: some View {
        ZStack {
            if state.isInTranslateSession {
                translateRecordingLayout
            } else {
                dictateRecordingLayout
            }

            // Delete zone (appears when dragging down) — shared by both
            // modes.
            if isDragging {
                VStack {
                    Spacer()
                    deleteZone
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    /// Original dictation layout — hint above circle, full-size 150pt
    /// circle with 50pt glow ring, centered with bottom padding.
    private var dictateRecordingLayout: some View {
        VStack(spacing: 24) {
            dismissHint
            interactiveCircle(
                diameter: KeyboardTheme.recordingCircleDiameter,
                glowExtra: 50
            )
        }
        .padding(.bottom, 20)
    }

    /// Translation layout — banner top, circle center (smaller so banner
    /// and hint stay clear of the glow ring), hint bottom. Each band lives
    /// in its own VStack inside the ZStack so the layout is robust to
    /// keyboard height changes (drag offset, etc.) and the three elements
    /// never share a vertical band.
    private var translateRecordingLayout: some View {
        ZStack {
            // 1) Banner pinned to top. `.allowsHitTesting(false)` keeps
            // taps falling through to the circle even when the user
            // releases over the banner area.
            VStack(spacing: 0) {
                translationBanner
                    .padding(.top, 12)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
            .transition(.move(edge: .top).combined(with: .opacity))
            .zIndex(1)

            // 2) Circle centered. 110pt diameter + 26pt glow = 136pt
            // visual; with the 232pt content area that leaves ~48pt above
            // (banner + gap) and ~48pt below (hint + gap) — both clear of
            // the glow ring.
            interactiveCircle(diameter: 110, glowExtra: 26)

            // 3) Hint pinned to bottom. Same hit-test passthrough as the
            // banner so the circle owns the entire recording-area surface.
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                dismissHint
                    .padding(.bottom, 18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
        }
    }

    /// Mic circle + glow + waveform with the standard interaction stack
    /// (tap-to-stop, drag-down-to-cancel, delete-zone scale + offset).
    /// Diameter and glow are parameterised so dictation and translation
    /// can share the gesture wiring while picking their own visual size.
    private func interactiveCircle(diameter: CGFloat, glowExtra: CGFloat) -> some View {
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
                        startRadius: diameter * 0.45,
                        endRadius: diameter * 0.65
                    )
                )
                .frame(width: diameter + glowExtra, height: diameter + glowExtra)

            // White circle
            Circle()
                .fill(.white)
                .frame(width: diameter, height: diameter)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 2)

            // Bar waveform
            BarWaveformView(level: state.audioLevel)
                .frame(width: diameter * 0.45, height: diameter * 0.35)
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
            Text(localizedTranslateBannerText)
                .font(.footnote)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color.black.opacity(0.85)))
    }

    /// The banner is read by the *speaker*, not by the recipient of the
    /// translated text — so the prompt template and the language name both
    /// resolve in the speaker's locale (`Locale.current`). A Chinese user
    /// translating to English sees "正在翻译为 英文"; an English user
    /// translating to Chinese sees "Translating to Chinese (Simplified)".
    /// Falls back to the raw code when the OS locale db has no localised
    /// name for it (very rare).
    private var localizedTranslateBannerText: String {
        let code = state.translationTargetCode
        let langName = Locale.current.localizedString(forIdentifier: code)
            ?? Locale.current.localizedString(forLanguageCode: code)
            ?? code
        let primary = Locale.current.language.languageCode?.identifier ?? "en"
        if primary.hasPrefix("zh") {
            return "正在翻译为 \(langName)"
        } else {
            return "Translating to \(langName)"
        }
    }

    private var dismissHint: some View {
        Text("再次点击以完成")
            .font(.subheadline)
            .foregroundStyle(KeyboardTheme.subtitleColor)
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

/// Vertical bar waveform that responds to voice activity rather than raw
/// amplitude. Once `level` crosses `voiceThreshold` the bars snap to full
/// envelope (with per-bar wobble for an organic feel); silence relaxes them
/// back to a low idle envelope. This binary VAD design — instead of mapping
/// `level` linearly to height — gives the user a clear "system is hearing me"
/// signal even with quiet speech, where raw RMS bars barely move.
///
/// `level` arrives via IPC at ~10Hz (post-amp RMS, range 0…1). The TimelineView
/// runs at 60fps to keep wobble smooth independent of the data cadence.
private struct BarWaveformView: View {
    let level: Float

    private let barCount = 7
    private let baseHeights: [CGFloat] = [0.4, 0.6, 0.8, 1.0, 0.8, 0.6, 0.4]

    /// Post-amp RMS threshold separating voiced frames from silence/room noise.
    /// `BackgroundRecordingService.calculateRMS` multiplies raw RMS by 5 and
    /// clamps to 1.0; speech sits ~0.05–0.5, room noise ~0.005–0.02. 0.05 is
    /// the same floor the silence detector uses, so anything that reaches STT
    /// also lights up the bars.
    private static let voiceThreshold: Float = 0.05

    private static let activeAmplitude: CGFloat = 1.0
    private static let idleAmplitude: CGFloat = 0.30

    @State private var amplitude: CGFloat = idleAmplitude

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate

                HStack(alignment: .center, spacing: 3) {
                    ForEach(0..<barCount, id: \.self) { i in
                        let wobble = CGFloat(
                            sin(time * 4.5 + Double(i) * 0.85) * 0.22 + 1.0
                        )
                        let barH = baseHeights[i] * amplitude * wobble * geo.size.height

                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.black.opacity(0.85))
                            .frame(width: 4, height: max(4, barH))
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .onChange(of: level) { _, newLevel in
            let target: CGFloat = newLevel > Self.voiceThreshold
                ? Self.activeAmplitude
                : Self.idleAmplitude
            guard target != amplitude else { return }
            // Faster attack (snap to "I hear you") than release (relax back so
            // brief gaps between words don't strobe the bars).
            let duration: Double = target == Self.activeAmplitude ? 0.12 : 0.32
            withAnimation(.easeOut(duration: duration)) {
                amplitude = target
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

// MARK: - F-070 Ripple

/// 4 concentric stroke rings centered on the expanded mic. Static — no
/// animation, no audio reactivity. The expanded state is *pre-recording*
/// (audio level is 0), so animated rings would be visual noise without
/// information. Acts as a visual "ground" anchoring the small mic circle.
private struct Ripple: View {
    /// Sized to fit inside the 232pt content area below the "松开以取消"
    /// hint at y≈115 — outer ring radius 52pt keeps the topmost arc clear of
    /// the hint when centered on the mic at y≈176. Visually proportional to
    /// the 56pt mic (outer ≈ 1.86× mic), close to the mockup's relative scale.
    private let rings: [(diameter: CGFloat, alpha: Double)] = [
        (60,  0.060),
        (76,  0.045),
        (92,  0.030),
        (104, 0.018),
    ]

    var body: some View {
        ZStack {
            ForEach(rings.indices, id: \.self) { i in
                Circle()
                    .stroke(Color(white: 0.3, opacity: rings[i].alpha), lineWidth: 1)
                    .frame(width: rings[i].diameter, height: rings[i].diameter)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - F-070 Chip background (Liquid Glass + iOS 17 fallback)

/// Background fill + shadow for a chip pill. Splits along iOS 26 vs ≤25 —
/// the former gets native `.glassEffect`, the latter falls back to
/// `.ultraThinMaterial` plus a manual gradient + stroke. Active state
/// applies a pale-blue tint per the mockup either way.
private struct KeyboardChipBackground: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            modernGlass(content: content)
        } else {
            legacyFallback(content: content)
        }
    }

    @available(iOS 26.0, *)
    private func modernGlass(content: Content) -> some View {
        content
            .background {
                if isActive {
                    Capsule().fill(activeGradient)
                }
            }
            .glassEffect(.regular.interactive(), in: .capsule)
            .shadow(
                color: isActive
                    ? KeyboardTheme.chipActiveText.opacity(0.32)
                    : .black.opacity(0.10),
                radius: isActive ? 8 : 6,
                y: isActive ? 8 : 6
            )
    }

    private func legacyFallback(content: Content) -> some View {
        content
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        if isActive {
                            Capsule().fill(activeGradient)
                        } else {
                            Capsule().fill(idleGradient)
                        }
                    }
                    .overlay {
                        Capsule().strokeBorder(.white.opacity(0.55), lineWidth: 0.5)
                    }
            }
            .shadow(
                color: isActive
                    ? KeyboardTheme.chipActiveText.opacity(0.32)
                    : .black.opacity(0.10),
                radius: isActive ? 8 : 6,
                y: isActive ? 8 : 6
            )
    }

    private var activeGradient: LinearGradient {
        LinearGradient(
            colors: [KeyboardTheme.chipActiveTop, KeyboardTheme.chipActiveBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var idleGradient: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.95), Color.white.opacity(0.72)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
