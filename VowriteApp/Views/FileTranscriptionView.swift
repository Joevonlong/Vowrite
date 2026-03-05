import SwiftUI
import UniformTypeIdentifiers

/// F-020: File transcription UI — drag & drop or file picker
struct FileTranscriptionView: View {
    @State private var isDragging = false
    @State private var isProcessing = false
    @State private var progressMessage = ""
    @State private var result: FileTranscriptionService.TranscriptionResult?
    @State private var errorMessage: String?
    @State private var enablePolish = true
    @State private var copied = false

    private let service = FileTranscriptionService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("File Transcription")
                    .font(.system(size: 24, weight: .bold))

                Text("Upload an audio or video file to transcribe it to text.")
                    .font(.body)
                    .foregroundColor(.secondary)

                // Drop zone
                dropZone

                // Options
                Toggle("AI Polish after transcription", isOn: $enablePolish)

                // Supported formats
                Text("Supported: \(FileTranscriptionService.supportedExtensions.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Progress
                if isProcessing {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(progressMessage)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }

                // Error
                if let error = errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                // Result
                if let result = result {
                    resultView(result)
                }
            }
            .padding(32)
        }
    }

    // MARK: - Drop Zone

    private var dropZone: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.doc.fill")
                .font(.system(size: 36))
                .foregroundColor(isDragging ? .accentColor : .secondary)

            Text(isDragging ? "Drop to transcribe" : "Drag & drop a file here")
                .font(.headline)
                .foregroundColor(isDragging ? .accentColor : .primary)

            Text("or")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("Choose File...") { pickFile() }
                .buttonStyle(.bordered)
                .disabled(isProcessing)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isDragging ? Color.accentColor : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                )
        )
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDragging ? Color.accentColor.opacity(0.05) : Color.clear)
        )
        .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
            handleDrop(providers)
            return true
        }
    }

    // MARK: - Result View

    private func resultView(_ result: FileTranscriptionService.TranscriptionResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Transcription Result")
                    .font(.headline)
                Spacer()
                Text(formatDuration(result.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button {
                    let text = result.polishedText ?? result.rawText
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                } label: {
                    Label(copied ? "Copied!" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            // Show polished result if available
            if let polished = result.polishedText {
                Text("Polished")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontWeight(.semibold)
                Text(polished)
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.06))
                    .cornerRadius(8)

                // Raw transcript collapsible
                DisclosureGroup("Raw transcript") {
                    Text(result.rawText)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                        .padding(8)
                }
                .font(.caption)
            } else {
                Text(result.rawText)
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.06))
                    .cornerRadius(8)
            }
        }
    }

    // MARK: - Actions

    private func pickFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = FileTranscriptionService.supportedExtensions.compactMap {
            UTType(filenameExtension: $0)
        }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        transcribeFile(url)
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            Task { @MainActor in
                transcribeFile(url)
            }
        }
    }

    private func transcribeFile(_ url: URL) {
        guard !isProcessing else { return }
        isProcessing = true
        errorMessage = nil
        result = nil
        progressMessage = "Starting..."

        Task {
            do {
                let res = try await service.transcribe(
                    fileURL: url,
                    polish: enablePolish,
                    language: LanguageConfig.globalLanguage.whisperCode
                ) { msg in
                    Task { @MainActor in progressMessage = msg }
                }
                result = res
            } catch {
                errorMessage = error.localizedDescription
            }
            isProcessing = false
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if mins == 0 { return "\(secs)s" }
        return "\(mins)m \(secs)s"
    }
}
