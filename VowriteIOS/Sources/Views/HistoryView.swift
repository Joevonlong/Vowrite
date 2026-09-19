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
                VWIOSPageHeader(title: "Every thought, kept.", subtitle: "Find the words you want to return to.")
                    .padding(24)
                if appState.historyUnavailable {
                    historyUnavailableBanner
                }
                if records.isEmpty {
                    emptyState
                } else {
                    recordList
                }
            }
            .background(VW.Colors.Surface.canvas)
            .tint(VW.Colors.Action.primary)
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
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
        .background(VW.Colors.Status.warning.opacity(0.10))
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
                .listRowBackground(VW.Colors.Surface.panel)
            }
            .onDelete(perform: deleteRecords)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
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
        VStack(alignment: .leading, spacing: 12) {
            Label(record.createdAt.formatted(date: .abbreviated, time: .shortened), systemImage: "waveform")
                .font(.caption)
                .foregroundStyle(VW.Colors.Text.secondary)
            Text(record.polishedText)
                .font(.body)
                .lineLimit(2)

            HStack {
                Text(record.wasTranslation == true ? "Translation" : "Dictation")

                Spacer()

                let seconds = Int(record.duration)
                Text(seconds < 60 ? "\(seconds)s" : "\(seconds / 60)m \(seconds % 60)s")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
    }
}
