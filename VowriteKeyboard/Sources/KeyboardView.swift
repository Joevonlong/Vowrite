import SwiftUI
import UIKit
import VowriteKit

// MARK: - Theme

enum KeyboardTheme {
    // F-076: opaque backdrop occludes the system UIKeyboardDockView dictation
    // mic. MUST stay opaque (no Color.clear) — reverting re-exposes the mic
    // and is blocked by ops/scripts/test.sh. This intentionally supersedes the
    // earlier clear/translucent choice (commit a936fce): a transparent backdrop
    // let the system dock mic show through the bottom-right. Tuned to
    // approximate the iOS native keyboard backdrop; fine-tune the RGB here
    // (single source of truth) for both light/dark if a seam is visible.
    static let backgroundUIColor = UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(white: 0.07, alpha: 1)
            : UIColor(red: 0.82, green: 0.84, blue: 0.87, alpha: 1)
    }
    static let background = Color(backgroundUIColor)
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
    static let chipActiveTop = Color(red: 0.867, green: 0.910, blue: 1.000)   // #DDE8FF
    static let chipActiveBottom = Color(red: 0.761, green: 0.831, blue: 1.000) // #C2D4FF
    static let chipActiveText = Color(red: 0.114, green: 0.302, blue: 0.847)   // #1D4ED8

    static let actionButtonSize: CGFloat = 44

    // Idle state
    static let micPillWidth: CGFloat = 180
    static let micPillHeight: CGFloat = 64

    // Recording state
    static let recordingCircleDiameter: CGFloat = 150

    // Processing state
    static let thinkingPillWidth: CGFloat = 180
    static let thinkingPillHeight: CGFloat = 56
}

// MARK: - Root View

struct KeyboardView: View {
    @ObservedObject var state: KeyboardState
    @Environment(\.openURL) private var openURL

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

            // F-076: ALWAYS render our own globe (voice mode; keyboard mode
            // renders it inline in KeyboardInputView). Its GlobeKeyButton wires
            // handleInputModeList(from:with:) for .allTouchEvents, which tells
            // iOS this extension owns input-mode switching — so iOS hides its
            // OWN bottom globe+dictation strip (the system mic). Do NOT gate
            // this on needsInputModeSwitchKey/showGlobe: when that is false the
            // wiring disappears and the system re-draws its dock with the mic
            // (the two-tone strip regression). Proven mechanism from 5beffbe.
            if state.inputMode == .voice {
                GlobeKeyButton(inputViewController: state.viewController)
                    .frame(width: 44, height: 44)
                    .padding(.leading, 12)
                    .padding(.bottom, 8)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: state.inputMode)
        .background(KeyboardTheme.background.ignoresSafeArea())
        .onAppear { state.openURLAction = openURL }
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

            RecordArea(state: state)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if state.viewState == .idle && !state.isModeSelectionExpanded {
                VoiceBottomRow(state: state)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: headerKind)
        .animation(.easeInOut(duration: 0.2), value: state.viewState == .idle && !state.isModeSelectionExpanded)
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
                Image(systemName: "dot.radiowaves.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(KeyboardTheme.titleColor)
                Text("Vowrite")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(KeyboardTheme.titleColor)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
    }
}

