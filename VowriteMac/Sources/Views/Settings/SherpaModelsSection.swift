import SwiftUI
import VowriteKit

struct SherpaLocalModelsSection: View {
    @StateObject private var modelManager = SherpaModelManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Download models for fully offline speech recognition. No API key or internet connection required during recording.")
                .font(.caption)
                .foregroundColor(VW.Colors.Text.secondary)

            ForEach(SherpaModelManager.availableModels) { model in
                SherpaModelRow(model: model, modelManager: modelManager)
                if model.id != SherpaModelManager.availableModels.last?.id {
                    Divider()
                }
            }
        }
    }
}

private struct SherpaModelRow: View {
    let model: SherpaModelManager.ModelInfo
    @ObservedObject var modelManager: SherpaModelManager
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "cpu")
                    .font(.system(size: 18))
                    .foregroundStyle(VW.Colors.Text.secondary)
                    .frame(width: 40, height: 40)
                    .background(VW.Colors.Surface.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: VW.Radius.control))
                    .overlay(RoundedRectangle(cornerRadius: VW.Radius.control).stroke(VW.Colors.Border.standard))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.name)
                        .font(.body.weight(.medium))
                    Text("\(model.size) · \(model.languages)")
                        .font(.caption)
                        .foregroundColor(VW.Colors.Text.secondary)
                }

                Spacer()

                if let progress = modelManager.downloadProgress[model.id] {
                    ProgressView(value: progress)
                        .frame(width: 100)
                        .accessibilityLabel("Downloading \(model.name)")
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(VW.Colors.Text.secondary)
                        .frame(width: 36, alignment: .trailing)
                } else if modelManager.downloadedModels.contains(model.id) {
                    Label("Downloaded", systemImage: "checkmark.circle.fill")
                        .foregroundColor(VW.Colors.Status.success)
                        .font(.caption.weight(.medium))
                    Button("Delete") {
                        do {
                            try modelManager.deleteModel(model.id)
                            errorMessage = nil
                        } catch {
                            errorMessage = error.localizedDescription
                            Log.models.error("Failed to delete model \(model.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
                        }
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                    .foregroundColor(VW.Colors.Status.error)
                } else {
                    Button("Download") {
                        Task {
                            do {
                                _ = try await modelManager.downloadModel(model)
                                errorMessage = nil
                            } catch {
                                errorMessage = error.localizedDescription
                                Log.models.error("Failed to download model \(model.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle")
                    .font(.system(size: 13))
                    .foregroundColor(VW.Colors.Status.error)
            }
        }
        .padding(.vertical, VW.Spacing.xl)
    }
}
