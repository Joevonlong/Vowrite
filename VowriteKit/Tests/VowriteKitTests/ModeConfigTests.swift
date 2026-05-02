import XCTest
@testable import VowriteKit

final class ModeConfigTests: XCTestCase {
    private func makeMode(styleId: UUID? = nil) -> Mode {
        Mode(
            id: UUID(),
            name: "Test",
            icon: "mic",
            isBuiltin: false,
            sttModel: "whisper-1",
            language: "en",
            polishEnabled: true,
            polishModel: "gpt-4o-mini",
            systemPrompt: "sys",
            userPrompt: "usr",
            temperature: 0.5,
            autoPaste: false,
            outputStyleId: styleId,
            shortcutIndex: nil,
            isTranslation: true,
            targetLanguage: "zh-Hans"
        )
    }

    func testInitFromModeCarriesAllFields() {
        let styleId = UUID()
        let mode = makeMode(styleId: styleId)
        let config = ModeConfig(from: mode)

        XCTAssertEqual(config.modeName, "Test")
        XCTAssertEqual(config.sttModel, "whisper-1")
        XCTAssertEqual(config.language, "en")
        XCTAssertTrue(config.polishEnabled)
        XCTAssertEqual(config.polishModel, "gpt-4o-mini")
        XCTAssertEqual(config.systemPrompt, "sys")
        XCTAssertEqual(config.userPrompt, "usr")
        XCTAssertEqual(config.temperature, 0.5)
        XCTAssertFalse(config.autoPaste)
        XCTAssertEqual(config.outputStyleId, styleId)
        XCTAssertTrue(config.isTranslation)
        XCTAssertEqual(config.targetLanguage, "zh-Hans")
    }

    func testWithStyleOverrideOnlyChangesStyleId() {
        let originalStyle = UUID()
        let newStyle = UUID()
        let config = ModeConfig(from: makeMode(styleId: originalStyle))
        let overridden = config.withStyleOverride(newStyle)

        XCTAssertEqual(overridden.outputStyleId, newStyle)
        XCTAssertEqual(overridden.modeName, config.modeName)
        XCTAssertEqual(overridden.sttModel, config.sttModel)
        XCTAssertEqual(overridden.language, config.language)
        XCTAssertEqual(overridden.polishEnabled, config.polishEnabled)
        XCTAssertEqual(overridden.polishModel, config.polishModel)
        XCTAssertEqual(overridden.systemPrompt, config.systemPrompt)
        XCTAssertEqual(overridden.userPrompt, config.userPrompt)
        XCTAssertEqual(overridden.temperature, config.temperature)
        XCTAssertEqual(overridden.autoPaste, config.autoPaste)
        XCTAssertEqual(overridden.isTranslation, config.isTranslation)
        XCTAssertEqual(overridden.targetLanguage, config.targetLanguage)
    }

    func testWithStyleOverrideAcceptsNil() {
        let config = ModeConfig(from: makeMode(styleId: UUID()))
        let overridden = config.withStyleOverride(nil)
        XCTAssertNil(overridden.outputStyleId)
    }
}
