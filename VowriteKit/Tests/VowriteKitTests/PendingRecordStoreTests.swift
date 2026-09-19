import Foundation
import SwiftData
import XCTest
@testable import VowriteKit

@MainActor
final class PendingRecordStoreTests: XCTestCase {
    private enum ForcedSaveFailure: Error {
        case forced
    }

    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PendingRecordStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testFailedSaveRetainsFileThenRetryPersistsOneOriginalRecord() throws {
        let record = try writePendingRecord()
        let container = try makeContainer()

        do {
            let failingContext = ModelContext(container)
            failingContext.autosaveEnabled = false
            XCTAssertThrowsError(
                try PendingRecordStore.importPendingRecords(
                    into: failingContext,
                    from: directory
                ) { _ in
                    throw ForcedSaveFailure.forced
                }
            )
        }

        let file = directory.appendingPathComponent("\(record.id.uuidString).json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))

        let retryContext = ModelContext(container)
        let result = try PendingRecordStore.importPendingRecords(into: retryContext, from: directory)
        XCTAssertEqual(result.insertedCount, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))

        let records = try fetchRecords(from: ModelContext(container))
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.id, record.id)
        XCTAssertEqual(records.first?.createdAt, record.createdAt)
    }

    func testExistingPendingIDFromPostSaveCrashIsAcknowledgedWithoutDuplicate() throws {
        let record = try writePendingRecord()
        let container = try makeContainer()
        let context = ModelContext(container)
        let existing = DictationRecord(
            rawTranscript: record.rawTranscript,
            polishedText: record.polishedText,
            duration: record.duration,
            detectedLanguage: nil
        )
        existing.id = record.id
        existing.createdAt = record.createdAt
        context.insert(existing)
        try context.save()

        let result = try PendingRecordStore.importPendingRecords(into: context, from: directory)

        XCTAssertEqual(result.insertedCount, 0)
        XCTAssertEqual(result.duplicateCount, 1)
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: directory.appendingPathComponent("\(record.id.uuidString).json").path
            )
        )
        let records = try fetchRecords(from: ModelContext(container))
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.id, record.id)
        XCTAssertEqual(records.first?.createdAt, record.createdAt)
    }

    func testImportRetainsMalformedPayloadWhileAcknowledgingValidRecord() throws {
        let record = try writePendingRecord()
        let malformedFile = directory.appendingPathComponent("malformed.json")
        try Data("not json".utf8).write(to: malformedFile)

        let container = try makeContainer()
        let result = try PendingRecordStore.importPendingRecords(
            into: ModelContext(container),
            from: directory
        )

        XCTAssertEqual(result.insertedCount, 1)
        XCTAssertEqual(result.malformedFiles.map(\.lastPathComponent), [malformedFile.lastPathComponent])
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: directory.appendingPathComponent("\(record.id.uuidString).json").path
            )
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: malformedFile.path))
    }

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: DictationRecord.self, configurations: configuration)
    }

    private func writePendingRecord() throws -> PendingRecord {
        let record = PendingRecord(rawTranscript: "raw", polishedText: "polished", duration: 1)
        let file = directory.appendingPathComponent("\(record.id.uuidString).json")
        try JSONEncoder().encode(record).write(to: file)
        return record
    }

    private func fetchRecords(from context: ModelContext) throws -> [DictationRecord] {
        try context.fetch(FetchDescriptor<DictationRecord>())
    }
}
