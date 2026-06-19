import XCTest
@testable import VowriteKit

/// Tests for `APIEndpointConfiguration.normalizeBaseURL(_:provider:)` — the
/// canonicalization applied to every stored/resolved base URL. Endpoints are
/// built as `"\(base)/chat/completions"`, so the base must not carry a trailing
/// slash or it produces a double-slash path that strict servers reject.
final class NormalizeBaseURLTests: XCTestCase {

    func testEmptyFallsBackToProviderDefault() {
        XCTAssertEqual(
            APIEndpointConfiguration.normalizeBaseURL("", provider: .openai),
            APIProvider.openai.defaultBaseURL
        )
        XCTAssertEqual(
            APIEndpointConfiguration.normalizeBaseURL(nil, provider: .openai),
            APIProvider.openai.defaultBaseURL
        )
    }

    func testWhitespaceTrimmed() {
        XCTAssertEqual(
            APIEndpointConfiguration.normalizeBaseURL("  https://api.example.com/v1  ", provider: .openai),
            "https://api.example.com/v1"
        )
    }

    func testNormalURLUnchanged() {
        XCTAssertEqual(
            APIEndpointConfiguration.normalizeBaseURL("https://api.example.com/v1", provider: .openai),
            "https://api.example.com/v1"
        )
    }

    // NEW: trailing-slash canonicalization (prevents "...//chat/completions")

    func testTrailingSlashStripped() {
        XCTAssertEqual(
            APIEndpointConfiguration.normalizeBaseURL("https://api.example.com/v1/", provider: .openai),
            "https://api.example.com/v1"
        )
    }

    func testMultipleTrailingSlashesStripped() {
        XCTAssertEqual(
            APIEndpointConfiguration.normalizeBaseURL("https://api.example.com/v1//", provider: .openai),
            "https://api.example.com/v1"
        )
    }

    func testWhitespaceThenTrailingSlashBothHandled() {
        XCTAssertEqual(
            APIEndpointConfiguration.normalizeBaseURL("  https://api.example.com/v1/  ", provider: .openai),
            "https://api.example.com/v1"
        )
    }

    /// Guards against a providers.json entry regressing into a trailing slash.
    func testProviderDefaultsHaveNoTrailingSlash() {
        XCTAssertFalse(APIProvider.openai.defaultBaseURL.hasSuffix("/"))
        XCTAssertFalse(APIProvider.deepseek.defaultBaseURL.hasSuffix("/"))
        XCTAssertFalse(APIProvider.groq.defaultBaseURL.hasSuffix("/"))
    }
}
