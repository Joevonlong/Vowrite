import CryptoKit
import XCTest
@testable import VowriteKit

final class ProviderModelSafetyRulesTests: XCTestCase {
    func testGroqPolishRetirementsUseDeveloperSafeReplacements() {
        XCTAssertEqual(
            ProviderModelSafetyRules.safeModel(
                providerID: "groq",
                capability: .polish,
                storedModel: "qwen/qwen3-32b"
            ),
            "openai/gpt-oss-120b"
        )
        XCTAssertEqual(
            ProviderModelSafetyRules.safeModel(
                providerID: "groq",
                capability: .polish,
                storedModel: "llama-3.3-70b-versatile"
            ),
            "openai/gpt-oss-120b"
        )
        XCTAssertEqual(
            ProviderModelSafetyRules.safeModel(
                providerID: "groq",
                capability: .polish,
                storedModel: "llama-3.1-8b-instant"
            ),
            "openai/gpt-oss-20b"
        )
    }

    func testTogetherWhisperUsesProviderQualifiedID() {
        XCTAssertEqual(
            ProviderModelSafetyRules.safeModel(
                providerID: "together",
                capability: .stt,
                storedModel: "whisper-large-v3"
            ),
            "openai/whisper-large-v3"
        )
    }

    func testSiliconFlowDeprecatedModelFallsBackWithinProvider() {
        XCTAssertEqual(
            ProviderModelSafetyRules.safeModel(
                providerID: "siliconflow",
                capability: .polish,
                storedModel: "zai-org/GLM-4.6"
            ),
            "deepseek-ai/DeepSeek-V3"
        )
    }

    func testDeepSeekLegacyAliasesAreProviderScoped() {
        for model in ["deepseek-chat", "deepseek-reasoner"] {
            XCTAssertEqual(
                ProviderModelSafetyRules.safeModel(
                    providerID: "deepseek",
                    capability: .polish,
                    storedModel: model
                ),
                "deepseek-v4-flash"
            )
            XCTAssertEqual(
                ProviderModelSafetyRules.safeModel(
                    providerID: "openrouter",
                    capability: .polish,
                    storedModel: model
                ),
                model
            )
            XCTAssertEqual(
                ProviderModelSafetyRules.safeModel(
                    providerID: "custom",
                    capability: .polish,
                    storedModel: model
                ),
                model
            )
        }
    }

    func testRulesDoNotCrossCapabilitiesOrRewriteUnknownModels() {
        XCTAssertEqual(
            ProviderModelSafetyRules.safeModel(
                providerID: "groq",
                capability: .stt,
                storedModel: "qwen/qwen3-32b"
            ),
            "qwen/qwen3-32b"
        )
        XCTAssertEqual(
            ProviderModelSafetyRules.safeModel(
                providerID: "groq",
                capability: .polish,
                storedModel: "enterprise/custom-model"
            ),
            "enterprise/custom-model"
        )
    }

    func testRulesetHashIsDerivedFromCanonicalSortedRules() {
        let expectedCanonicalRules = """
        deepseek|polish|deepseek-chat|deepseek-v4-flash
        deepseek|polish|deepseek-reasoner|deepseek-v4-flash
        groq|polish|llama-3.1-8b-instant|openai/gpt-oss-20b
        groq|polish|llama-3.3-70b-versatile|openai/gpt-oss-120b
        groq|polish|qwen/qwen3-32b|openai/gpt-oss-120b
        siliconflow|polish|zai-org/GLM-4.6|deepseek-ai/DeepSeek-V3
        together|stt|whisper-large-v3|openai/whisper-large-v3
        """
        let expectedHash = SHA256.hash(data: Data(expectedCanonicalRules.utf8))
            .map { String(format: "%02x", $0) }
            .joined()

        XCTAssertEqual(ProviderModelSafetyRules.canonicalRuleset, expectedCanonicalRules)
        XCTAssertEqual(ProviderModelSafetyRules.rulesetHash, expectedHash)
    }
}
