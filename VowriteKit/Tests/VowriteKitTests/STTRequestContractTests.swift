import Foundation
import XCTest
import AVFoundation
@testable import VowriteKit

private final class STTURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responseData = Data()
    nonisolated(unsafe) static var requests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var captured = request
        if captured.httpBody == nil, let stream = captured.httpBodyStream {
            stream.open()
            var data = Data()
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
            defer { buffer.deallocate(); stream.close() }
            while stream.hasBytesAvailable {
                let count = stream.read(buffer, maxLength: 4096)
                if count <= 0 { break }
                data.append(buffer, count: count)
            }
            captured.httpBody = data
        }
        Self.requests.append(captured)
        let response = HTTPURLResponse(
            url: request.url!, statusCode: 200, httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class STTRequestContractTests: XCTestCase {
    private func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [STTURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func audioFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("vowrite-contract-\(UUID().uuidString).m4a")
        try Data(repeating: 0x01, count: 32).write(to: url)
        return url
    }

    private func validWAV(seconds: Double) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("vowrite-contract-\(UUID().uuidString).wav")
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1))
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let frames = AVAudioFrameCount(seconds * 16_000)
        let chunkFrames: AVAudioFrameCount = 16_000
        var remaining = frames
        while remaining > 0 {
            let chunk = min(remaining, chunkFrames)
            let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunk))
            buffer.frameLength = chunk
            try file.write(from: buffer)
            remaining -= chunk
        }
        return url
    }

    private func sparseWAV(seconds: Double) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("vowrite-contract-long-\(UUID().uuidString).wav")
        let dataBytes = UInt32(seconds * 16_000 * 2)
        func le(_ value: UInt32) -> [UInt8] { [UInt8(value & 0xff), UInt8((value >> 8) & 0xff), UInt8((value >> 16) & 0xff), UInt8((value >> 24) & 0xff)] }
        var header = Data("RIFF".utf8)
        header.append(contentsOf: le(36 + dataBytes))
        header.append(contentsOf: Data("WAVEfmt ".utf8))
        header.append(contentsOf: le(16))
        header.append(contentsOf: [1, 0, 1, 0])
        header.append(contentsOf: le(16_000))
        header.append(contentsOf: le(32_000))
        header.append(contentsOf: [2, 0, 16, 0])
        header.append(contentsOf: Data("data".utf8))
        header.append(contentsOf: le(dataBytes))
        try header.write(to: url)
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: UInt64(44 + dataBytes))
        try handle.close()
        return url
    }

    override func setUp() {
        super.setUp()
        STTURLProtocol.requests = []
    }

    func testGPTTranscribeUsesTextAndLanguagesArray() async throws {
        STTURLProtocol.responseData = Data("hello world".utf8)
        let file = try audioFile()
        let text = try await OpenAISTTAdapter(session: session()).transcribe(
            audioURL: file, model: "gpt-transcribe", language: "zh-TW", prompt: nil,
            apiKey: "key", baseURL: "https://example.test/v1", provider: .openai
        )

        XCTAssertEqual(text, "hello world")
        let body = String(data: try XCTUnwrap(STTURLProtocol.requests.first?.httpBody), encoding: .utf8)!
        XCTAssertTrue(body.contains("name=\"response_format\"\r\n\r\ntext"))
        XCTAssertTrue(body.contains("name=\"languages[]\"\r\n\r\nzh-tw"))
        XCTAssertFalse(body.contains("name=\"language\""))
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testOpenAI4oMiniTranscribeUsesJSONAndDecodesText() async throws {
        STTURLProtocol.responseData = Data(#"{"text":"decoded transcript"}"#.utf8)
        let file = try audioFile()
        let text = try await OpenAISTTAdapter(session: session()).transcribe(
            audioURL: file, model: "gpt-4o-mini-transcribe", language: "en", prompt: nil,
            apiKey: "key", baseURL: "https://example.test/v1", provider: .openai
        )

        XCTAssertEqual(text, "decoded transcript")
        let body = String(data: try XCTUnwrap(STTURLProtocol.requests.first?.httpBody), encoding: .utf8)!
        XCTAssertTrue(body.contains("name=\"response_format\"\r\n\r\njson"))
        XCTAssertTrue(body.contains("name=\"language\"\r\n\r\nen"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testQwenRejectsUnsupportedAsyncModelBeforeNetwork() async throws {
        let file = try audioFile()
        do {
            _ = try await QwenSTTAdapter(session: session()).transcribe(
                audioURL: file, model: "fun-asr", language: nil, prompt: nil,
                apiKey: "key", baseURL: "https://example.test/v1", provider: .qwen
            )
            XCTFail("expected unsupported async model error")
        } catch {
            XCTAssertTrue(STTURLProtocol.requests.isEmpty)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testQwenSyncParsesResponseAndUsesNoAsyncRoute() async throws {
        STTURLProtocol.responseData = Data(#"{"output":{"choices":[{"message":{"content":[{"text":"qwen transcript"}]}}]}}"#.utf8)
        let file = try validWAV(seconds: 1)
        let text = try await QwenSTTAdapter(session: session()).transcribe(
            audioURL: file, model: "qwen3-asr-flash", language: nil, prompt: nil,
            apiKey: "key", baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1", provider: .qwen
        )
        XCTAssertEqual(text, "qwen transcript")
        XCTAssertEqual(STTURLProtocol.requests.count, 1)
        let body = String(data: try XCTUnwrap(STTURLProtocol.requests.first?.httpBody), encoding: .utf8)
        XCTAssertTrue(body?.contains("qwen3-asr-flash") == true)
        XCTAssertTrue(body?.contains("data:audio\\/wav;base64,") == true)
        XCTAssertTrue(STTURLProtocol.requests.first?.url?.absoluteString.contains("multimodal-generation") == true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testQwenRejectsOversizedAndOverDurationBeforeNetwork() async throws {
        let oversized = try audioFile()
        try Data(repeating: 0, count: 10 * 1024 * 1024 + 1).write(to: oversized)
        do {
            _ = try await QwenSTTAdapter(session: session()).transcribe(
                audioURL: oversized, model: "qwen3-asr-flash", language: nil, prompt: nil,
                apiKey: "key", baseURL: "https://example.test/v1", provider: .qwen
            )
            XCTFail("expected size error")
        } catch {
            XCTAssertTrue((error as NSError).localizedDescription.contains("10 MB"))
            XCTAssertTrue(STTURLProtocol.requests.isEmpty)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: oversized.path))

        let long = try sparseWAV(seconds: 301)
        do {
            _ = try await QwenSTTAdapter(session: session()).transcribe(
                audioURL: long, model: "qwen3-asr-flash", language: nil, prompt: nil,
                apiKey: "key", baseURL: "https://example.test/v1", provider: .qwen
            )
            XCTFail("expected duration error")
        } catch {
            XCTAssertTrue((error as NSError).localizedDescription.contains("5 minutes"))
            XCTAssertTrue(STTURLProtocol.requests.isEmpty)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: long.path))
    }
}
