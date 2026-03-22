import SwiftUI
import VowriteKit

// MARK: - Theme

enum KeyboardTheme {
    static let background = Color.black
    static let buttonFill = Color(white: 0.2)
    static let titleColor = Color.white
    static let subtitleColor = Color(white: 0.6)
    static let iconColor = Color.white
    static let orbFill = Color.white
    static let orbWaveformColor = Color(white: 0.55)
    static let waveformActiveColor = Color(white: 0.4)

    static let orbDiameter: CGFloat = 126
    static let actionButtonSize: CGFloat = 44
    static let returnButtonWidth: CGFloat = 200
    static let returnButtonHeight: CGFloat = 36
    static let returnButtonCornerRadius: CGFloat = 18
}

// MARK: - Root View

struct KeyboardView: View {
    @ObservedObject var state: KeyboardState

    var body: some View {
        VStack(spacing: 0) {
            TopBar(state: state)
                .frame(height: 48)

            RecordArea(state: state)
                .frame(maxHeight: .infinity)

            BottomBar(state: state)
                .frame(height: 48)
        }
        .background(KeyboardTheme.background)
        .preferredColorScheme(.dark)
    }
}
