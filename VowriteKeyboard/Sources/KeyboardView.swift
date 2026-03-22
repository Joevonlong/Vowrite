import SwiftUI
import VowriteKit

// MARK: - Theme

enum KeyboardTheme {
    static let background = Color(red: 28/255, green: 28/255, blue: 30/255)
    static let buttonFill = Color(red: 44/255, green: 44/255, blue: 46/255)
    static let titleColor = Color(UIColor.label)
    static let subtitleColor = Color(UIColor.secondaryLabel)
    static let iconColor = Color(UIColor.label)
    static let orbFill = Color.white
    static let orbWaveformColor = Color(UIColor.systemGray)
    static let waveformActiveColor = Color(UIColor.systemGray2)

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
        .background(KeyboardTheme.background.ignoresSafeArea())
    }
}
