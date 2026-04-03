import SwiftUI
import VowriteKit

// MARK: - Theme

enum KeyboardTheme {
    static let background = Color(red: 28/255, green: 28/255, blue: 30/255)
    static let buttonFill = Color(red: 44/255, green: 44/255, blue: 46/255)
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
    private var isFullScreen: Bool {
        state.viewState == .recording || state.viewState == .processing
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            VStack(spacing: 0) {
                if !isFullScreen {
                    TopBar(state: state)
                        .frame(height: 48)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                RecordArea(state: state)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .animation(.easeInOut(duration: 0.3), value: isFullScreen)

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
