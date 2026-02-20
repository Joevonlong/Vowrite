import SwiftUI
import SwiftData

struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    @Query(sort: \DictationRecord.createdAt, order: .reverse) private var records: [DictationRecord]
    @State private var searchText = ""
    @State private var selectedRecord: DictationRecord?

    var filteredRecords: [DictationRecord] {
        if searchText.isEmpty { return records }
        return records.filter {
            $0.polishedText.localizedCaseInsensitiveContains(searchText) ||
            $0.rawTranscript.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationSplitView {
            List(filteredRecords, selection: $selectedRecord) { record in
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.polishedText)
                        .lineLimit(2)
                        .font(.body)
                    HStack {
                        Text(record.createdAt, style: .relative)
                        Text("·")
                        Text(String(format: "%.1fs", record.duration))
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
                .tag(record)
            }
            .searchable(text: $searchText)
            .navigationTitle("History")
        } detail: {
            if let record = selectedRecord {
                RecordDetailView(record: record)
            } else {
                ContentUnavailableView("Select a dictation", systemImage: "doc.text", description: Text("Choose from the list to see details"))
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

struct RecordDetailView: View {
    let record: DictationRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Polished text
                GroupBox("Polished") {
                    Text(record.polishedText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Raw transcript
                GroupBox("Raw Transcript") {
                    Text(record.rawTranscript)
                        .textSelection(.enabled)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Metadata
                GroupBox("Info") {
                    LabeledContent("Date", value: record.createdAt.formatted())
                    LabeledContent("Duration", value: String(format: "%.1f seconds", record.duration))
                    if let lang = record.detectedLanguage {
                        LabeledContent("Language", value: lang)
                    }
                }

                // Actions
                HStack {
                    Button("Copy Polished") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(record.polishedText, forType: .string)
                    }
                    Button("Copy Raw") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(record.rawTranscript, forType: .string)
                    }
                }
            }
            .padding()
        }
    }
}
