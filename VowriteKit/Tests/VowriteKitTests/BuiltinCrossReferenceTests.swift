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
}
