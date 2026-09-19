import Foundation
import SwiftData

/// A record produced by the keyboard extension, pending import into SwiftData.
/// Written as JSON to the App Group shared container's pending-records/ directory.
/// The container app removes each payload only after its SwiftData save succeeds.
public struct PendingRecord: Codable {
    public let id: UUID
    public let rawTranscript: String
    public let polishedText: String
    public let duration: TimeInterval
    public let createdAt: Date

    public init(rawTranscript: String, polishedText: String, duration: TimeInterval) {
        self.id = UUID()
        self.rawTranscript = rawTranscript
        self.polishedText = polishedText
        self.duration = duration
        self.createdAt = Date()
    }
}

public enum PendingRecordStore {
    public struct Entry {
        public let record: PendingRecord
        public let fileURL: URL
    }

    public struct LoadResult {
        public let entries: [Entry]
        public let malformedFiles: [URL]
    }

    public struct ImportResult {
        public let insertedCount: Int
        public let duplicateCount: Int
        public let malformedFiles: [URL]
    }

    private static var pendingDir: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: VowriteStorage.appGroupID)?
            .appendingPathComponent("pending-records", isDirectory: true)
    }

    /// Keyboard extension calls this to save a pending record
    public static func save(_ record: PendingRecord) {
        guard let dir = pendingDir else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("\(record.id.uuidString).json")
        try? JSONEncoder().encode(record).write(to: file)
    }

    /// Reads pending records without deleting them. The container app acknowledges
    /// entries only after its SwiftData transaction has committed.
    public static func load() -> LoadResult {
        guard let pendingDir else { return LoadResult(entries: [], malformedFiles: []) }
        return load(from: pendingDir)
    }

    /// Directory-injected form used by tests. Invalid payloads remain in place so
    /// an import failure never destroys evidence or another queued record.
    public static func load(from directory: URL) -> LoadResult {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return LoadResult(entries: [], malformedFiles: [])
        }

        var entries: [Entry] = []
        var malformedFiles: [URL] = []
        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let record = try? JSONDecoder().decode(PendingRecord.self, from: data) {
                entries.append(Entry(record: record, fileURL: file))
            } else {
                malformedFiles.append(file)
            }
        }
        return LoadResult(
            entries: entries.sorted { $0.record.createdAt < $1.record.createdAt },
            malformedFiles: malformedFiles.sorted { $0.path < $1.path }
        )
    }

    /// Removes only entries that were durably imported. A crash before this call
    /// is safe because the app stores the pending UUID in SwiftData and de-dupes on retry.
    public static func acknowledge(_ entries: [Entry]) throws {
        for entry in entries {
            try FileManager.default.removeItem(at: entry.fileURL)
        }
    }

    /// Imports queued records into SwiftData, then acknowledges only the files
    /// covered by that committed save. UUID de-duplication makes a crash after
    /// save but before acknowledgement safe to retry.
    @MainActor
    public static func importPendingRecords(
        into context: ModelContext,
        from directory: URL? = nil,
        save: (ModelContext) throws -> Void = { try $0.save() }
    ) throws -> ImportResult {
        let loaded = directory.map { load(from: $0) } ?? load()
        var pendingIDs = Set<UUID>()
        var insertedCount = 0
        var duplicateCount = 0

        for entry in loaded.entries {
            let pending = entry.record
            guard pendingIDs.insert(pending.id).inserted else {
                duplicateCount += 1
                continue
            }

            let descriptor = FetchDescriptor<DictationRecord>(predicate: #Predicate { $0.id == pending.id })
            guard try context.fetch(descriptor).isEmpty else {
                duplicateCount += 1
                continue
            }

            let record = DictationRecord(
                rawTranscript: pending.rawTranscript,
                polishedText: pending.polishedText,
                duration: pending.duration,
                detectedLanguage: nil
            )
            record.id = pending.id
            record.createdAt = pending.createdAt
            context.insert(record)
            insertedCount += 1
        }

        if !loaded.entries.isEmpty {
            try save(context)
            try acknowledge(loaded.entries)
        }

        return ImportResult(
            insertedCount: insertedCount,
            duplicateCount: duplicateCount,
            malformedFiles: loaded.malformedFiles
        )
    }
}
