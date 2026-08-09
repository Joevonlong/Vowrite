import XCTest
@testable import VowriteKit

final class APIConnectionTesterPayloadTests: XCTestCase {
    func testProbeUsesProviderScopedSafeModel() {
        let groq = APIEndpointConfiguration(
            provider: .groq,
            model: "llama-3.3-70b-versatile"
        )
        let openRouter = APIEndpointConfiguration(
            provider: .openrouter,
            model: "llama-3.3-70b-versatile"
        )

        XCTAssertEqual(
            APIConnectionTester.chatCompletionProbePayload(configuration: groq)["model"] as? String,
            "openai/gpt-oss-120b"
        )
        XCTAssertEqual(
            APIConnectionTester.chatCompletionProbePayload(configuration: openRouter)["model"] as? String,
            "llama-3.3-70b-versatile"
        )
    }

    func testProbeAppliesCatalogOverrides() {
        let kimi = APIEndpointConfiguration(provider: .kimi, model: "kimi-k2.6")
        let openAI = APIEndpointConfiguration(provider: .openai, model: "gpt-5.6-luna")

        let kimiPayload = APIConnectionTester.chatCompletionProbePayload(configuration: kimi)
        XCTAssertEqual(kimiPayload["temperature"] as? Double, 0.6)
        let thinking = kimiPayload["thinking"] as? [String: Any]
        XCTAssertEqual(thinking?["type"] as? String, "disabled")

        let openAIPayload = APIConnectionTester.chatCompletionProbePayload(configuration: openAI)
        XCTAssertEqual(openAIPayload["reasoning_effort"] as? String, "none")
    }

    func testF086PendingSelectionsAreNotRewrittenAtTheRequestBoundary() {
        let pendingSelections: [(APIProvider, String)] = [
            (.claude, "claude-opus-4-8"),
            (.gemini, "gemini-3.5-flash"),
            (.gemini, "gemini-3.1-flash-lite"),
            (.siliconflow, "deepseek-ai/DeepSeek-V3.1-Terminus"),
        ]

        for (provider, selectedModel) in pendingSelections {
            let configuration = APIEndpointConfiguration(
                provider: provider,
                model: selectedModel
            )
            XCTAssertEqual(
                APIConnectionTester.chatCompletionProbePayload(configuration: configuration)["model"] as? String,
                selectedModel,
                "F-086 candidates must not activate before external evidence is accepted"
            )
        }
    }
}
