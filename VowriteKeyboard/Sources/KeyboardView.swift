import SwiftUI
import VowriteKit

// MARK: - Theme

enum KeyboardTheme {
    static let background = Color(UIColor.secondarySystemBackground)
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

    /// True when the keyboard is actively recording or processing (full-screen mode).
    /// Also true while the F-064 long-press 口述/翻译 selection arcs are visible,
    /// so the TopBar collapses out of the way during the gesture.
    private var isFullScreen: Bool {
        state.viewState == .recording
            || state.viewState == .processing
            || state.isModeSelectionExpanded
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            VStack(spacing: 0) {
                // F-067: Top spacer that grows during the long-press
                // bulk-delete gesture, providing space for the popup to
                // render above the delete button. Driven by
                // KeyboardState.extraTopHeight; KeyboardViewController
                // resizes the keyboard's heightAnchor in lockstep.
                if !isFullScreen && state.extraTopHeight > 0 {
                    Color.clear
                        .frame(height: state.extraTopHeight)
                        .allowsHitTesting(false)
                }

                if !isFullScreen {
                    TopBar(state: state)
                        .frame(height: 48)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                RecordArea(state: state)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .animation(.easeInOut(duration: 0.3), value: isFullScreen)
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
