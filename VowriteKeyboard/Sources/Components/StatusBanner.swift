import SwiftUI

struct StatusBanner: View {
    let icon: String
    let message: String
    let actionLabel: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.orange)

            Text(message)
                .font(.caption)
                .foregroundStyle(KeyboardTheme.subtitleColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Button(action: action) {
                Text(actionLabel)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        KeyboardTheme.buttonFill,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
            }
        }
    }
}
