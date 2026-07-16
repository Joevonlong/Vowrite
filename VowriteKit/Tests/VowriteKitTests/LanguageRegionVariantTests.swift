import XCTest
@testable import VowriteKit

/// Tests for F-079 "language region variants" — BCP-47 region-qualified
/// language tags (zh-TW, en-GB, ...) layered on top of the existing plain
/// ISO-639-1 `SupportedLanguage` codes.
final class LanguageRegionVariantTests: XCTestCase {

    // MARK: - whisperMainCode (STT downgrade, pure)

    func testWhisperMainCodeDowngradesRegionVariant() {
        XCTAssertEqual(LanguageConfig.whisperMainCode(from: "zh-TW"), "zh")
        XCTAssertEqual(LanguageConfig.whisperMainCode(from: "en-GB"), "en")
        XCTAssertEqual(LanguageConfig.whisperMainCode(from: "pt-BR"), "pt")
    }

    func testWhisperMainCodePassesThroughPlainCode() {
        XCTAssertEqual(LanguageConfig.whisperMainCode(from: "zh"), "zh")
        XCTAssertEqual(LanguageConfig.whisperMainCode(from: "en"), "en")
        XCTAssertEqual(LanguageConfig.whisperMainCode(from: "auto"), "auto")
    }

    func testSupportedLanguageWhisperCodeReturnsFullTagForVariants() {
        // F-079: whisperCode no longer downgrades — that's now the adapter's
        // job, so Deepgram (which wants the full tag) can share the same value.
        XCTAssertEqual(SupportedLanguage.zhHant.whisperCode, "zh-TW")
        XCTAssertEqual(SupportedLanguage.enGB.whisperCode, "en-GB")
        XCTAssertEqual(SupportedLanguage.zhHans.whisperCode, "zh")
        XCTAssertNil(SupportedLanguage.auto.whisperCode)
    }

    // MARK: - Deepgram passthrough (pure decision function)

    func testDeepgramLanguagePassesTagThroughUnchanged() {
        XCTAssertEqual(LanguageConfig.deepgramLanguage(for: "en-GB"), "en-GB")
        XCTAssertEqual(LanguageConfig.deepgramLanguage(for: "zh"), "zh")
        XCTAssertNil(LanguageConfig.deepgramLanguage(for: nil))
    }

    // MARK: - sttRegionHint / sttPrompt (STT hint inclusion/exclusion)

    func testSttRegionHintIncludedForScriptSensitiveVariants() {
        XCTAssertNotNil(LanguageConfig.sttRegionHint(for: "zh-TW"))
        XCTAssertNotNil(LanguageConfig.sttRegionHint(for: "zh-HK"))
    }

    func testSttRegionHintExcludedForNonScriptSensitiveTags() {
        XCTAssertNil(LanguageConfig.sttRegionHint(for: "zh-CN"))
        XCTAssertNil(LanguageConfig.sttRegionHint(for: "en-GB"))
        XCTAssertNil(LanguageConfig.sttRegionHint(for: "zh"))
        XCTAssertNil(LanguageConfig.sttRegionHint(for: "auto"))
    }

    func testSttPromptPrependsHintAdditivelyToExistingVocabPrompt() {
        let result = LanguageConfig.sttPrompt(basePrompt: "Vowrite, SwiftUI", languageTag: "zh-TW")
        XCTAssertTrue(result?.contains("Vowrite, SwiftUI") == true, "existing vocab prompt must survive")
        XCTAssertNotEqual(result, "Vowrite, SwiftUI", "hint must be added, not silently dropped")
    }

    func testSttPromptUsesHintAloneWhenNoBasePrompt() {
        let result = LanguageConfig.sttPrompt(basePrompt: nil, languageTag: "zh-TW")
        XCTAssertEqual(result, LanguageConfig.sttRegionHint(for: "zh-TW"))
    }

    func testSttPromptUnchangedWhenNoHintApplies() {
        XCTAssertEqual(LanguageConfig.sttPrompt(basePrompt: "vocab", languageTag: "en-GB"), "vocab")
        XCTAssertEqual(LanguageConfig.sttPrompt(basePrompt: "vocab", languageTag: nil), "vocab")
        XCTAssertNil(LanguageConfig.sttPrompt(basePrompt: nil, languageTag: nil))
    }

