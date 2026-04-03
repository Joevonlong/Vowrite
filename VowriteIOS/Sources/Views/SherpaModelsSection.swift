import SwiftUI
import VowriteKit

struct SherpaLocalModelsList: View {
    @StateObject private var modelManager = SherpaModelManager.shared

    var body: some View {
        ForEach(SherpaModelManager.availableModels) { model in
            SherpaModelRowiOS(model: model, modelManager: modelManager)
        }
    }
}

private struct SherpaModelRowiOS: View {
    let model: SherpaModelManager.ModelInfo
    @ObservedObject var modelManager: SherpaModelManager

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.name)
                    .font(.body)
                Text("\(model.size) · \(model.languages)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let progress = modelManager.downloadProgress[model.id] {
                ProgressView(value: progress)
                    .frame(width: 80)
            } else if modelManager.downloadedModels.contains(model.id) {
                Button(role: .destructive) {
                    try? modelManager.deleteModel(model.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            } else {
                Button("Download") {
                    Task {
                        try? await modelManager.downloadModel(model)
                    }
                }
                .buttonStyle(.borderless)
            }
        }
    }
}
