import SwiftUI
import VowriteKit

// MARK: - Theme

enum KeyboardTheme {
    /// Transparent — let UIInputViewController's default keyboard backdrop
    /// (system blur material) show through. This avoids a visible color block
    /// vs. the system area above the keyboard, matching how Typeless / system
    /// keyboards render edge-to-edge.
    static let background = Color.clear
    static let buttonFill = Color(UIColor.systemGray5)
    static let titleColor = Color(UIColor.label)
    static let subtitleColor = Color(UIColor.secondaryLabel)
    static let iconColor = Color(UIColor.label)

    static let actionButtonSize: CGFloat = 44

    // Idle state
    static let micPillWidth: CGFloat = 180
    static let micPillHeight: CGFloat = 64

    static let returnPillWidth: CGFloat = 160
    static let returnPillHeight: CGFloat = 40

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

    /// Controls which header sits above the RecordArea.
    /// - `.full`: idle TopBar with logo + action buttons (@, ─, delete).
    /// - `.compact`: minimal logo-only header (recording/processing). Mirrors the
    ///   reference design (e.g. Typeless) where the brand stays anchored top-left
    ///   throughout the dictation lifecycle so the user always knows which
    ///   keyboard is active.
    /// - `.hidden`: no header at all (mode-selection arcs need the room).
    private enum HeaderKind { case full, compact, hidden }

    private var headerKind: HeaderKind {
        if state.isModeSelectionExpanded { return .hidden }
        switch state.viewState {
        case .recording, .processing: return .compact
        default: return .full
        }
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            VStack(spacing: 0) {
                // F-067: Top spacer that grows during the long-press
                // bulk-delete gesture, providing space for the popup to
                // render above the delete button. Driven by
                // KeyboardState.extraTopHeight; KeyboardViewController
                // resizes the keyboard's heightAnchor in lockstep.
                if headerKind == .full && state.extraTopHeight > 0 {
                    Color.clear
                        .frame(height: state.extraTopHeight)
                        .allowsHitTesting(false)
                }

                switch headerKind {
                case .full:
                    TopBar(state: state)
                        .frame(height: 48)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                case .compact:
                    RecordingHeader()
                        .frame(height: 48)
                        .transition(.opacity)
                case .hidden:
                    EmptyView()
                }

                RecordArea(state: state)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .animation(.easeInOut(duration: 0.3), value: headerKind)
            .animation(.easeOut(duration: 0.22), value: state.extraTopHeight)

            // Globe key — always visible at bottom-left
            if state.showGlobe {
                GlobeKeyButton(inputViewController: state.viewController)
                    .frame(width: 44, height: 44)
                    .padding(.leading, 12)
                    .padding(.bottom, 8)
            }
        }
        .background(KeyboardTheme.background.ignoresSafeArea())
        .onAppear { state.openURLAction = openURL }
    }
}

// MARK: - Recording Header

/// Logo-only header rendered while a dictation is active. Action buttons (@, ─,
/// delete) are intentionally omitted — during recording/processing they would
/// either conflict with the gesture surface (delete) or be irrelevant (text
/// insertion). Keeping just the brand mark mirrors the reference design where
/// the logo stays pinned top-left throughout the session.
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
