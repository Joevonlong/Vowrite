import VowriteKit
import SwiftUI
import SwiftData

struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var navigation = MainWindowNavigation.shared
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

    // V-3 perf fix: DateFormatter is expensive to allocate/configure; hoist it out
    // of the per-record closure (was reconstructed for every non-today record on
    // every body evaluation) into a single shared instance. Output is unchanged.
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var groupedRecords: [(String, [DictationRecord])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredRecords) { record -> String in
            if calendar.isDateInToday(record.createdAt) {
                return "Today"
            } else if calendar.isDateInYesterday(record.createdAt) {
                return "Yesterday"
            } else {
                return Self.dayFormatter.string(from: record.createdAt)
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
        ScrollViewReader { scroll in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("History").font(.system(size: 32, weight: .semibold))
                            Text("Find the words you want to keep.")
                                .foregroundStyle(VW.Colors.Text.secondary)
                        }
                        Spacer()
                        Text("\(filteredRecords.count) records")
                            .font(.callout).foregroundStyle(VW.Colors.Text.secondary)
                            .padding(.top, 8)
                    }

                    if appState.historyUnavailable { historyUnavailableBanner }

                    Label("Your history stays on this device.", systemImage: "lock.shield")
                        .font(.callout)
                        .foregroundStyle(VW.Colors.Text.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(VW.Colors.Surface.secondary, in: RoundedRectangle(cornerRadius: VW.Radius.control))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Search history").font(.callout.weight(.medium))
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass").foregroundStyle(VW.Colors.Text.secondary)
                            TextField("Search original and polished text", text: $searchText)
                                .textFieldStyle(.plain)
                                .accessibilityLabel("Search history")
                                .accessibilityIdentifier("history.search")
                            if !searchText.isEmpty {
                                Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                                    .buttonStyle(.plain).accessibilityLabel("Clear search")
                            }
                        }
                        .padding(12)
                        .background(VW.Colors.Surface.panel, in: RoundedRectangle(cornerRadius: VW.Radius.control))
                        .overlay(RoundedRectangle(cornerRadius: VW.Radius.control).stroke(VW.Colors.Border.standard))
                    }

                    if isSelecting {
                        HStack(spacing: 12) {
                            Text("\(selectedRecords.count) selected").fontWeight(.medium)
                            Spacer()
                            Button("Deselect All") { selectedRecords.removeAll() }
                            Button(role: .destructive) { showDeleteConfirm = true } label: {
                                Label("Delete Selected", systemImage: "trash")
                            }
                        }
                        .font(.callout)
                        .padding(16)
                        .background(VW.Colors.Action.soft, in: RoundedRectangle(cornerRadius: VW.Radius.control))
                    } else if !records.isEmpty {
                        HStack {
                            Spacer()
                            Button("Select All") { selectedRecords = Set(filteredRecords.map(\.id)) }
                                .font(.callout).buttonStyle(.borderless)
                        }
                    }

                    if filteredRecords.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: searchText.isEmpty ? "text.bubble" : "magnifyingglass")
                                .font(.system(size: 32)).foregroundStyle(VW.Colors.Text.secondary)
                            Text(searchText.isEmpty ? "Your words will appear here" : "No matching dictations")
                                .font(.headline)
                            Text(searchText.isEmpty ? "Complete your first voice input to build your history." : "Try a different search or clear the filter.")
                                .foregroundStyle(VW.Colors.Text.secondary)
                            if !searchText.isEmpty {
                                Button("Clear search") { searchText = "" }
                            } else {
                                Button("Go to overview") { WindowHelper.openMainWindow(destination: .overview) }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 56)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 24) {
                            ForEach(groupedRecords, id: \.0) { section, sectionRecords in
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(section).font(.callout.weight(.semibold))
                                        .foregroundStyle(VW.Colors.Text.secondary)
                                    VStack(spacing: 0) {
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
                                            .id(record.id)
                                            if record.id != sectionRecords.last?.id {
                                                Divider().padding(.horizontal, 24)
                                            }
                                        }
                                    }
                                    .background(VW.Colors.Surface.panel, in: RoundedRectangle(cornerRadius: VW.Radius.panel))
                                    .overlay(RoundedRectangle(cornerRadius: VW.Radius.panel).stroke(VW.Colors.Border.standard))
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: 1040, alignment: .leading)
                .padding(32)
                .frame(maxWidth: .infinity)
            }
            .onAppear { revealRecord(navigation.historyRecordID, scroll: scroll) }
            .onChange(of: navigation.historyRecordID) { _, recordID in revealRecord(recordID, scroll: scroll) }
            .background(VW.Colors.Surface.canvas)
            .frame(minWidth: 500, minHeight: 400)
            .alert("Delete \(selectedRecords.count) record(s)?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) { batchDelete() }
            } message: {
                Text("This action cannot be undone.")
            }
        }

    }

    private func revealRecord(_ recordID: UUID?, scroll: ScrollViewProxy) {
        guard let recordID else { return }
        searchText = ""
        expandedRecord = recordID
        DispatchQueue.main.async { scroll.scrollTo(recordID, anchor: .center) }
    }

    private var historyUnavailableBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("History temporarily unavailable", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(VW.Colors.Status.warning)
            Text("This session won't be saved to history. Restart the app or check disk space.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VW.Colors.Surface.secondary)
        .cornerRadius(8)
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
            do {
                try modelContext.save()
            } catch {
                Log.history.error("Failed to save after deleteRecord: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func batchDelete() {
        withAnimation {
            for record in records where selectedRecords.contains(record.id) {
                modelContext.delete(record)
            }
            do {
                try modelContext.save()
            } catch {
                Log.history.error("Failed to save after batchDelete: \(error.localizedDescription, privacy: .public)")
            }
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

    // V-3 perf fix: hoisted out of the per-row computed property (was
    // reconstructed on every row's body evaluation). Output is unchanged.
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter
    }()

    private var timeString: String {
        Self.timeFormatter.string(from: record.createdAt)
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
        HStack(alignment: .top, spacing: 16) {
            Button(action: onToggleSelect) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? VW.Colors.Action.primary : VW.Colors.Text.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSelected ? "Deselect dictation" : "Select dictation")
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text(timeString)
                    Text("·")
                    Text(durationString)
                    if record.wasTranslation == true {
                        Label("Translation", systemImage: "globe")
                    }
                }
                .font(.caption).monospacedDigit()
                .foregroundStyle(VW.Colors.Text.secondary)

                Text(record.polishedText)
                    .font(.body)
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(isExpanded ? nil : 3)

                if isExpanded && hasPolishDiff {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Original transcript").font(.caption.weight(.semibold))
                        Text(record.rawTranscript)
                            .font(.callout).lineSpacing(4)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(VW.Colors.Text.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(VW.Colors.Surface.secondary, in: RoundedRectangle(cornerRadius: VW.Radius.control))
                }

                HStack(spacing: 16) {
                    Button(action: onToggleExpand) {
                        Label(isExpanded ? "Collapse" : hasPolishDiff ? "View & compare" : "View full text", systemImage: isExpanded ? "chevron.up" : "text.alignleft")
                    }
                    .foregroundStyle(VW.Colors.Action.primary)
                    Button {
                        onCopy()
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { copied = false }
                    } label: {
                        Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    .foregroundStyle(copied ? VW.Colors.Status.success : VW.Colors.Text.secondary)
                    Spacer(minLength: 0)
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Image(systemName: "trash").frame(width: 28, height: 28)
                    }
                    .foregroundStyle(VW.Colors.Text.secondary)
                    .accessibilityLabel("Delete dictation")
                }
                .font(.callout)
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        .background(isSelected ? VW.Colors.Action.soft : .clear, in: RoundedRectangle(cornerRadius: VW.Radius.panel))
        .alert("Delete this record?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { onDelete() }
        } message: {
            Text("This action cannot be undone.")
        }
    }
}
