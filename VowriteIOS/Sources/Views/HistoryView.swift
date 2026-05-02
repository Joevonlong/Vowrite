import SwiftUI
import SwiftData
import VowriteKit

struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    @Query(sort: \DictationRecord.createdAt, order: .reverse)
    private var records: [DictationRecord]

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if appState.historyUnavailable {
                    historyUnavailableBanner
                }
                if records.isEmpty {
                    emptyState
                } else {
                    recordList
                }
            }
            .navigationTitle("History")
        }
    }

    private var historyUnavailableBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("History temporarily unavailable", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundColor(.orange)
            Text("This session and keyboard extension records won't be saved. Check App Group permissions or reinstall the app.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12))
        .cornerRadius(8)
        .padding(.horizontal, 16)
        .padding(.top, 8)
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
