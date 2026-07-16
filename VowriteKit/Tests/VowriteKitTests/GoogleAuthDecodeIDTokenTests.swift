import XCTest
@testable import VowriteKit

/// Tests for `GoogleAuthService.decodeIDToken` — base64url + JSON parsing of the
/// JWT payload segment (no signature verification, by design, for MVP; see the
/// code comment on the function). This is security-adjacent parsing surface:
/// it must degrade to `nil` on any malformed input rather than crashing, since
/// the callback URL / token response is attacker-influenceable network input.
///
/// Fixtures below are literal base64url JWT strings (verified independently
/// with a Python base64url encoder) rather than round-tripping through an
/// encoder in this test, so the test exercises exactly what a real IdP would
/// send on the wire.
final class GoogleAuthDecodeIDTokenTests: XCTestCase {

    private let header = "eyJhbGciOiAibm9uZSIsICJ0eXAiOiAiSldUIn0" // {"alg":"none","typ":"JWT"}

    // MARK: - Valid tokens

    func testDecodesEmailAndNameFromValidToken() {
        // payload: {"email": "user@example.com", "name": "Test User"}
        let payload = "eyJlbWFpbCI6ICJ1c2VyQGV4YW1wbGUuY29tIiwgIm5hbWUiOiAiVGVzdCBVc2VyIn0"
        let token = "\(header).\(payload).SIGNATURE"

        let info = GoogleAuthService.decodeIDToken(token)

        XCTAssertEqual(info?.email, "user@example.com")
        XCTAssertEqual(info?.name, "Test User")
    }

    func testNameIsNilWhenAbsentFromPayload() {
        // payload: {"email": "user2@example.com"}  (remainder 0 — no padding needed)
        let payload = "eyJlbWFpbCI6ICJ1c2VyMkBleGFtcGxlLmNvbSJ9"
        let token = "\(header).\(payload).SIGNATURE"

        let info = GoogleAuthService.decodeIDToken(token)

        XCTAssertEqual(info?.email, "user2@example.com")
        XCTAssertNil(info?.name)
    }

    func testDecodesWithNoSignatureSegment() {
        // Only header.payload, no third segment — decodeIDToken only requires >= 2 parts.
        let payload = "eyJlbWFpbCI6ICJ1c2VyMkBleGFtcGxlLmNvbSJ9"
        let token = "\(header).\(payload)"

        XCTAssertEqual(GoogleAuthService.decodeIDToken(token)?.email, "user2@example.com")
    }

    // MARK: - Base64url padding variants
    // Base64 remainder-after-stripping-'=' is always 0, 2, or 3 (never 1).

    func testDecodesPayloadRequiringNoPadding() {
        // "eyJlbWFpbCI6ICJ1c2VyMkBleGFtcGxlLmNvbSJ9".count % 4 == 0
        let payload = "eyJlbWFpbCI6ICJ1c2VyMkBleGFtcGxlLmNvbSJ9"
        XCTAssertEqual(payload.count % 4, 0)
        let token = "\(header).\(payload).sig"
        XCTAssertEqual(GoogleAuthService.decodeIDToken(token)?.email, "user2@example.com")
    }

    func testDecodesPayloadRequiringOnePaddingCharacter() {
        // payload: {"email": "test9@abc.com"} — count % 4 == 3, needs one "=".
        let payload = "eyJlbWFpbCI6ICJ0ZXN0OUBhYmMuY29tIn0"
        XCTAssertEqual(payload.count % 4, 3)
        let token = "\(header).\(payload).sig"
        XCTAssertEqual(GoogleAuthService.decodeIDToken(token)?.email, "test9@abc.com")
    }

    func testDecodesPayloadRequiringTwoPaddingCharacters() {
        // payload: {"email": "a@b.co"} — count % 4 == 2, needs two "=".
        let payload = "eyJlbWFpbCI6ICJhQGIuY28ifQ"
        XCTAssertEqual(payload.count % 4, 2)
        let token = "\(header).\(payload).sig"
        XCTAssertEqual(GoogleAuthService.decodeIDToken(token)?.email, "a@b.co")
    }

    func testDecodesPayloadContainingBothDashAndUnderscoreBase64urlCharacters() {
        // payload: {"email": "u@e.com", "note": "`.~`{@ta35h?KdMV+6>2>(`v!x0W8$(b]'8Y"}
        // Contains both '-' and '_' — exercises the -/_ → +// substitution before
        // standard base64 decoding.
        let payload = "eyJlbWFpbCI6ICJ1QGUuY29tIiwgIm5vdGUiOiAiYC5-YHtAdGEzNWg_S2RNVis2PjI-KGB2IXgwVzgkKGJdJzhZIn0"
        XCTAssertTrue(payload.contains("-"))
        XCTAssertTrue(payload.contains("_"))
        let token = "\(header).\(payload).sig"
        XCTAssertEqual(GoogleAuthService.decodeIDToken(token)?.email, "u@e.com")
    }

    // MARK: - Malformed input → nil, never crash

    func testReturnsNilForEmptyString() {
        XCTAssertNil(GoogleAuthService.decodeIDToken(""))
    }

    func testReturnsNilWhenNoDotSeparatorPresent() {
        XCTAssertNil(GoogleAuthService.decodeIDToken("notoken"))
    }

    func testReturnsNilForInvalidBase64Payload() {
        XCTAssertNil(GoogleAuthService.decodeIDToken("\(header).not valid base64!!!.sig"))
    }

    func testReturnsNilForNonJSONPayload() {
        // payload decodes fine as base64 but the bytes aren't valid JSON: "not-json-at-all"
        let payload = "bm90LWpzb24tYXQtYWxs"
        XCTAssertNil(GoogleAuthService.decodeIDToken("\(header).\(payload).sig"))
    }

    func testReturnsNilWhenEmailFieldMissing() {
        // payload: {"name": "No Email"}
        let payload = "eyJuYW1lIjogIk5vIEVtYWlsIn0"
        XCTAssertNil(GoogleAuthService.decodeIDToken("\(header).\(payload).sig"))
    }
}
