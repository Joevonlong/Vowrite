import XCTest
@testable import VowriteKit

/// Cross-reference integrity for built-in data: a built-in Mode that points at a
/// non-existent OutputStyle would silently fail to apply its style. Also guards
/// against duplicate built-in Mode / OutputStyle IDs (which would make lookups
/// ambiguous). Complements BuiltinDataTests (which checks each set in isolation).
final class BuiltinCrossReferenceTests: XCTestCase {

    func testBuiltinModeOutputStyleIDsResolveToExistingStyles() {
        let styleIDs = Set(OutputStyle.builtinStyles.map(\.id))
        for mode in Mode.builtinModes {
            guard let styleID = mode.outputStyleId else { continue }
            XCTAssertTrue(
                styleIDs.contains(styleID),
                "builtin mode '\(mode.name)' references outputStyleId \(styleID) which is not a builtin OutputStyle"
            )
        }
    }

    func testBuiltinModeIDsAreUnique() {
        let ids = Mode.builtinModes.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "builtin mode IDs must be unique")
    }

    func testBuiltinStyleIDsAreUnique() {
        let ids = OutputStyle.builtinStyles.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "builtin OutputStyle IDs must be unique")
    }

    func testTranslationBuiltinModesHaveTargetLanguage() {
        for mode in Mode.builtinModes where mode.isTranslation {
            XCTAssertNotNil(
                mode.targetLanguage,
                "builtin translation mode '\(mode.name)' must declare a targetLanguage"
            )
        }
    }

    func testBuiltinAPIPresetsReferenceSupportedCatalogModels() {
        for preset in APIPresetStore.builtInPresets {
            let configuration = preset.configuration
            let sttProvider = configuration.stt.provider
            let polishProvider = configuration.polish.provider

            XCTAssertTrue(
                sttProvider.hasSTTSupport,
                "\(preset.id) selects \(sttProvider.providerID) for unsupported STT"
            )
            XCTAssertTrue(
                sttProvider.presetSTTModels.contains(configuration.stt.model),
                "\(preset.id) STT model is absent from \(sttProvider.providerID) catalog"
            )
            XCTAssertTrue(
                ProviderRegistry.shared.provider(for: polishProvider.providerID)?.hasPolishSupport == true,
                "\(preset.id) selects \(polishProvider.providerID) for unsupported polish"
            )
            XCTAssertTrue(
                polishProvider.presetPolishModels.contains(configuration.polish.model),
                "\(preset.id) polish model is absent from \(polishProvider.providerID) catalog"
            )
        }
    }
}
