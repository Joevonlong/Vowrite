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
        "openai-compatible", "deepgram", "qwen", "iflytek", "sherpa",
    ]

    /// Only providers with STT capability enabled can ever reach `WhisperService`'s
    /// routing — `DictationEngine.setupErrorMessage(for:)` refuses to start a
    /// recording when `hasSTTSupport` is false. A provider like volcengine may
    /// declare a placeholder `sttAdapter` with no matching implementation while its
    /// STT capability stays off (pending F-063); that's fine until the capability
    /// flag flips, at which point this test starts checking it.
    func testEveryProviderRoutesToAnImplementedAdapter() {
        for p in ProviderRegistry.shared.sttProviders {
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
