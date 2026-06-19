import XCTest
@testable import VowriteKit

/// Tests for `SpeculativePolish.buildSystemPrompt(for:)` — the shared function
/// that selects and assembles the polish vs. translation system prompt.
///
/// The critical invariant (F-063): in translation mode the prompt must NOT carry
/// the mode's `userPrompt` (a polish-formatting instruction), or it would
/// contaminate the translation output. Polish mode, conversely, must include it.
final class BuildSystemPromptTests: XCTestCase {

    private func makeMode(
        isTranslation: Bool,
        target: String?,
        systemPrompt: String,
        userPrompt: String
    ) -> Mode {
        Mode(
            id: UUID(),
            name: "T",
            icon: "mic",
            isBuiltin: false,
            sttModel: "whisper-1",
            language: "en",
            polishEnabled: true,
            polishModel: "gpt-4o-mini",
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            temperature: 0.5,
            autoPaste: false,
            outputStyleId: nil,
            shortcutIndex: nil,
            isTranslation: isTranslation,
            targetLanguage: target
        )
    }

    func testTranslationPromptDoesNotLeakUserPrompt() {
        let mode = makeMode(
            isTranslation: true, target: "zh-Hans",
            systemPrompt: "extra instructions", userPrompt: "USERPROMPT_SHOULD_NOT_LEAK"
        )
        let prompt = SpeculativePolish.buildSystemPrompt(for: ModeConfig(from: mode))
        XCTAssertFalse(
            prompt.contains("USERPROMPT_SHOULD_NOT_LEAK"),
            "translation prompt must not include the mode's userPrompt (F-063 isolation)"
        )
    }

    func testTranslationPromptIncludesTargetLanguageAndSystemPrompt() {
        let mode = makeMode(
            isTranslation: true, target: "zh-Hans",
            systemPrompt: "TRANSLATE_FORMALLY_MARKER", userPrompt: "ignored"
        )
        let prompt = SpeculativePolish.buildSystemPrompt(for: ModeConfig(from: mode))
        let langName = SupportedLanguage(rawValue: "zh-Hans")?.displayName ?? "zh-Hans"
        XCTAssertTrue(prompt.contains(langName), "translation prompt should name the target language")
        XCTAssertTrue(
            prompt.contains("TRANSLATE_FORMALLY_MARKER"),
            "translation prompt should include systemPrompt as additional instructions"
        )
    }

    func testPolishPromptIncludesUserPrompt() {
        let mode = makeMode(
            isTranslation: false, target: nil,
            systemPrompt: "mode-format", userPrompt: "USERPROMPT_SHOULD_APPEAR"
        )
        let prompt = SpeculativePolish.buildSystemPrompt(for: ModeConfig(from: mode))
        XCTAssertTrue(
            prompt.contains("USERPROMPT_SHOULD_APPEAR"),
            "polish prompt should include the mode's userPrompt"
        )
    }
}
