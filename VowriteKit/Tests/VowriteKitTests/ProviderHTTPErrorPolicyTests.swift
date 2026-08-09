import XCTest
@testable import VowriteKit

final class ProviderHTTPErrorPolicyTests: XCTestCase {
    func testPublicErrorDiscardsVeryLargeSecretResponseBody() throws {
        let secret = "provider-secret-token-should-never-be-public"
        let body = Data((secret + String(repeating: "x", count: 1_000_000)).utf8)
        let response = try XCTUnwrap(HTTPURLResponse(
            url: URL(string: "https://api.example.com/v1/chat/completions")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["X-Request-ID": "req-safe-123"]
        ))

        let error = ProviderHTTPErrorPolicy.publicError(
            context: .polishRequest,
            response: response,
            discardingResponseBody: body
        )
        let description = error.localizedDescription

        XCTAssertEqual(
            description,
            "Polish API request failed (HTTP 429, request ID: req-safe-123)."
        )
        XCTAssertFalse(description.contains(secret))
        XCTAssertLessThan(description.utf8.count, 160)
    }

    func testRequestIDIsRejectedWhenItContainsUnsafeCharacters() throws {
        let response = try XCTUnwrap(HTTPURLResponse(
            url: URL(string: "https://api.example.com/v1/messages")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: [
                "Anthropic-Request-ID": "req-safe\r\nAuthorization: provider-secret"
            ]
        ))

        let error = ProviderHTTPErrorPolicy.publicError(
            context: .claudePolishRequest,
            response: response
        )

        XCTAssertEqual(error.localizedDescription, "Claude API request failed (HTTP 500).")
        XCTAssertFalse(error.localizedDescription.contains("provider-secret"))
        XCTAssertFalse(error.localizedDescription.contains("Authorization"))
    }

    func testRequestIDIsBoundedToPublicPolicyLimit() throws {
        let longRequestID = "req-" + String(repeating: "a", count: 500)
        let response = try XCTUnwrap(HTTPURLResponse(
            url: URL(string: "https://api.example.com/v1/audio/transcriptions")!,
            statusCode: 503,
            httpVersion: nil,
            headerFields: ["Request-ID": longRequestID]
        ))

        let error = ProviderHTTPErrorPolicy.publicError(
            context: .sttRequest,
            response: response
        )
        let description = error.localizedDescription
        let requestIDSuffix = try XCTUnwrap(
            description.components(separatedBy: "request ID: ").last
        )
        let requestID = try XCTUnwrap(requestIDSuffix.split(separator: ")", maxSplits: 1).first)

        XCTAssertEqual(requestID.count, ProviderHTTPErrorPolicy.maximumRequestIDLength)
        XCTAssertTrue(requestID.allSatisfy {
            $0.isASCII && ($0.isLetter || $0.isNumber || "-_.:".contains($0))
        })
        XCTAssertFalse(description.contains(String(repeating: "a", count: 65)))
    }

    func testProviderMessageCannotLeakThroughLegacyIflytekError() {
        let secret = "provider-secret-in-websocket-message"
        let error = IflytekError.apiError(code: 10105, message: secret)

        XCTAssertEqual(
            error.localizedDescription,
            "iFlytek API request failed (provider code 10105)."
        )
        XCTAssertFalse(error.localizedDescription.contains(secret))
    }
}
