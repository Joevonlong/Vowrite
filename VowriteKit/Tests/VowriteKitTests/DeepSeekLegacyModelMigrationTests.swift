import XCTest
@testable import VowriteKit

/// Pure-function coverage for the 2026-07-24 DeepSeek alias retirement
/// migration (deepseek-chat / deepseek-reasoner → deepseek-v4-flash).
final class DeepSeekLegacyModelMigrationTests: XCTestCase {

    // MARK: - migratedModel

    func testLegacyChatAliasIsMigrated() {
        XCTAssertEqual(DeepSeekLegacyModelMigration.migratedModel("deepseek-chat"), "deepseek-v4-flash")
    }

    func testLegacyReasonerAliasIsMigrated() {
        XCTAssertEqual(DeepSeekLegacyModelMigration.migratedModel("deepseek-reasoner"), "deepseek-v4-flash")
    }

    func testCurrentModelsAreUntouched() {
        XCTAssertNil(DeepSeekLegacyModelMigration.migratedModel("deepseek-v4-flash"))
        XCTAssertNil(DeepSeekLegacyModelMigration.migratedModel("deepseek-v4-pro"))
        XCTAssertNil(DeepSeekLegacyModelMigration.migratedModel("gpt-5.4-mini"))
        XCTAssertNil(DeepSeekLegacyModelMigration.migratedModel(""))
    }

    func testSimilarButDistinctIDsAreUntouched() {
        XCTAssertNil(DeepSeekLegacyModelMigration.migratedModel("deepseek-chat-v3"))
        XCTAssertNil(DeepSeekLegacyModelMigration.migratedModel("deepseek-ai/DeepSeek-V3"))
    }

    // MARK: - migratedModesData

    private func encodedModes(_ mutate: (inout Mode) -> Void) throws -> Data {
        var mode = Mode.builtinModes[0]
        mutate(&mode)
        return try JSONEncoder().encode([mode])
    }

    func testModeWithLegacyOverrideIsPatched() throws {
        let data = try encodedModes { $0.polishModel = "deepseek-chat" }
        let repaired = DeepSeekLegacyModelMigration.migratedModesData(data)
        XCTAssertNotNil(repaired)
        let modes = try JSONDecoder().decode([Mode].self, from: repaired!)
        XCTAssertEqual(modes[0].polishModel, "deepseek-v4-flash")
    }

    func testModeWithoutOverrideReturnsNil() throws {
        let data = try encodedModes { $0.polishModel = nil }
        XCTAssertNil(DeepSeekLegacyModelMigration.migratedModesData(data))
    }

    func testModeWithCurrentOverrideReturnsNil() throws {
        let data = try encodedModes { $0.polishModel = "deepseek-v4-pro" }
        XCTAssertNil(DeepSeekLegacyModelMigration.migratedModesData(data))
    }

    func testGarbageDataReturnsNil() {
        XCTAssertNil(DeepSeekLegacyModelMigration.migratedModesData(Data("not json".utf8)))
    }

    func testPatchPreservesOtherModeFields() throws {
        var original = Mode.builtinModes[0]
        original.polishModel = "deepseek-reasoner"
        let data = try JSONEncoder().encode([original])
        let repaired = try XCTUnwrap(DeepSeekLegacyModelMigration.migratedModesData(data))
        let mode = try JSONDecoder().decode([Mode].self, from: repaired)[0]
        XCTAssertEqual(mode.id, original.id)
        XCTAssertEqual(mode.name, original.name)
        XCTAssertEqual(mode.systemPrompt, original.systemPrompt)
        XCTAssertEqual(mode.isTranslation, original.isTranslation)
    }
}
