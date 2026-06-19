import XCTest
@testable import VowriteKit

/// Tests for `String.formURLEncoded()` — the encoder used to build OAuth
/// `application/x-www-form-urlencoded` token-exchange bodies. The critical case
/// is `+`: an OAuth `code` containing `+` must encode to `%2B`, or the server
/// decodes it as a space and the exchange fails (V-018).
final class FormURLEncodedTests: XCTestCase {

    func testUnreservedCharactersAreUnchanged() {
        // Typical URL-safe-base64 OAuth codes survive unchanged → no regression.
        XCTAssertEqual("Abc123-._~".formURLEncoded(), "Abc123-._~")
    }

    func testPlusIsEncoded() {
        XCTAssertEqual("a+b".formURLEncoded(), "a%2Bb")
    }

    func testAmpersandIsEncoded() {
        XCTAssertEqual("a&b".formURLEncoded(), "a%26b")
    }

    func testEqualsIsEncoded() {
        XCTAssertEqual("a=b".formURLEncoded(), "a%3Db")
    }

    func testSpaceIsEncoded() {
        XCTAssertEqual("a b".formURLEncoded(), "a%20b")
    }

    func testSlashIsKept() {
        // `/` is not a form-body delimiter; kept unencoded (matches the proven
        // Kimi encoder this consolidates).
        XCTAssertEqual("a/b".formURLEncoded(), "a/b")
    }

    func testRealisticGoogleAuthCodeWithPlusAndSlash() {
        XCTAssertEqual("4/0Ab_x+y/z".formURLEncoded(), "4/0Ab_x%2By/z")
    }

    func testEmptyString() {
        XCTAssertEqual("".formURLEncoded(), "")
    }
}
