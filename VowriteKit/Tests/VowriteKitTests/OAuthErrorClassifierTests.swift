import XCTest
@testable import VowriteKit

/// Tests for `OAuthErrorClassifier.shouldInvalidateToken`, the pure decision
/// that replaced "delete the token on any decode failure" in the Kimi and
/// OpenAI Codex OAuth refresh flows. Only a 400/401 with a well-formed
/// `invalid_grant`-class error body should trigger a token deletion; anything
/// else (5xx, HTML bodies, malformed JSON, other error codes) is transient.
final class OAuthErrorClassifierTests: XCTestCase {

    private func jsonBody(_ string: String) -> Data {
        string.data(using: .utf8)!
    }

    func testServerErrorWithHTMLBodyIsNotInvalidated() {
        let body = jsonBody("<html><body>502 Bad Gateway</body></html>")
        XCTAssertFalse(OAuthErrorClassifier.shouldInvalidateToken(status: 500, body: body))
    }

    func test400WithInvalidGrantIsInvalidated() {
        let body = jsonBody(#"{"error": "invalid_grant", "error_description": "refresh token expired"}"#)
        XCTAssertTrue(OAuthErrorClassifier.shouldInvalidateToken(status: 400, body: body))
    }

    func test401WithInvalidClientIsNotInvalidated() {
        // invalid_client is an auth-configuration problem (wrong client_id),
        // not proof the refresh token itself is dead — keep the token.
        let body = jsonBody(#"{"error": "invalid_client"}"#)
        XCTAssertFalse(OAuthErrorClassifier.shouldInvalidateToken(status: 401, body: body))
    }

    func test400WithUndecodableBodyIsNotInvalidated() {
        let body = jsonBody("not json at all")
        XCTAssertFalse(OAuthErrorClassifier.shouldInvalidateToken(status: 400, body: body))
    }

    func test200PathIsNeverInvalidatedRegardlessOfBody() {
        // A 200 response is the success path handled entirely elsewhere; the
        // classifier must never be triggered into invalidating on it even if
        // (hypothetically) called with an error-shaped body.
        let body = jsonBody(#"{"error": "invalid_grant"}"#)
        XCTAssertFalse(OAuthErrorClassifier.shouldInvalidateToken(status: 200, body: body))
    }

    func test401WithExpiredTokenIsInvalidated() {
        let body = jsonBody(#"{"error": "expired_token"}"#)
        XCTAssertTrue(OAuthErrorClassifier.shouldInvalidateToken(status: 401, body: body))
    }

    func test400WithRevokedIsInvalidated() {
        let body = jsonBody(#"{"error": "revoked"}"#)
        XCTAssertTrue(OAuthErrorClassifier.shouldInvalidateToken(status: 400, body: body))
    }
}
