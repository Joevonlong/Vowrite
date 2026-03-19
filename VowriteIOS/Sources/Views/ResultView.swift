import SwiftUI
import VowriteKit

struct ResultView: View {
    let rawTranscript: String
    let polishedText: String
    let duration: TimeInterval
    let createdAt: Date

    @State private var showCopied = false
    @State private var showRaw = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Metadata
                HStack {
                    Label(formattedDate, systemImage: "calendar")
                    Spacer()
                    Label(formattedDuration, systemImage: "timer")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Divider()

                // Polished text
                VStack(alignment: .leading, spacing: 8) {
                    Text("Polished Text")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    Text(polishedText)
                        .font(.body)
                        .textSelection(.enabled)
                }

                // Raw transcript (collapsible)
                if rawTranscript != polishedText {
                    DisclosureGroup("Raw Transcript", isExpanded: $showRaw) {
                        Text(rawTranscript)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .padding(.top, 4)
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                }

                Divider()

                // Action buttons
                HStack(spacing: 12) {
                    Button {
                        UIPasteboard.general.string = polishedText
                        showCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showCopied = false
                        }
                    } label: {
                        Label(showCopied ? "Copied!" : "Copy",
                              systemImage: showCopied ? "checkmark.circle.fill" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    ShareLink(item: polishedText) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding(20)
        }
        .navigationTitle("Result")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var formattedDate: String {
        createdAt.formatted(date: .abbreviated, time: .shortened)
    }

    private var formattedDuration: String {
        let seconds = Int(duration)
        if seconds < 60 {
            return "\(seconds)s"
        }
        return "\(seconds / 60)m \(seconds % 60)s"
    }
}
