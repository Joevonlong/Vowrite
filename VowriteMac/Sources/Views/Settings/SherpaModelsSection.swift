import SwiftUI
import VowriteKit

struct SherpaLocalModelsSection: View {
    @StateObject private var modelManager = SherpaModelManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Download models for fully offline speech recognition. No API key or internet connection required during recording.")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(SherpaModelManager.availableModels) { model in
                SherpaModelRow(model: model, modelManager: modelManager)
            }
        }
    }
}

private struct SherpaModelRow: View {
    let model: SherpaModelManager.ModelInfo
    @ObservedObject var modelManager: SherpaModelManager

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.name)
                    .font(.body.weight(.medium))
                Text("\(model.size) · \(model.languages)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let progress = modelManager.downloadProgress[model.id] {
                ProgressView(value: progress)
                    .frame(width: 100)
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 36, alignment: .trailing)
            } else if modelManager.downloadedModels.contains(model.id) {
                Label("Downloaded", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption.weight(.medium))
                Button("Delete") {
                    try? modelManager.deleteModel(model.id)
                }
                .buttonStyle(.link)
                .font(.caption)
                .foregroundColor(.red)
            } else {
                Button("Download") {
                    Task {
                        try? await modelManager.downloadModel(model)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}
