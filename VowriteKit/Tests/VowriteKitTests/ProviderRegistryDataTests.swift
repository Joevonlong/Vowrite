import XCTest
@testable import VowriteKit

/// Data-integrity tests for the hand-edited `providers.json`,
/// loaded by `ProviderRegistry`. These guard against typos that would silently
/// break a provider: a malformed base URL, a trailing slash (which the request
/// builder would turn into a double slash), a duplicate id, or an empty id.
final class ProviderRegistryDataTests: XCTestCase {

    func testRegistryLoadsAtLeastOneProvider() {
        XCTAssertFalse(
            ProviderRegistry.shared.providers.isEmpty,
            "providers.json failed to load — registry is empty"
        )
    }

    func testProviderIDsAreUnique() {
        let ids = ProviderRegistry.shared.providers.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "provider ids in providers.json must be unique")
    }

    func testProviderIDsAreNonEmpty() {
        for p in ProviderRegistry.shared.providers {
            XCTAssertFalse(p.id.isEmpty, "every provider must have a non-empty id")
        }
    }

    func testModelIDsAreUniqueWithinEachProviderCapability() {
        for provider in ProviderRegistry.shared.providers {
            let sttIDs = provider.presetSTTModels
            XCTAssertEqual(
                sttIDs.count,
                Set(sttIDs).count,
                "\(provider.id) has duplicate STT model ids"
            )

            let polishIDs = provider.presetPolishModels
            XCTAssertEqual(
                polishIDs.count,
                Set(polishIDs).count,
                "\(provider.id) has duplicate polish model ids"
            )
        }
    }

    func testNonEmptyBaseURLsAreValidURLs() {
        for p in ProviderRegistry.shared.providers where !p.baseURL.isEmpty {
            XCTAssertNotNil(
                URL(string: p.baseURL),
                "provider '\(p.id)' has an invalid baseURL: '\(p.baseURL)'"
            )
        }
    }

    func testNonEmptyBaseURLsHaveNoTrailingSlash() {
        for p in ProviderRegistry.shared.providers where !p.baseURL.isEmpty {
            XCTAssertFalse(
                p.baseURL.hasSuffix("/"),
                "provider '\(p.id)' baseURL should not end with '/': '\(p.baseURL)'"
            )
        }
    }

    func testEverySupportedCapabilityHasAResolvableDefault() {
        for provider in ProviderRegistry.shared.providers {
            if provider.hasSTTSupport {
                XCTAssertFalse(provider.defaultSTTModel.isEmpty, "\(provider.id) STT default is empty")
                if !provider.presetSTTModels.isEmpty {
                    XCTAssertTrue(
                        provider.presetSTTModels.contains(provider.defaultSTTModel),
                        "\(provider.id) STT default is absent from its catalog"
                    )
                }
            }
            if provider.hasPolishSupport {
                XCTAssertFalse(provider.defaultPolishModel.isEmpty, "\(provider.id) polish default is empty")
                if !provider.presetPolishModels.isEmpty {
                    XCTAssertTrue(
                        provider.presetPolishModels.contains(provider.defaultPolishModel),
                        "\(provider.id) polish default is absent from its catalog"
                    )
                }
            }
        }
    }

    func testF084RetiredGeneralCatalogRowsAreAbsent() throws {
        let groq = try XCTUnwrap(ProviderRegistry.shared.provider(for: "groq"))
        for retired in ["qwen/qwen3-32b", "llama-3.1-8b-instant", "llama-3.3-70b-versatile"] {
            XCTAssertFalse(groq.presetPolishModels.contains(retired))
        }

        let siliconFlow = try XCTUnwrap(ProviderRegistry.shared.provider(for: "siliconflow"))
        XCTAssertFalse(siliconFlow.presetPolishModels.contains("zai-org/GLM-4.6"))
    }

    func testF084CatalogCorrectionsAndOverrides() throws {
        let openAI = try XCTUnwrap(ProviderRegistry.shared.provider(for: "openai"))
        for model in ["gpt-5.6-luna", "gpt-5.6-sol"] {
            XCTAssertEqual(
                openAI.polishOverrides(for: model)?["reasoning_effort"],
                .string("none")
            )
        }

        let together = try XCTUnwrap(ProviderRegistry.shared.provider(for: "together"))
        XCTAssertEqual(together.defaultSTTModel, "openai/whisper-large-v3")
        XCTAssertTrue(together.presetSTTModels.contains("openai/whisper-large-v3"))

        let kimi = try XCTUnwrap(ProviderRegistry.shared.provider(for: "kimi"))
        for model in ["kimi-k2.5", "kimi-k2.6"] {
            XCTAssertEqual(kimi.polishOverrides(for: model)?["temperature"], .double(0.6))
        }

        let xAI = try XCTUnwrap(ProviderRegistry.shared.provider(for: "xai"))
        XCTAssertFalse(xAI.hasSTTSupport)
        XCTAssertTrue(xAI.sttNote?.contains("F-088") == true)
    }

    func testF086PendingCandidatesStayOutAndIncumbentsRemainAvailable() throws {
        let openAI = try XCTUnwrap(ProviderRegistry.shared.provider(for: "openai"))
        XCTAssertEqual(openAI.defaultPolishModel, "gpt-5.4-mini")
        XCTAssertFalse(openAI.presetPolishModels.contains("gpt-5.6-terra"))

        let claude = try XCTUnwrap(ProviderRegistry.shared.provider(for: "claude"))
        XCTAssertEqual(claude.defaultPolishModel, "claude-sonnet-5")
        XCTAssertFalse(claude.presetPolishModels.contains("claude-opus-5"))
        XCTAssertTrue(claude.presetPolishModels.contains("claude-opus-4-8"))

        let gemini = try XCTUnwrap(ProviderRegistry.shared.provider(for: "gemini"))
        XCTAssertEqual(gemini.defaultPolishModel, "gemini-2.5-flash")
        XCTAssertFalse(gemini.presetPolishModels.contains("gemini-3.6-flash"))
        XCTAssertFalse(gemini.presetPolishModels.contains("gemini-3.5-flash-lite"))
        XCTAssertTrue(gemini.presetPolishModels.contains("gemini-3.5-flash"))
        XCTAssertTrue(gemini.presetPolishModels.contains("gemini-3.1-flash-lite"))

        let siliconFlow = try XCTUnwrap(ProviderRegistry.shared.provider(for: "siliconflow"))
        XCTAssertEqual(siliconFlow.defaultPolishModel, "deepseek-ai/DeepSeek-V3")
        for model in [
            "deepseek-ai/DeepSeek-V4-Flash",
            "deepseek-ai/DeepSeek-V4-Pro",
            "zai-org/GLM-5.2",
        ] {
            XCTAssertFalse(siliconFlow.presetPolishModels.contains(model))
        }
        XCTAssertTrue(
            siliconFlow.presetPolishModels.contains("deepseek-ai/DeepSeek-V3.1-Terminus")
        )
        XCTAssertTrue(
            siliconFlow.presetPolishModels.contains("Qwen/Qwen2.5-72B-Instruct")
        )

        let openRouter = try XCTUnwrap(ProviderRegistry.shared.provider(for: "openrouter"))
        XCTAssertEqual(openRouter.defaultSTTModel, "openai/whisper-large-v3")
        XCTAssertFalse(
            openRouter.presetSTTModels.contains("openai/whisper-large-v3-turbo")
        )
    }

    func testF086CuratedCloudRowsStayWithinSixAndOllamaKeepsSeven() throws {
        let curatedCloudProviderIDs = [
            "openai",
            "openrouter",
            "siliconflow",
            "gemini",
            "claude",
            "qianfan",
            "qwen",
            "minimax_intl",
            "minimax_cn",
        ]
        for providerID in curatedCloudProviderIDs {
            let provider = try XCTUnwrap(ProviderRegistry.shared.provider(for: providerID))
            XCTAssertLessThanOrEqual(
                provider.stt?.models.count ?? 0,
                6,
                "\(providerID) STT catalog exceeds the curated cloud limit"
            )
            XCTAssertLessThanOrEqual(
                provider.polish?.models.count ?? 0,
                6,
                "\(providerID) polish catalog exceeds the curated cloud limit"
            )
        }

        let ollama = try XCTUnwrap(ProviderRegistry.shared.provider(for: "ollama"))
        XCTAssertEqual(ollama.presetPolishModels.count, 7)
        XCTAssertFalse(ollama.presetPolishModels.contains { $0.contains(":cloud") })
    }

    func testF086UnprovenOrOutOfScopeModelsStayOutOfStableCatalog() throws {
        let allModelIDs = ProviderRegistry.shared.providers.flatMap { provider in
            provider.presetSTTModels + provider.presetPolishModels
        }
        let exactExclusions = [
            "claude-fable-5",
            "claude-mythos-5",
            "kimi-k3",
            "kimi-k2.7-code",
            "qwen3.8-max-preview",
            "qwen3.7-flash",
        ]
        for model in exactExclusions {
            XCTAssertFalse(allModelIDs.contains(model), "unvalidated model leaked into catalog: \(model)")
        }

        let qianfan = try XCTUnwrap(ProviderRegistry.shared.provider(for: "qianfan"))
        XCTAssertEqual(qianfan.defaultPolishModel, "ernie-4.5-turbo-128k")
        XCTAssertEqual(qianfan.presetPolishModels, ["ernie-4.5-turbo-128k"])
        XCTAssertFalse(qianfan.presetPolishModels.contains { $0.lowercased().contains("ernie-5") })

        let qwen = try XCTUnwrap(ProviderRegistry.shared.provider(for: "qwen"))
        XCTAssertEqual(qwen.defaultPolishModel, "qwen3.7-plus")
        XCTAssertTrue(qwen.presetPolishModels.contains("qwen3.6-flash"))

        for providerID in ["minimax_intl", "minimax_cn"] {
            let provider = try XCTUnwrap(ProviderRegistry.shared.provider(for: providerID))
            XCTAssertEqual(provider.defaultPolishModel, "MiniMax-M3")
            XCTAssertEqual(
                provider.presetPolishModels,
                ["MiniMax-M3", "MiniMax-M2.7", "MiniMax-M2.7-highspeed"]
            )
        }

        let xAI = try XCTUnwrap(ProviderRegistry.shared.provider(for: "xai"))
        XCTAssertFalse(xAI.hasSTTSupport)
        XCTAssertTrue(xAI.presetSTTModels.isEmpty)
    }
}
