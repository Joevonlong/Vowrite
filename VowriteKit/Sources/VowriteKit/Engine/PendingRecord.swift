import Foundation

/// A record produced by the keyboard extension, pending import into SwiftData.
/// Written as JSON to the App Group shared container's pending-records/ directory.
/// Container App imports and deletes these on launch.
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

    /// Container App calls this to read and delete all pending records
    public static func consumeAll() -> [PendingRecord] {
        guard let dir = pendingDir,
              let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        else { return [] }

        var records: [PendingRecord] = []
        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let record = try? JSONDecoder().decode(PendingRecord.self, from: data) {
                records.append(record)
                try? FileManager.default.removeItem(at: file)
            }
        }
        return records.sorted { $0.createdAt < $1.createdAt }
    }
}
