import XCTest
@testable import VowriteKit

/// Verifies STT adapters always clean up the recording temp file — even when
/// transcription throws. Previously cleanup ran only on the success path, so any
/// error (API failure, malformed URL, oversized file) leaked the audio file in
/// the temp directory (V-021).
final class STTAdapterTempFileTests: XCTestCase {

    private func makeTempAudioFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("vowrite-test-\(UUID().uuidString).m4a")
        try Data("fake audio".utf8).write(to: url)
        return url
    }

    func testOpenAIAdapterRemovesTempFileWhenTranscribeThrows() async throws {
        let tmp = try makeTempAudioFile()
        XCTAssertTrue(FileManager.default.fileExists(atPath: tmp.path))

        // Malformed base URL → throws while building the request.
        _ = try? await OpenAISTTAdapter().transcribe(
            audioURL: tmp, model: "whisper-1", language: nil, prompt: nil,
            apiKey: "k", baseURL: "https://api x.com", provider: .openai
        )

        XCTAssertFalse(
            FileManager.default.fileExists(atPath: tmp.path),
            "OpenAI STT temp file must be cleaned up even on failure"
        )
    }

    func testQwenAdapterRemovesTempFileWhenTranscribeThrows() async throws {
        let tmp = try makeTempAudioFile()
        XCTAssertTrue(FileManager.default.fileExists(atPath: tmp.path))

        _ = try? await QwenSTTAdapter().transcribe(
            audioURL: tmp, model: "qwen3-asr-flash", language: nil, prompt: nil,
            apiKey: "k", baseURL: "https://api x.com", provider: .qwen
        )

        XCTAssertFalse(
            FileManager.default.fileExists(atPath: tmp.path),
            "Qwen STT temp file must be cleaned up even on failure"
        )
    }
}
