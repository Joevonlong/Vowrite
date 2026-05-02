import XCTest
@testable import VowriteKit

final class ModeCodableTests: XCTestCase {
    func testRoundtripPreservesAllFields() throws {
        let original = Mode(
            id: UUID(),
            name: "Custom",
            icon: "star",
            isBuiltin: false,
            sttModel: "whisper-1",
            language: "en",
            polishEnabled: true,
            polishModel: "gpt-4o-mini",
            systemPrompt: "system",
            userPrompt: "user",
            temperature: 0.42,
            autoPaste: false,
            outputStyleId: UUID(),
            shortcutIndex: 9,
            isTranslation: true,
            targetLanguage: "zh-Hans"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Mode.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    /// F-063 backward compatibility: pre-translation Mode JSON (no isTranslation/targetLanguage)
    /// must still decode without throwing. Defaults: isTranslation=false, targetLanguage=nil.
    func testDecodesLegacyJSONWithoutTranslationFields() throws {
        let id = UUID()
        let styleId = UUID()
        let legacy = """
        {
            "id": "\(id.uuidString)",
            "name": "Legacy",
            "icon": "mic",
            "isBuiltin": false,
            "polishEnabled": true,
            "systemPrompt": "",
            "userPrompt": "",
            "temperature": 0.3,
            "autoPaste": true,
            "outputStyleId": "\(styleId.uuidString)",
            "shortcutIndex": 1
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Mode.self, from: legacy)
        XCTAssertEqual(decoded.id, id)
        XCTAssertEqual(decoded.name, "Legacy")
        XCTAssertFalse(decoded.isTranslation)
        XCTAssertNil(decoded.targetLanguage)
    }
}
