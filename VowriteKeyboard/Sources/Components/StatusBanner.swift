import SwiftUI
import VowriteKit

struct StatusBanner: View {
    let icon: String
    let message: String
    let actionLabel: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(VW.Colors.Status.warning)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(KeyboardTheme.subtitleColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Button(action: action) {
                Text(actionLabel)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(KeyboardTheme.accentText)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .background(
                        KeyboardTheme.accentFill,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
            }
        }
    }
}
