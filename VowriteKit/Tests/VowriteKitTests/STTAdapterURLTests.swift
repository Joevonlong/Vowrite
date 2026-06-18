import XCTest
@testable import VowriteKit

/// Verifies STT adapters throw a catchable error — rather than crashing on a
/// force-unwrapped `URL(string:)!` — when a custom STT base URL is malformed.
///
/// `OpenAISTTAdapter` builds and validates its endpoint URL before reading the
/// audio file or touching the network, so a malformed base URL surfaces as a
/// thrown `VowriteError` with no real file or request needed.
final class STTAdapterURLTests: XCTestCase {

    func testOpenAIAdapterThrowsOnMalformedBaseURL() async {
        let adapter = OpenAISTTAdapter()
        do {
            _ = try await adapter.transcribe(
                audioURL: URL(fileURLWithPath: "/tmp/vowrite-nonexistent.m4a"),
                model: "whisper-1",
                language: nil,
                prompt: nil,
                apiKey: "test-key",
                baseURL: "https://api x.com",   // internal space → URL(string:) returns nil
                provider: .openai
            )
            XCTFail("expected transcribe to throw on a malformed base URL, not crash")
        } catch {
            // Expected: VowriteError.apiError("Invalid … URL …"), thrown before any I/O.
        }
    }
}
