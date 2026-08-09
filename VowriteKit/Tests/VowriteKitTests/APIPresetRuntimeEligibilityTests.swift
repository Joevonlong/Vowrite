import XCTest
@testable import VowriteKit

final class APIPresetRuntimeEligibilityTests: XCTestCase {
    func testPublicBuiltinPickerExcludesRuntimeIneligibleLocalOllamaPreset() {
        XCTAssertFalse(BuiltInAPIPreset.localOllama.isRuntimeEligible)
        XCTAssertFalse(
            APIPresetStore.builtInPresets.contains {
                $0.id == BuiltInAPIPreset.localOllama.id
            }
        )
        XCTAssertTrue(
            APIPresetStore.builtInPresets.allSatisfy { option in
                BuiltInAPIPreset(rawValue: option.id.replacingOccurrences(of: "builtin:", with: ""))?
                    .isRuntimeEligible == true
            }
        )
    }

    func testLegacyLocalOllamaSelectionIsInvalidatedWithoutChangingEndpoints() throws {
        let suite = "APIPresetRuntimeEligibilityTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(BuiltInAPIPreset.localOllama.id, forKey: StorageKeys.splitAPISelectedPresetID)
        defaults.set(APIProvider.ollama.rawValue, forKey: StorageKeys.splitAPISTTProvider)
        defaults.set("whisper-large-v3", forKey: StorageKeys.splitAPISTTModel)
        defaults.set("http://127.0.0.1:11434/v1", forKey: StorageKeys.splitAPISTTBaseURL)
        defaults.set(APIProvider.ollama.rawValue, forKey: StorageKeys.splitAPIPolishProvider)
        defaults.set("qwen3:8b", forKey: StorageKeys.splitAPIPolishModel)
        let endpointKeys = [
            StorageKeys.splitAPISTTProvider,
            StorageKeys.splitAPISTTModel,
            StorageKeys.splitAPISTTBaseURL,
            StorageKeys.splitAPIPolishProvider,
            StorageKeys.splitAPIPolishModel,
        ]
        let before = endpointKeys.map { defaults.object(forKey: $0) as? NSObject }

        XCTAssertEqual(APIConfig.migratePresetIDs(in: defaults), .invalidatedUnavailablePreset)

        XCTAssertNil(defaults.string(forKey: StorageKeys.splitAPISelectedPresetID))
        XCTAssertEqual(
            APIConfig.pendingPresetRecovery(in: defaults)?.presetID,
            BuiltInAPIPreset.localOllama.id
        )
        XCTAssertTrue(
            zip(before, endpointKeys.map { defaults.object(forKey: $0) as? NSObject })
                .allSatisfy { $0 == $1 }
        )
        XCTAssertNil(APIPresetStore.preset(for: BuiltInAPIPreset.localOllama.id))
    }
}
