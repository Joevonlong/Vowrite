import XCTest
@testable import VowriteKit

/// Guards STT adapter routing: `ProviderRegistry.sttAdapterID(for:)` must only
/// ever return an adapter id that `WhisperService` actually implements. A typo
/// in a provider's `sttAdapter` field in providers.json would otherwise silently
/// fall back to the OpenAI-compatible adapter and send audio to the wrong API.
final class STTAdapterRoutingTests: XCTestCase {

    /// Adapter ids WhisperService has implementations for (its `adapterMap` keys).
    /// If a new adapter is added there, add it here too.
    private let implementedAdapterIDs: Set<String> = [
        "openai-compatible", "deepgram", "volcengine", "qwen", "iflytek", "sherpa",
    ]

    func testEveryProviderRoutesToAnImplementedAdapter() {
        for p in ProviderRegistry.shared.providers {
            let adapterID = ProviderRegistry.shared.sttAdapterID(for: p.id)
            XCTAssertTrue(
                implementedAdapterIDs.contains(adapterID),
                "provider '\(p.id)' declares sttAdapter '\(adapterID)', which WhisperService has no implementation for — it would silently fall back to openai-compatible"
            )
        }
    }

    func testUnknownProviderDefaultsToOpenAICompatible() {
        XCTAssertEqual(
            ProviderRegistry.shared.sttAdapterID(for: "no-such-provider-id"),
            "openai-compatible"
        )
    }

    func testDeepgramRoutesToItsOwnAdapter() {
        // Deepgram has a non-OpenAI API, so it must route to the dedicated adapter.
        XCTAssertEqual(ProviderRegistry.shared.sttAdapterID(for: "deepgram"), "deepgram")
    }
}
