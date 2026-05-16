import SwiftUI
import UIKit
import VowriteKit

// MARK: - Theme

enum KeyboardTheme {
    /// Transparent — let UIInputViewController's default keyboard backdrop
    /// (system blur material) show through.
    static let background = Color.clear
    static let buttonFill = Color(UIColor.systemGray5)
    static let titleColor = Color(UIColor.label)
    static let subtitleColor = Color(UIColor.secondaryLabel)
    static let iconColor = Color(UIColor.label)

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

            // Globe key — voice mode only; keyboard mode integrates globe in its bottom row
            if state.showGlobe && state.inputMode == .voice {
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