    // MARK: - polishRegionInstruction (polish/translate hint)

    func testPolishRegionInstructionNonNilForEachDefinedVariant() {
        let variantTags = [
            "zh-CN", "zh-TW", "zh-HK",
            "en-US", "en-GB", "en-AU",
            "es-ES", "es-MX",
            "pt-BR", "pt-PT",
            "fr-FR", "fr-CA",
        ]
        for tag in variantTags {
            XCTAssertNotNil(LanguageConfig.polishRegionInstruction(for: tag), "expected a region instruction for \(tag)")
        }
    }

    func testPolishRegionInstructionNilForPlainCodesAndUnknownTags() {
        XCTAssertNil(LanguageConfig.polishRegionInstruction(for: "zh"))
        XCTAssertNil(LanguageConfig.polishRegionInstruction(for: "en"))
        XCTAssertNil(LanguageConfig.polishRegionInstruction(for: "auto"))
        XCTAssertNil(LanguageConfig.polishRegionInstruction(for: "zh-Hans"), "not one of the defined BCP-47 variant tags")
    }

    // MARK: - buildSystemPrompt integration (translation + polish paths)

    private func makeMode(
        isTranslation: Bool,
        language: String?,
        target: String?
    ) -> Mode {
        Mode(
            id: UUID(),
            name: "T",
            icon: "mic",
            isBuiltin: false,
            sttModel: "whisper-1",
            language: language,
            polishEnabled: true,
            polishModel: "gpt-4o-mini",
            systemPrompt: "",
            userPrompt: "",
            temperature: 0.3,
            autoPaste: false,
            outputStyleId: nil,
            shortcutIndex: nil,
            isTranslation: isTranslation,
            targetLanguage: target
        )
    }

    func testTranslationPromptIncludesRegionInstructionForVariantTarget() {
        let mode = makeMode(isTranslation: true, language: nil, target: "zh-TW")
        let prompt = SpeculativePolish.buildSystemPrompt(for: ModeConfig(from: mode))
        XCTAssertTrue(prompt.contains(LanguageConfig.polishRegionInstruction(for: "zh-TW")!))
    }

    func testTranslationPromptOmitsRegionInstructionForPlainTarget() {
        let mode = makeMode(isTranslation: true, language: nil, target: "en")
        let prompt = SpeculativePolish.buildSystemPrompt(for: ModeConfig(from: mode))
        XCTAssertFalse(prompt.contains("Region convention"))
    }

    func testPolishPromptIncludesRegionInstructionForVariantModeLanguage() {
        let mode = makeMode(isTranslation: false, language: "en-GB", target: nil)
        let prompt = SpeculativePolish.buildSystemPrompt(for: ModeConfig(from: mode))
        XCTAssertTrue(prompt.contains(LanguageConfig.polishRegionInstruction(for: "en-GB")!))
    }

    func testPolishPromptOmitsRegionInstructionWhenModeLanguageIsNil() {
        // `buildSystemPrompt` itself does not resolve "nil -> global default" —
        // that's the caller's job (DictationEngine / BackgroundRecordingService,
        // via `resolvedLanguageTag` + `withResolvedLanguage`, see below). Passed
        // an unresolved nil, it correctly stays silent.
        let mode = makeMode(isTranslation: false, language: nil, target: nil)
        let prompt = SpeculativePolish.buildSystemPrompt(for: ModeConfig(from: mode))
        XCTAssertFalse(prompt.contains("Region convention"))
    }

    // MARK: - resolvedLanguageTag (mode-nil -> global-default cascade, pure)

    func testResolvedLanguageTagFallsBackToGlobalWhenModeLanguageIsNil() {
        XCTAssertEqual(
            LanguageConfig.resolvedLanguageTag(modeLanguage: nil, globalLanguage: .zhHant),
            "zh-TW"
        )
        XCTAssertEqual(
            LanguageConfig.resolvedLanguageTag(modeLanguage: nil, globalLanguage: .zhHans),
            "zh"
        )
    }

