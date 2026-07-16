import XCTest
@testable import VowriteKit

/// Verifies `PKCEHelper.generateCodeChallenge(from:)` against the official
/// RFC 7636 Appendix B test vector, plus basic sanity checks on
/// `generateCodeVerifier()`'s output shape (RFC 7636 §4.1).
///
/// RFC 7636 Appendix B ("Example for the S256 code_challenge_method"):
/// https://www.rfc-editor.org/rfc/rfc7636#appendix-B
final class PKCEHelperRFC7636Tests: XCTestCase {

    /// The exact code_verifier from RFC 7636 Appendix B.
    private let rfcVerifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
    /// The corresponding S256 code_challenge the RFC says this verifier must produce.
    private let rfcChallenge = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"

    func testGenerateCodeChallengeMatchesRFC7636AppendixBVector() {
        let challenge = PKCEHelper.generateCodeChallenge(from: rfcVerifier)
        XCTAssertEqual(challenge, rfcChallenge)
    }

    func testGeneratedChallengeIsBase64urlWithoutPadding() {
        let challenge = PKCEHelper.generateCodeChallenge(from: rfcVerifier)
        XCTAssertFalse(challenge.contains("+"))
        XCTAssertFalse(challenge.contains("/"))
        XCTAssertFalse(challenge.contains("="))
    }

    func testGenerateCodeVerifierProducesURLSafeStringOfExpectedLength() {
        let verifier = PKCEHelper.generateCodeVerifier()
        // 32 raw bytes base64url-encoded (no padding) → ceil(32*4/3) == 43 chars.
        XCTAssertEqual(verifier.count, 43)
        XCTAssertFalse(verifier.contains("+"))
        XCTAssertFalse(verifier.contains("/"))
        XCTAssertFalse(verifier.contains("="))
    }

    func testGenerateCodeVerifierProducesDistinctValuesEachCall() {
        let a = PKCEHelper.generateCodeVerifier()
        let b = PKCEHelper.generateCodeVerifier()
        XCTAssertNotEqual(a, b)
    }

    /// The verifier/challenge relationship must be deterministic — same input,
    /// same output — since the OAuth flow computes the challenge once at
    /// authorization-request time and must reproduce it implicitly server-side.
    func testGenerateCodeChallengeIsDeterministicForSameVerifier() {
        let challenge1 = PKCEHelper.generateCodeChallenge(from: rfcVerifier)
        let challenge2 = PKCEHelper.generateCodeChallenge(from: rfcVerifier)
        XCTAssertEqual(challenge1, challenge2)
    }
}
