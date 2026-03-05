import SwiftUI
import SwiftData

struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DictationRecord.createdAt, order: .reverse) private var records: [DictationRecord]
    @State private var searchText = ""
    @State private var selectedRecords = Set<UUID>()
    @State private var showDeleteConfirm = false
    @State private var expandedRecord: UUID?

    var filteredRecords: [DictationRecord] {
        if searchText.isEmpty { return records }
        return records.filter {
            $0.polishedText.localizedCaseInsensitiveContains(searchText) ||
            $0.rawTranscript.localizedCaseInsensitiveContains(searchText)
        }
    }

    var groupedRecords: [(String, [DictationRecord])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredRecords) { record -> String in
            if calendar.isDateInToday(record.createdAt) {
                return "Today"
            } else if calendar.isDateInYesterday(record.createdAt) {
                return "Yesterday"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter.string(from: record.createdAt)
            }
        }
        return grouped.sorted { a, b in
            if a.key == "Today" { return true }
            if b.key == "Today" { return false }
            if a.key == "Yesterday" { return true }
            if b.key == "Yesterday" { return false }
            return a.key > b.key
        }
    }

    private var isSelecting: Bool { !selectedRecords.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text("History")
                        .font(.largeTitle.bold())
                    Spacer()
                    if !records.isEmpty {
                        Text("\(filteredRecords.count) record(s)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 8)

                // Privacy note card
                HStack(spacing: 10) {
                    Image(systemName: "lock.shield")
                        .font(.body)
                        .foregroundColor(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your data stays private")
                            .font(.subheadline.weight(.medium))
                        Text("All data is stored locally on your device only.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.03))
                .cornerRadius(8)
                .padding(.horizontal, 28)
                .padding(.bottom, 16)

                // Search + batch actions
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search history...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(8)
                .padding(.horizontal, 28)
                .padding(.bottom, 8)

                // Batch action bar
                if isSelecting {
                    HStack(spacing: 12) {
                        Text("\(selectedRecords.count) selected")
                            .font(.caption).fontWeight(.medium)
                        Spacer()
                        Button("Deselect All") { selectedRecords.removeAll() }
                            .font(.caption)
                        Button(role: .destructive) { showDeleteConfirm = true } label: {
                            Label("Delete Selected", systemImage: "trash")
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.06))
                } else if !records.isEmpty {
                    HStack {
                        Spacer()
                        Button("Select All") {
                            selectedRecords = Set(filteredRecords.map(\.id))
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 4)
                }

                // Records
                if filteredRecords.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "mic.badge.plus")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text(searchText.isEmpty ? "No dictation records yet" : "No results for \"\(searchText)\"")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                        ForEach(groupedRecords, id: \.0) { section, sectionRecords in
                            Section {
                                ForEach(sectionRecords) { record in
                                    HistoryRow(
                                        record: record,
                                        isSelected: selectedRecords.contains(record.id),
                                        isExpanded: expandedRecord == record.id,
                                        onToggleSelect: { toggleSelection(record) },
                                        onToggleExpand: { toggleExpand(record) },
                                        onCopy: { copyRecord(record) },
                                        onDelete: { deleteRecord(record) }
                                    )
                                    if record.id != sectionRecords.last?.id {
                                        Divider()
                                            .padding(.leading, 100)
                                            .padding(.trailing, 28)
                                    }
                                }
                            } header: {
                                Text(section)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 28)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.background)
                            }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .alert("Delete \(selectedRecords.count) record(s)?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { batchDelete() }
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private func toggleSelection(_ record: DictationRecord) {
        if selectedRecords.contains(record.id) {
            selectedRecords.remove(record.id)
        } else {
            selectedRecords.insert(record.id)
        }
    }

    private func toggleExpand(_ record: DictationRecord) {
        withAnimation(.easeInOut(duration: 0.2)) {
            expandedRecord = (expandedRecord == record.id) ? nil : record.id
        }
    }

    private func copyRecord(_ record: DictationRecord) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(record.polishedText, forType: .string)
    }

    private func deleteRecord(_ record: DictationRecord) {
        withAnimation {
            modelContext.delete(record)
            try? modelContext.save()
        }
    }

    private func batchDelete() {
        withAnimation {
            for record in records where selectedRecords.contains(record.id) {
                modelContext.delete(record)
            }
            try? modelContext.save()
            selectedRecords.removeAll()
        }
    }
}

// MARK: - History Row (enhanced)

struct HistoryRow: View {
    let record: DictationRecord
    let isSelected: Bool
    let isExpanded: Bool
    let onToggleSelect: () -> Void
    let onToggleExpand: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false
    @State private var copied = false

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter.string(from: record.createdAt)
    }

    private var durationString: String {
        let secs = Int(record.duration)
        if secs < 60 { return "\(secs)s" }
        return "\(secs / 60)m \(secs % 60)s"
    }

    private var hasPolishDiff: Bool {
        record.rawTranscript != record.polishedText
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Selection checkbox
            Button(action: onToggleSelect) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary.opacity(0.4))
                    .font(.body)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            // Time + duration
            VStack(alignment: .trailing, spacing: 2) {
                Text(timeString)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundColor(.secondary)
                Text(durationString)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .frame(width: 65, alignment: .trailing)
            .padding(.top, 2)

            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Polished text
                Text(record.polishedText)
                    .font(.body)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(isExpanded ? nil : 3)

                // Expanded: show raw vs polished comparison
                if isExpanded && hasPolishDiff {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Raw transcript")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .fontWeight(.semibold)
                        Text(record.rawTranscript)
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(8)
                            .background(Color.secondary.opacity(0.06))
                            .cornerRadius(6)
                    }
                    .padding(.top, 4)
                }

                // Action buttons
                HStack(spacing: 12) {
                    if hasPolishDiff {
                        Button(action: onToggleExpand) {
                            Label(isExpanded ? "Collapse" : "Compare", systemImage: isExpanded ? "chevron.up" : "arrow.left.arrow.right")
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                    }

                    Button {
                        onCopy()
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { copied = false }
                    } label: {
                        Label(copied ? "Copied!" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(copied ? .green : .secondary)

                    Spacer()

                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Image(systemName: "trash")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary.opacity(0.5))
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 12)
        .background(isSelected ? Color.accentColor.opacity(0.04) : Color.clear)
        .alert("Delete this record?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { onDelete() }
        }
    }
}