    func testResolvedLanguageTagFallsBackToNilWhenGlobalIsAuto() {
        XCTAssertNil(LanguageConfig.resolvedLanguageTag(modeLanguage: nil, globalLanguage: .auto))
    }

    func testResolvedLanguageTagPrefersModeOverrideOverGlobal() {
        XCTAssertEqual(
            LanguageConfig.resolvedLanguageTag(modeLanguage: "en-GB", globalLanguage: .zhHant),
            "en-GB"
        )
    }

    func testResolvedLanguageTagIgnoresUnrecognizedModeLanguageAndFallsBackToGlobal() {
        // Mirrors the pre-F-079 STT-side behavior: an invalid/garbage stored
        // mode.language falls back to the global default rather than being
        // sent through as-is.
        XCTAssertEqual(
            LanguageConfig.resolvedLanguageTag(modeLanguage: "not-a-real-code", globalLanguage: .zhHant),
            "zh-TW"
        )
    }

    // MARK: - End-to-end: mode.language nil + global default variant (BUG-017
    // follow-up — the primary scenario: a user sets their global default to a
    // region variant like zh-TW, and any mode without its own language
    // override must still get the polish-output region instruction, not just
    // the STT hint).

    func testPolishPromptIncludesRegionInstructionWhenModeLanguageNilAndGlobalDefaultIsVariant() {
        let mode = makeMode(isTranslation: false, language: nil, target: nil)
        let resolved = LanguageConfig.resolvedLanguageTag(modeLanguage: mode.language, globalLanguage: .zhHant)
        let modeConfig = ModeConfig(from: mode).withResolvedLanguage(resolved)
        let prompt = SpeculativePolish.buildSystemPrompt(for: modeConfig)
        XCTAssertTrue(prompt.contains(LanguageConfig.polishRegionInstruction(for: "zh-TW")!))
    }

    func testPolishPromptOmitsRegionInstructionWhenModeLanguageNilAndGlobalDefaultIsPlainCode() {
        let mode = makeMode(isTranslation: false, language: nil, target: nil)
        let resolved = LanguageConfig.resolvedLanguageTag(modeLanguage: mode.language, globalLanguage: .zhHans)
        let modeConfig = ModeConfig(from: mode).withResolvedLanguage(resolved)
        let prompt = SpeculativePolish.buildSystemPrompt(for: modeConfig)
        XCTAssertFalse(prompt.contains("Region convention"))
    }

    func testPolishPromptOmitsRegionInstructionWhenModeLanguageNilAndGlobalDefaultIsAuto() {
        let mode = makeMode(isTranslation: false, language: nil, target: nil)
        let resolved = LanguageConfig.resolvedLanguageTag(modeLanguage: mode.language, globalLanguage: .auto)
        let modeConfig = ModeConfig(from: mode).withResolvedLanguage(resolved)
        let prompt = SpeculativePolish.buildSystemPrompt(for: modeConfig)
        XCTAssertFalse(prompt.contains("Region convention"))
    }

    // MARK: - withResolvedLanguage / withStyleOverride (ModeConfig copy helpers)

    func testWithResolvedLanguageOnlyChangesLanguage() {
        let mode = makeMode(isTranslation: false, language: "en", target: nil)
        let base = ModeConfig(from: mode)
        let resolved = base.withResolvedLanguage("zh-TW")
        XCTAssertEqual(resolved.language, "zh-TW")
        XCTAssertEqual(resolved.modeName, base.modeName)
        XCTAssertEqual(resolved.polishEnabled, base.polishEnabled)
        XCTAssertEqual(resolved.isTranslation, base.isTranslation)
        XCTAssertEqual(resolved.outputStyleId, base.outputStyleId)
    }

    func testWithStyleOverrideStillOverridesTheStyleId() {
        // Regression guard: withResolvedLanguage was added right next to
        // withStyleOverride in ModeManager.swift — confirm the sibling
        // method's own override still takes effect (not silently ignored).
        let mode = makeMode(isTranslation: false, language: "en", target: nil)
        let base = ModeConfig(from: mode)
        let newStyle = UUID()
        let overridden = base.withStyleOverride(newStyle)
        XCTAssertEqual(overridden.outputStyleId, newStyle)
    }

    // MARK: - Plain-code backward compatibility (zero migration)

