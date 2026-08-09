import XCTest
@testable import VowriteKit

/// Data-integrity tests for the hand-edited `providers.json` (19+ providers),
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
}
