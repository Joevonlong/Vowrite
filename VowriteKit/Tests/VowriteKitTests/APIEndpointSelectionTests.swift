import XCTest
@testable import VowriteKit

final class APIEndpointSelectionTests: XCTestCase {
    func testSwitchingBothPipelinesResetsEachEndpointToItsNewProviderDefault() {
        let existing = SplitAPIConfiguration(
            stt: APIEndpointConfiguration(
                provider: .groq,
                model: "whisper-large-v3-turbo",
                baseURL: "https://stt.example.test/v1"
            ),
            polish: APIEndpointConfiguration(
                provider: .deepseek,
                model: "deepseek-flash",
                baseURL: "https://polish.example.test/v1"
            )
        )

        let switched = SplitAPIConfiguration(
            stt: APIEndpointConfiguration.selecting(
                provider: .openai,
                model: "gpt-transcribe",
                preservingBaseURLFrom: existing.stt
            ),
            polish: APIEndpointConfiguration.selecting(
                provider: .kimi,
                model: "kimi-k2.6",
                preservingBaseURLFrom: existing.polish
            )
        )

        XCTAssertEqual(switched.stt.baseURL, APIProvider.openai.defaultBaseURL)
        XCTAssertEqual(switched.polish.baseURL, APIProvider.kimi.defaultBaseURL)
        XCTAssertNotEqual(switched.stt.baseURL, existing.stt.baseURL)
        XCTAssertNotEqual(switched.polish.baseURL, existing.polish.baseURL)
    }

    func testChangingModelWithinSameProviderPreservesCustomBaseURL() {
        let existing = APIEndpointConfiguration(
            provider: .openai,
            model: "gpt-4o-mini-transcribe",
            baseURL: " https://gateway.example.test/v1/ "
        )

        let updated = APIEndpointConfiguration.selecting(
            provider: .openai,
            model: "gpt-transcribe",
            preservingBaseURLFrom: existing
        )

        XCTAssertEqual(updated.baseURL, "https://gateway.example.test/v1")
    }
}
