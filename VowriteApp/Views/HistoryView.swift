import SwiftUI
import SwiftData

struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    @Query(sort: \DictationRecord.createdAt, order: .reverse) private var records: [DictationRecord]
    @State private var searchText = ""

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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                Text("History")
                    .font(.largeTitle.bold())
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
                        Text("数据仅保存在本地设备，不会上传到任何服务器。")
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

                // Search
                TextField("搜索历史记录...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 20)

                // Records
                if filteredRecords.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "mic.badge.plus")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text("暂无听写记录")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                        ForEach(groupedRecords, id: \.0) { section, sectionRecords in
                            Section {
                                ForEach(sectionRecords) { record in
                                    HistoryRow(record: record)
                                    Divider()
                                        .padding(.leading, 100)
                                        .padding(.trailing, 28)
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
    }
}

struct HistoryRow: View {
    let record: DictationRecord

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter.string(from: record.createdAt)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Time
            Text(timeString)
                .font(.system(.callout, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 75, alignment: .trailing)
                .padding(.top, 2)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(record.polishedText)
                    .font(.body)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 12)
    }
}
