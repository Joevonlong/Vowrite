import AVFoundation
import Foundation
import XCTest
@testable import VowriteKit

private final class DoubaoURLProtocol: URLProtocol {
    nonisolated(unsafe) static var statusCode = 200
    nonisolated(unsafe) static var responseHeaders: [String: String] = ["X-Api-Status-Code": "20000000"]
    nonisolated(unsafe) static var responseData = Data(#"{"result":{"text":"transcript"}}"#.utf8)
    nonisolated(unsafe) static var requests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var capturedRequest = request
        if capturedRequest.httpBody == nil, let stream = capturedRequest.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var body = Data()
            var buffer = [UInt8](repeating: 0, count: 4_096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                guard count > 0 else { break }
                body.append(buffer, count: count)
            }
            capturedRequest.httpBody = body
        }
        Self.requests.append(capturedRequest)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: Self.statusCode,
            httpVersion: nil,
            headerFields: Self.responseHeaders
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class DoubaoSTTAdapterTests: XCTestCase {
    private func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DoubaoURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func m4aFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("vowrite-doubao-\(UUID().uuidString).m4a")
        let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!
        let file = try AVAudioFile(forWriting: url, settings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 2,
        ])
        // Exceeds the adapter's 4,096-frame conversion chunk so the test also
        // exercises multi-buffer conversion and its final converter drain.
        let frames: AVAudioFrameCount = 9_600
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let left = buffer.floatChannelData![0]
        let right = buffer.floatChannelData![1]
        for index in 0..<Int(frames) {
            left[index] = sin(Float(index) * 0.1)
            right[index] = cos(Float(index) * 0.07)
        }
        try file.write(from: buffer)
        return url
    }

    override func setUp() {
        super.setUp()
        DoubaoURLProtocol.statusCode = 200
        DoubaoURLProtocol.responseHeaders = ["X-Api-Status-Code": "20000000"]
        DoubaoURLProtocol.responseData = Data(#"{"result":{"text":"transcript"}}"#.utf8)
        DoubaoURLProtocol.requests = []
    }

    func testFlashRequestUsesDedicatedHeadersAndBase64WAV() async throws {
        let file = try m4aFile()
        let inputFile = try AVAudioFile(forReading: file)
        let inputDuration = Double(inputFile.length) / inputFile.processingFormat.sampleRate
        let result = try await DoubaoSTTAdapter(session: session()).transcribe(
            audioURL: file,
            model: "volc.bigasr.auc_turbo",
            language: "zh-CN",
            prompt: "ignored because corpus/hotword configuration is deferred",
            apiKey: "test-doubao-key",
            baseURL: "https://openspeech.bytedance.com/api/v3/auc/bigmodel",
            provider: .doubaoSpeech
        )

        XCTAssertEqual(result, "transcript")
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        let request = try XCTUnwrap(DoubaoURLProtocol.requests.only)
        XCTAssertEqual(request.url?.absoluteString, "https://openspeech.bytedance.com/api/v3/auc/bigmodel/recognize/flash")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Api-Key"), "test-doubao-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Api-Resource-Id"), "volc.bigasr.auc_turbo")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Api-Sequence"), "-1")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertNotNil(UUID(uuidString: try XCTUnwrap(request.value(forHTTPHeaderField: "X-Api-Request-Id"))))

        let payload = try XCTUnwrap(try JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: Any])
        XCTAssertNotNil(UUID(uuidString: (payload["user"] as? [String: Any])?["uid"] as? String ?? ""))
        XCTAssertEqual((payload["audio"] as? [String: Any])?["format"] as? String, "wav")
        let audio = try XCTUnwrap(payload["audio"] as? [String: Any])
        let encodedAudio = try XCTUnwrap(audio["data"] as? String)
        XCTAssertFalse(encodedAudio.contains("data:"))
        let decodedAudio = try XCTUnwrap(Data(base64Encoded: encodedAudio))
        XCTAssertEqual(String(data: decodedAudio.prefix(4), encoding: .ascii), "RIFF")
        XCTAssertEqual(Array(decodedAudio[22...23]), [1, 0], "WAV must be mono")
        XCTAssertEqual(Array(decodedAudio[24...27]), [0x80, 0x3e, 0, 0], "WAV must be 16 kHz")
        XCTAssertEqual(Array(decodedAudio[34...35]), [16, 0], "WAV must be 16-bit PCM")
        XCTAssertTrue(decodedAudio.dropFirst(44).contains { $0 != 0 })
        let uploadedWAV = FileManager.default.temporaryDirectory
            .appendingPathComponent("vowrite-doubao-uploaded-\(UUID().uuidString).wav")
        try decodedAudio.write(to: uploadedWAV)
        defer { try? FileManager.default.removeItem(at: uploadedWAV) }
        let wavFile = try AVAudioFile(forReading: uploadedWAV)
        XCTAssertEqual(wavFile.processingFormat.sampleRate, 16_000, accuracy: 0.1)
        XCTAssertEqual(wavFile.processingFormat.channelCount, 1)
        let uploadedDuration = Double(wavFile.length) / wavFile.processingFormat.sampleRate
        XCTAssertEqual(uploadedDuration, inputDuration, accuracy: 0.03, "converter drain must retain the final fixture frames")
        XCTAssertEqual(audio["language"] as? String, "zh-CN")
        let options = try XCTUnwrap(payload["request"] as? [String: Any])
        XCTAssertEqual(options["model_name"] as? String, "bigmodel")
        XCTAssertEqual(options["enable_itn"] as? Bool, true)
        XCTAssertEqual(options["enable_punc"] as? Bool, true)
        XCTAssertEqual(options["enable_ddc"] as? Bool, false)
        XCTAssertNil(options["language"])
        XCTAssertFalse(String(data: try XCTUnwrap(request.httpBody), encoding: .utf8)?.contains("test-doubao-key") == true)
    }

    func testSilenceStatusReturnsEmptyTextAndUnknownModelNeverUploads() async throws {
        DoubaoURLProtocol.responseHeaders = ["X-Api-Status-Code": "20000003"]
        let silent = try m4aFile()
        let result = try await DoubaoSTTAdapter(session: session()).transcribe(
            audioURL: silent,
            model: "volc.bigasr.auc_turbo",
            language: nil,
            prompt: nil,
            apiKey: "test-doubao-key",
            baseURL: "https://openspeech.bytedance.com/api/v3/auc/bigmodel",
            provider: .doubaoSpeech
        )
        XCTAssertEqual(result, "")
        XCTAssertFalse(FileManager.default.fileExists(atPath: silent.path))

        DoubaoURLProtocol.requests = []
        let unsupported = try m4aFile()
        await XCTAssertThrowsErrorAsync {
            _ = try await DoubaoSTTAdapter(session: self.session()).transcribe(
                audioURL: unsupported,
                model: "volc.seedasr.auc",
                language: nil,
                prompt: nil,
                apiKey: "test-doubao-key",
                baseURL: "https://openspeech.bytedance.com/api/v3/auc/bigmodel",
                provider: .doubaoSpeech
            )
        }
        XCTAssertTrue(DoubaoURLProtocol.requests.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: unsupported.path))

        DoubaoURLProtocol.requests = []
        let noKey = try m4aFile()
        await XCTAssertThrowsErrorAsync {
            _ = try await DoubaoSTTAdapter(session: self.session()).transcribe(
                audioURL: noKey,
                model: "volc.bigasr.auc_turbo",
                language: nil,
                prompt: nil,
                apiKey: nil,
                baseURL: "https://openspeech.bytedance.com/api/v3/auc/bigmodel",
                provider: .doubaoSpeech
            )
        }
        XCTAssertTrue(DoubaoURLProtocol.requests.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: noKey.path))
    }

    func testConnectionProbeUsesSilentFlashAdapterInsteadOfModelsEndpoint() async throws {
        let configuration = APIEndpointConfiguration(
            provider: .doubaoSpeech,
            model: "volc.bigasr.auc_turbo"
        )

        try await APIConnectionTester.testSTTConnection(
            configuration: configuration,
            apiKeyOverride: "test-doubao-key",
            session: session()
        )

        let request = try XCTUnwrap(DoubaoURLProtocol.requests.only)
        XCTAssertEqual(request.url?.path, "/api/v3/auc/bigmodel/recognize/flash")
        XCTAssertNotEqual(request.url?.path, "/api/v3/auc/bigmodel/models")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Api-Key"), "test-doubao-key")
        let payload = try XCTUnwrap(try JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: Any])
        let audio = try XCTUnwrap(payload["audio"] as? [String: Any])
        let data = try XCTUnwrap(Data(base64Encoded: try XCTUnwrap(audio["data"] as? String)))
        XCTAssertTrue(data.dropFirst(44).allSatisfy { $0 == 0 })
        let options = try XCTUnwrap(payload["request"] as? [String: Any])
        XCTAssertEqual(options["enable_auto_lang"] as? Bool, true)
    }

    func testMissingResultAndSafeProviderFailuresDoNotBecomeEmptyTranscript() async throws {
        DoubaoURLProtocol.responseData = Data(#"{"result":{}}"#.utf8)
        let malformed = try m4aFile()
        await XCTAssertThrowsErrorAsync {
            _ = try await DoubaoSTTAdapter(session: self.session()).transcribe(
                audioURL: malformed,
                model: "volc.bigasr.auc_turbo",
                language: nil,
                prompt: nil,
                apiKey: "test-doubao-key",
                baseURL: "https://openspeech.bytedance.com/api/v3/auc/bigmodel",
                provider: .doubaoSpeech
            )
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: malformed.path))

        DoubaoURLProtocol.statusCode = 429
        DoubaoURLProtocol.responseData = Data("provider body must not escape".utf8)
        let throttled = try m4aFile()
        do {
            _ = try await DoubaoSTTAdapter(session: session()).transcribe(
                audioURL: throttled,
                model: "volc.bigasr.auc_turbo",
                language: nil,
                prompt: nil,
                apiKey: "test-doubao-key",
                baseURL: "https://openspeech.bytedance.com/api/v3/auc/bigmodel",
                provider: .doubaoSpeech
            )
            XCTFail("expected throttling error")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("quota or concurrency"))
            XCTAssertFalse(error.localizedDescription.contains("provider body must not escape"))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: throttled.path))

        DoubaoURLProtocol.statusCode = 200
        DoubaoURLProtocol.responseHeaders = ["X-Api-Status-Code": "55000031"]
        let busy = try m4aFile()
        do {
            _ = try await DoubaoSTTAdapter(session: session()).transcribe(
                audioURL: busy,
                model: "volc.bigasr.auc_turbo",
                language: nil,
                prompt: nil,
                apiKey: "test-doubao-key",
                baseURL: "https://openspeech.bytedance.com/api/v3/auc/bigmodel",
                provider: .doubaoSpeech
            )
            XCTFail("expected busy error")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("55000031"))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: busy.path))

        DoubaoURLProtocol.responseHeaders = [:]
        let missingStatus = try m4aFile()
        await XCTAssertThrowsErrorAsync {
            _ = try await DoubaoSTTAdapter(session: self.session()).transcribe(
                audioURL: missingStatus,
                model: "volc.bigasr.auc_turbo",
                language: nil,
                prompt: nil,
                apiKey: "test-doubao-key",
                baseURL: "https://openspeech.bytedance.com/api/v3/auc/bigmodel",
                provider: .doubaoSpeech
            )
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: missingStatus.path))
    }

    func testPreCancelledTaskRejectsBeforeUploadAndCleansSource() async throws {
        let source = try m4aFile()
        let gate = CancellationGate()
        let task = Task {
            await gate.wait()
            return try await DoubaoSTTAdapter(session: self.session()).transcribe(
                audioURL: source,
                model: "volc.bigasr.auc_turbo",
                language: nil,
                prompt: nil,
                apiKey: "test-doubao-key",
                baseURL: "https://openspeech.bytedance.com/api/v3/auc/bigmodel",
                provider: .doubaoSpeech
            )
        }
        task.cancel()
        await gate.open()
        await XCTAssertThrowsErrorAsync { _ = try await task.value }
        XCTAssertTrue(DoubaoURLProtocol.requests.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
    }

    func testOversizedSparseSourceIsRejectedBeforeUploadAndCleaned() async throws {
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("vowrite-doubao-oversized-\(UUID().uuidString).m4a")
        FileManager.default.createFile(atPath: source.path, contents: Data([0]))
        let handle = try FileHandle(forWritingTo: source)
        try handle.truncate(atOffset: UInt64(100 * 1024 * 1024 + 1))
        try handle.close()

        await XCTAssertThrowsErrorAsync {
            _ = try await DoubaoSTTAdapter(session: self.session()).transcribe(
                audioURL: source,
                model: "volc.bigasr.auc_turbo",
                language: nil,
                prompt: nil,
                apiKey: "test-doubao-key",
                baseURL: "https://openspeech.bytedance.com/api/v3/auc/bigmodel",
                provider: .doubaoSpeech
            )
        }
        XCTAssertTrue(DoubaoURLProtocol.requests.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
    }
}

private actor CancellationGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isOpen = false

    func wait() async {
        await withCheckedContinuation { continuation in
            if isOpen {
                continuation.resume()
            } else {
                self.continuation = continuation
            }
        }
    }

    func open() {
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}

private extension Array where Element == URLRequest {
    var only: URLRequest? { count == 1 ? first : nil }
}

private func XCTAssertThrowsErrorAsync(
    _ expression: () async throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await expression()
        XCTFail("expected error", file: file, line: line)
    } catch {}
}