    func testPlainCodesStillDecodeToTheSameCasesAsBefore() {
        XCTAssertEqual(SupportedLanguage(rawValue: "zh"), .zhHans)
        XCTAssertEqual(SupportedLanguage(rawValue: "en"), .en)
        XCTAssertEqual(SupportedLanguage(rawValue: "zh-TW"), .zhHant)
        XCTAssertEqual(SupportedLanguage(rawValue: "auto"), .auto)
    }

    func testModeWithPlainLanguageCodeRoundtripsThroughCodable() throws {
        let original = Mode(
            id: UUID(), name: "T", icon: "mic", isBuiltin: false,
            sttModel: nil, language: "zh", polishEnabled: false, polishModel: nil,
            systemPrompt: "", userPrompt: "", temperature: 0.3, autoPaste: true,
            outputStyleId: nil, shortcutIndex: nil
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Mode.self, from: data)
        XCTAssertEqual(decoded.language, "zh")
    }

    // MARK: - Family / region-variant grouping

    func testFamilyRootsExcludeAllRegionVariants() {
        let roots = SupportedLanguage.familyRoots
        XCTAssertFalse(roots.contains(.zhHant))
        XCTAssertFalse(roots.contains(.zhCN))
        XCTAssertFalse(roots.contains(.enGB))
        XCTAssertTrue(roots.contains(.zhHans))
        XCTAssertTrue(roots.contains(.en))
        XCTAssertTrue(roots.contains(.auto))
    }

    func testChineseFamilyHasThreeRegionVariants() {
        let variants = Set(SupportedLanguage.zhHans.regionVariants)
        XCTAssertEqual(variants, [.zhCN, .zhHant, .zhHK])
    }

    func testEnglishFamilyHasThreeRegionVariants() {
        let variants = Set(SupportedLanguage.en.regionVariants)
        XCTAssertEqual(variants, [.enUS, .enGB, .enAU])
    }

    func testSpanishPortugueseFrenchFamiliesHaveTwoRegionVariantsEach() {
        XCTAssertEqual(Set(SupportedLanguage.es.regionVariants), [.esES, .esMX])
        XCTAssertEqual(Set(SupportedLanguage.pt.regionVariants), [.ptBR, .ptPT])
        XCTAssertEqual(Set(SupportedLanguage.fr.regionVariants), [.frFR, .frCA])
    }

    func testLanguagesWithoutVariantsHaveEmptyRegionVariants() {
        XCTAssertTrue(SupportedLanguage.de.regionVariants.isEmpty)
        XCTAssertTrue(SupportedLanguage.ja.regionVariants.isEmpty)
        XCTAssertTrue(SupportedLanguage.auto.regionVariants.isEmpty)
    }

    func testRegionVariantLanguageFamilyMapsBackToRoot() {
        XCTAssertEqual(SupportedLanguage.zhHant.languageFamily, .zhHans)
        XCTAssertEqual(SupportedLanguage.zhCN.languageFamily, .zhHans)
        XCTAssertEqual(SupportedLanguage.zhHK.languageFamily, .zhHans)
        XCTAssertEqual(SupportedLanguage.enGB.languageFamily, .en)
        XCTAssertEqual(SupportedLanguage.frCA.languageFamily, .fr)
    }

    func testFamilyRootIsItsOwnFamily() {
        XCTAssertEqual(SupportedLanguage.en.languageFamily, .en)
        XCTAssertTrue(SupportedLanguage.en.isFamilyRoot)
        XCTAssertFalse(SupportedLanguage.enGB.isFamilyRoot)
    }

    // MARK: - Display names non-empty

    func testAllCasesHaveNonEmptyDisplayName() {
        for lang in SupportedLanguage.allCases {
            XCTAssertFalse(lang.displayName.isEmpty, "\(lang.rawValue) has an empty displayName")
        }
    }

    func testAllRegionVariantsHaveNonEmptyRegionLabel() {
        for lang in SupportedLanguage.allCases where !lang.isFamilyRoot {
            XCTAssertNotNil(lang.regionLabel, "\(lang.rawValue) is a variant but has no regionLabel")
            XCTAssertFalse(lang.regionLabel!.isEmpty)
        }
    }
}
