import XCTest
@testable import VowriteKit

class ProviderModelMigration202608TestCase: XCTestCase {
    var defaults: UserDefaults!
    var suiteName: String!
    var directory: URL!

    override func setUpWithError() throws {
        suiteName = "ProviderModelMigration202608Tests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProviderModelMigration202608Tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
        defaults = nil
        suiteName = nil
        directory = nil
    }

    func assertPersistentDomainEquals(
        _ expected: [String: Any]?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let current = defaults.persistentDomain(forName: suiteName) ?? [:]
        XCTAssertTrue(
            NSDictionary(dictionary: current).isEqual(to: expected ?? [:]),
            file: file,
            line: line
        )
    }

    func mutateJournal(
        _ mutation: (inout [String: Any]) throws -> Void
    ) throws {
        let url = ProviderModelMigration202608.journalURL(in: directory)
        let data = try Data(contentsOf: url)
        var json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        try mutation(&json)
        let mutated = try JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys]
        )
        try mutated.write(to: url, options: .atomic)
    }
}
