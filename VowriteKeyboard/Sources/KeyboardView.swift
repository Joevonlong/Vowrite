import SwiftUI
import UIKit
import VowriteKit

// MARK: - Theme

enum KeyboardTheme {
    // F-076: backdrop stays CLEAR so the iOS system keyboard backdrop shows
    // through — this gives ONE uniform tone edge-to-edge (matching Typeless).
    // A custom opaque override produced a two-tone seam vs. the system dock
    // band and was reverted. The system dictation mic is suppressed purely by
    // the Info.plist declaration (PrimaryLanguage=mul, IsASCIICapable), the
    // same approach Typeless uses — NOT by painting over the dock. Do not
    // re-introduce a custom opaque background here.
    static let background = Color.clear
    static let buttonFill = Color(UIColor.systemGray5)
    static let titleColor = Color(UIColor.label)
    static let subtitleColor = Color(UIColor.secondaryLabel)
    static let iconColor = Color(UIColor.label)

    // Typeless-parity palette. Regular keys ride the system gray ramp so they
    // adapt automatically (light: pale gray, dark: charcoal). The primary
    // action surface (record pill, return key) intentionally INVERTS against
    // the backdrop — `label` over `systemBackground` — so it reads as a solid
    // white block on dark and a solid black block on light. Never hardcode a
    // fixed white/black here: the keyboard tracks the system appearance and a
    // fixed color goes invisible in one of the two modes.
    static let keyFill = Color(UIColor.systemGray5)        // letter/space keys
    static let specialKeyFill = Color(UIColor.systemGray4) // 123 / shift / delete
    static let accentFill = Color(UIColor.label)           // record pill, return
    static let accentText = Color(UIColor.systemBackground)
    static let keyCornerRadius: CGFloat = 8

    // F-070 chip active palette (matches mockup pale-blue active state)
    static let chipActiveTop = VW.Colors.Action.soft
    static let chipActiveBottom = VW.Colors.Action.soft
    static let chipActiveText = VW.Colors.Action.primary

    static let actionButtonSize: CGFloat = 44

    // Idle state
    static let micPillWidth: CGFloat = 180
    static let micPillHeight: CGFloat = 64

    // Recording state
    static let recordingCircleDiameter: CGFloat = 112

    // Processing state
    static let thinkingPillWidth: CGFloat = 180
    static let thinkingPillHeight: CGFloat = 56
}

// MARK: - Root View

struct KeyboardView: View {
    @ObservedObject var state: KeyboardState
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showModes = false

    private enum HeaderKind { case full, compact }

    private var headerKind: HeaderKind {
        if state.inputMode == .keyboard { return .full }
        switch state.viewState {
        case .recording, .processing: return .compact
        default: return .full
        }
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if state.inputMode == .voice {
                voiceContent
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .center)))
            } else {
                keyboardContent
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .center)))
            }

            // F-076: we render NO globe of our own. iOS already provides the
            // next-keyboard globe in its system keyboard dock at the bottom;
            // drawing our own produced a duplicate globe. Matching Typeless:
            // rely on the single system dock globe; the dictation mic next to
            // it is suppressed by the Info.plist declaration. Do not add a
            // GlobeKeyButton here.
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: state.inputMode)
        .background(KeyboardTheme.background.ignoresSafeArea())
        .onAppear { state.openURLAction = openURL }
        .transaction { transaction in
            if reduceMotion { transaction.animation = nil; transaction.disablesAnimations = true }
        }
    }

    @ViewBuilder
    private var voiceContent: some View {
        VStack(spacing: 0) {
            switch headerKind {
            case .full:
                TopBar(state: state)
                    .frame(height: 48)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            case .compact:
                RecordingHeader()
                    .frame(height: 48)
                    .transition(.opacity)
            }

            if state.viewState == .idle && !state.isModeSelectionExpanded {
                expressionControls
            }

            RecordArea(state: state)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if state.viewState == .idle && !state.isModeSelectionExpanded {
                VoiceBottomRow(state: state)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: headerKind)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: state.viewState == .idle && !state.isModeSelectionExpanded)
    }

    private var expressionControls: some View {
        HStack(spacing: 4) {
            Spacer(minLength: 0)
            Button { showModes = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: state.currentMode.icon)
                    Text(state.currentMode.name).lineLimit(1)
                    Image(systemName: "chevron.down").font(.caption2)
                }
                .font(.subheadline)
                .frame(minHeight: 44)
            }
            .popover(isPresented: $showModes) {
                ModePopover(state: state, isPresented: $showModes)
            }
            .accessibilityLabel("Expression scene, \(state.currentMode.name)")
            Button { state.startTranslateRecording() } label: {
                Label("Translate", systemImage: "globe")
                    .font(.subheadline)
                    .frame(minHeight: 44)
            }
            .disabled(state.needsActivation)
            Spacer(minLength: 0)
            VoiceDeleteButton(state: state)
                .frame(width: 44, height: 44)
                .accessibilityLabel("Delete")
                .accessibilityHint("Hold to delete continuously. Slide up to choose a larger deletion.")
        }
        .foregroundStyle(KeyboardTheme.subtitleColor)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var keyboardContent: some View {
        VStack(spacing: 0) {
            TopBar(state: state)
                .frame(height: 48)
            KeyboardInputView(state: state)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Recording Header

private struct RecordingHeader: View {
    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "waveform")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(KeyboardTheme.titleColor)
                Text("Vowrite")
                    .font(.system(.title3, design: .default).weight(.bold))
                    .fontWeight(.bold)
                    .foregroundStyle(KeyboardTheme.titleColor)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
    }
}

