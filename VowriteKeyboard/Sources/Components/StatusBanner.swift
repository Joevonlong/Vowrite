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
                .foregroundStyle(Color(white: 0.6))
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
                        Color(white: 0.2),
                        in: RoundedRectangle(cornerRadius: 8)
                    )
            }
        }
    }
}
