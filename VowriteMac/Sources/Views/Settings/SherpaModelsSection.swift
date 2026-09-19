import SwiftUI
import VowriteKit

struct SherpaLocalModelsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Offline speech recognition is not available yet", systemImage: "exclamationmark.triangle.fill")
                .font(.callout.weight(.semibold))
                .foregroundStyle(VW.Colors.Status.warning)
            Text(
                "The Sherpa recognition engine is not bundled in this build, so local model downloads are unavailable. "
                    + "Choose a supported speech-to-text provider instead."
            )
                .font(.caption)
                .foregroundColor(VW.Colors.Text.secondary)
        }
    }
}
