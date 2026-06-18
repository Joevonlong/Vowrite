import XCTest
@testable import VowriteKit

/// Tests for `URL.validated(_:label:)` — the throwing factory that replaces
/// `URL(string:)!` force-unwraps in the request-building paths.
///
/// `URL(string:)` returns nil for malformed input (empty string, whitespace in
/// the authority, leading control characters — verified empirically on the
/// macOS 14+ toolchain). A user-configured custom base URL with an internal
/// space therefore crashed the old `URL(string: endpoint)!`. This factory
/// throws a descriptive `VowriteError.apiError` instead.
final class URLValidatedTests: XCTestCase {

    func testValidStringReturnsURLPreservingExactString() throws {
        let endpoint = "https://api.openai.com/v1/chat/completions"
        let url = try URL.validated(endpoint, label: "polish endpoint")
        XCTAssertEqual(url.absoluteString, endpoint)
    }

    func testInternalSpaceInHostThrows() {
        // A space in the authority makes URL(string:) return nil → previously crashed.
        XCTAssertThrowsError(
            try URL.validated("https://api x.com/v1/chat/completions", label: "polish endpoint")
        )
    }

    func testEmptyStringThrows() {
        XCTAssertThrowsError(try URL.validated("", label: "polish endpoint"))
    }

    func testThrownErrorIncludesLabelAndOffendingValue() {
        do {
            _ = try URL.validated("https://bad host.com/x", label: "polish endpoint")
            XCTFail("expected URL.validated to throw on malformed input")
        } catch let VowriteError.apiError(message) {
            XCTAssertTrue(message.contains("polish endpoint"), "error should name the context label")
            XCTAssertTrue(message.contains("https://bad host.com/x"), "error should include the offending URL string")
        } catch {
            XCTFail("expected VowriteError.apiError, got \(error)")
        }
    }
}
