import SwiftUI
import SwiftData
import VowriteKit

struct HistoryView: View {
    @Query(sort: \DictationRecord.createdAt, order: .reverse)
    private var records: [DictationRecord]

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    emptyState
                } else {
                    recordList
                }
            }
            .navigationTitle("History")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Recordings Yet",
            systemImage: "waveform",
            description: Text("Your dictation history will appear here.")
        )
    }

    private var recordList: some View {
        List {
            ForEach(records) { record in
                NavigationLink {
                    ResultView(
                        rawTranscript: record.rawTranscript,
                        polishedText: record.polishedText,
                        duration: record.duration,
                        createdAt: record.createdAt
                    )
                } label: {
                    HistoryRow(record: record)
                }
            }
            .onDelete(perform: deleteRecords)
        }
        .listStyle(.plain)
    }

    private func deleteRecords(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(records[index])
        }
        try? modelContext.save()
    }
}

// MARK: - History Row

struct HistoryRow: View {
    let record: DictationRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(record.polishedText)
                .font(.body)
                .lineLimit(2)

            HStack {
                Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))

                Spacer()

                let seconds = Int(record.duration)
                Text(seconds < 60 ? "\(seconds)s" : "\(seconds / 60)m \(seconds % 60)s")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
