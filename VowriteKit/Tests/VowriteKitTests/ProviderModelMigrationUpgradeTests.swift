import XCTest
@testable import VowriteKit

final class ProviderModelMigrationUpgradeTests: ProviderModelMigration202608TestCase {
    func testProviderKnownGlobalAndPresetModelsMigrateWithoutTouchingModes() throws {
        defaults.set(APIProvider.together.rawValue, forKey: StorageKeys.splitAPISTTProvider)
        defaults.set("whisper-large-v3", forKey: StorageKeys.splitAPISTTModel)
        defaults.set(APIProvider.groq.rawValue, forKey: StorageKeys.splitAPIPolishProvider)
        defaults.set("llama-3.1-8b-instant", forKey: StorageKeys.splitAPIPolishModel)

        var mode = Mode.builtinModes[0]
        mode.sttModel = "whisper-large-v3"
        mode.polishModel = "llama-3.1-8b-instant"
        let modeData = try JSONEncoder().encode([mode])
        defaults.set(modeData, forKey: StorageKeys.vowriteModes)

        let preset = UserAPIPreset(
            id: UUID(),
            name: "Legacy",
            configuration: SplitAPIConfiguration(
                stt: APIEndpointConfiguration(provider: .together, model: "whisper-large-v3"),
                polish: APIEndpointConfiguration(provider: .siliconflow, model: "zai-org/GLM-4.6")
            )
        )
        defaults.set(try JSONEncoder().encode([preset]), forKey: StorageKeys.splitAPIUserPresets)

        let result = ProviderModelMigration202608.runIfNeeded(
            defaults: defaults,
            lockDirectory: directory
        )

        XCTAssertEqual(result, .committed)
        XCTAssertEqual(defaults.string(forKey: StorageKeys.splitAPISTTModel), "openai/whisper-large-v3")
        XCTAssertEqual(defaults.string(forKey: StorageKeys.splitAPIPolishModel), "openai/gpt-oss-20b")
        let migratedData = try XCTUnwrap(defaults.data(forKey: StorageKeys.splitAPIUserPresets))
        let migrated = try JSONDecoder().decode([UserAPIPreset].self, from: migratedData)
        XCTAssertEqual(migrated[0].configuration.stt.model, "openai/whisper-large-v3")
        XCTAssertEqual(migrated[0].configuration.polish.model, "deepseek-ai/DeepSeek-V3")
        XCTAssertEqual(defaults.data(forKey: StorageKeys.vowriteModes), modeData)
        XCTAssertEqual(
            defaults.string(forKey: StorageKeys.providerModelCompatibilityMigrationID),
            ProviderModelSafetyRules.migrationID
        )
        XCTAssertEqual(
            defaults.string(forKey: StorageKeys.providerModelCompatibilityRulesetHash),
            ProviderModelSafetyRules.rulesetHash
        )
    }
}
