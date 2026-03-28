import Foundation
import AVFoundation
#if canImport(CommonCrypto)
import CommonCrypto
#endif

/// STT adapter for iFlytek (讯飞) Streaming Voice Dictation API.
/// Uses WebSocket protocol with HMAC-SHA256 authentication.
/// Supports Chinese (+ simple English), 23 Chinese dialects, and minor languages.
///
/// API Key format: "AppID:APIKey:APISecret" (three credentials joined by colons)
/// API Doc: https://www.xfyun.cn/doc/asr/voicedictation/API.html
public final class IflytekSTTAdapter: STTAdapter {

    // MARK: - Credentials

    private struct Credentials {
        let appID: String
        let apiKey: String
        let apiSecret: String
    }

    private func parseCredentials(_ combined: String?) -> Credentials? {
        guard let combined = combined else { return nil }
        let parts = combined.split(separator: ":", maxSplits: 2)
        guard parts.count == 3 else { return nil }
        return Credentials(
            appID: String(parts[0]),
            apiKey: String(parts[1]),
            apiSecret: String(parts[2])
        )
    }

    // MARK: - STTAdapter

    public func transcribe(
        audioURL: URL,
        model: String,
        language: String?,
        prompt: String?,
        apiKey: String?,
        baseURL: String,
        provider: APIProvider
    ) async throws -> String {
        guard let credentials = parseCredentials(apiKey) else {
            throw IflytekError.invalidCredentials
        }

        // 1. Convert audio to PCM 16kHz 16bit mono
        let pcmData = try await convertToPCM16kHz(audioURL)

        // 2. Build authenticated WebSocket URL
        let wsURL = try buildAuthURL(
            base: baseURL.isEmpty ? "wss://iat-api.xfyun.cn/v2/iat" : baseURL,
            apiKey: credentials.apiKey,
            apiSecret: credentials.apiSecret
        )

        // 3. Connect and transcribe
        return try await withCheckedThrowingContinuation { continuation in
            let session = URLSession(configuration: .default)
            let task = session.webSocketTask(with: wsURL)
            task.resume()

            Task {
                do {
                    let result = try await self.performTranscription(
                        task: task,
                        pcmData: pcmData,
                        appID: credentials.appID,
                        language: language ?? "zh_cn",
                        domain: model.isEmpty ? "iat" : model
                    )
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
                task.cancel(with: .normalClosure, reason: nil)
            }
        }
    }

    // MARK: - WebSocket Transcription

    private func performTranscription(
        task: URLSessionWebSocketTask,
        pcmData: Data,
        appID: String,
        language: String,
        domain: String
    ) async throws -> String {
        let frameSize = 1280 // 40ms of 16kHz 16bit mono PCM
        let chunks = stride(from: 0, to: pcmData.count, by: frameSize).map { offset in
            pcmData[offset..<min(offset + frameSize, pcmData.count)]
        }

        // Send first frame (with common + business params)
        if let firstChunk = chunks.first {
            let firstFrame = buildFirstFrame(
                appID: appID,
                language: language,
                domain: domain,
                audioData: Data(firstChunk)
            )
            try await task.send(.string(firstFrame))
        }

        // Send middle frames
        for i in 1..<max(1, chunks.count - 1) {
            try await Task.sleep(nanoseconds: 40_000_000) // 40ms interval
            let frame = buildContinueFrame(audioData: Data(chunks[i]))
            try await task.send(.string(frame))
        }

        // Send last frame
        if chunks.count > 1 {
            try await Task.sleep(nanoseconds: 40_000_000)
            let lastFrame = buildLastFrame(audioData: Data(chunks[chunks.count - 1]))
            try await task.send(.string(lastFrame))
        } else {
            // Only one chunk — send it as last frame too
            let lastFrame = buildLastFrame(audioData: Data())
            try await task.send(.string(lastFrame))
        }

        // Receive results
        var fullText = ""
        while true {
            let message = try await task.receive()
            switch message {
            case .string(let text):
                guard let data = text.data(using: .utf8),
                      let response = try? JSONDecoder().decode(IflytekResponse.self, from: data) else {
                    continue
                }

                if response.code != 0 {
                    throw IflytekError.apiError(code: response.code, message: response.message ?? "Unknown error")
                }

                if let result = response.data?.result {
                    fullText += extractText(from: result)
                }

                if response.data?.status == 2 {
                    // Final result received
                    return fullText.trimmingCharacters(in: .whitespacesAndNewlines)
                }

            case .data:
                continue
            @unknown default:
                continue
            }
        }
    }

    // MARK: - Frame Builders

    private func buildFirstFrame(appID: String, language: String, domain: String, audioData: Data) -> String {
        let audioBase64 = audioData.base64EncodedString()
        return """
        {
            "common": {"app_id": "\(appID)"},
            "business": {
                "language": "\(language)",
                "domain": "\(domain)",
                "accent": "mandarin",
                "vad_eos": 3000,
                "ptt": 1
            },
            "data": {
                "status": 0,
                "format": "audio/L16;rate=16000",
                "encoding": "raw",
                "audio": "\(audioBase64)"
            }
        }
        """
    }

    private func buildContinueFrame(audioData: Data) -> String {
        let audioBase64 = audioData.base64EncodedString()
        return """
        {
            "data": {
                "status": 1,
                "format": "audio/L16;rate=16000",
                "encoding": "raw",
                "audio": "\(audioBase64)"
            }
        }
        """
    }

    private func buildLastFrame(audioData: Data) -> String {
        let audioBase64 = audioData.base64EncodedString()
        return """
        {
            "data": {
                "status": 2,
                "format": "audio/L16;rate=16000",
                "encoding": "raw",
                "audio": "\(audioBase64)"
            }
        }
        """
    }

    // MARK: - Result Parsing

    /// Extract text from iFlytek's nested result structure:
    /// result.ws[] → each ws has cw[] → each cw has w (the actual word)
    private func extractText(from result: IflytekResult) -> String {
        result.ws?.compactMap { ws in
            ws.cw?.compactMap { $0.w }.joined()
        }.joined() ?? ""
    }

    // MARK: - Authentication

    /// Build authenticated WebSocket URL using HMAC-SHA256 signature.
    /// See: https://www.xfyun.cn/doc/asr/voicedictation/API.html#接口鉴权
    private func buildAuthURL(base: String, apiKey: String, apiSecret: String) throws -> URL {
        guard let baseURL = URL(string: base),
              let host = baseURL.host else {
            throw IflytekError.invalidBaseURL
        }

        // RFC1123 date
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        let date = formatter.string(from: Date())

        // Signature origin
        let signatureOrigin = "host: \(host)\ndate: \(date)\nGET \(baseURL.path) HTTP/1.1"

        // HMAC-SHA256
        let signature = hmacSHA256(key: apiSecret, data: signatureOrigin)
        let signatureBase64 = signature.base64EncodedString()

        // Authorization
        let authorizationOrigin = "api_key=\"\(apiKey)\", algorithm=\"hmac-sha256\", headers=\"host date request-line\", signature=\"\(signatureBase64)\""
        let authorization = Data(authorizationOrigin.utf8).base64EncodedString()

        // URL encode
        let dateEncoded = date.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? date
        let authEncoded = authorization.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? authorization

        let urlString = "\(base)?authorization=\(authEncoded)&date=\(dateEncoded)&host=\(host)"
        guard let url = URL(string: urlString) else {
            throw IflytekError.invalidAuthURL
        }
        return url
    }

    private func hmacSHA256(key: String, data: String) -> Data {
        let keyData = Array(key.utf8)
        let dataBytes = Array(data.utf8)
        var hmac = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), keyData, keyData.count, dataBytes, dataBytes.count, &hmac)
        return Data(hmac)
    }

    // MARK: - Audio Conversion

    /// Convert audio file to PCM 16kHz 16bit mono raw data.
    private func convertToPCM16kHz(_ audioURL: URL) async throws -> Data {
        let sourceFile = try AVAudioFile(forReading: audioURL)
        let sourceFormat = sourceFile.processingFormat

        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16000,
            channels: 1,
            interleaved: true
        )!

        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            throw IflytekError.audioConversionFailed
        }

        // Calculate output frame count
        let ratio = 16000.0 / sourceFormat.sampleRate
        let outputFrameCount = AVAudioFrameCount(Double(sourceFile.length) * ratio)
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCount) else {
            throw IflytekError.audioConversionFailed
        }

        // Read source into buffer
        let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: AVAudioFrameCount(sourceFile.length))!
        try sourceFile.read(into: sourceBuffer)

        // Convert
        var error: NSError?
        var inputConsumed = false
        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if inputConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            inputConsumed = true
            outStatus.pointee = .haveData
            return sourceBuffer
        }

        if let error = error {
            throw IflytekError.audioConversionError(error.localizedDescription)
        }

        // Extract raw PCM bytes
        guard let int16Data = outputBuffer.int16ChannelData else {
            throw IflytekError.audioConversionFailed
        }
        let byteCount = Int(outputBuffer.frameLength) * MemoryLayout<Int16>.size
        return Data(bytes: int16Data[0], count: byteCount)
    }
}

// MARK: - Response Models

private struct IflytekResponse: Codable {
    let code: Int
    let message: String?
    let sid: String?
    let data: IflytekData?
}

private struct IflytekData: Codable {
    let status: Int?
    let result: IflytekResult?
}

private struct IflytekResult: Codable {
    let sn: Int?
    let ls: Bool?
    let bg: Int?
    let ed: Int?
    let ws: [IflytekWord]?
}

private struct IflytekWord: Codable {
    let bg: Int?
    let cw: [IflytekCharWord]?
}

private struct IflytekCharWord: Codable {
    let w: String?
    let sc: Double?
}

// MARK: - Errors

public enum IflytekError: LocalizedError {
    case invalidCredentials
    case invalidBaseURL
    case invalidAuthURL
    case audioConversionFailed
    case audioConversionError(String)
    case apiError(code: Int, message: String)

    public var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid iFlytek credentials. Expected format: AppID:APIKey:APISecret"
        case .invalidBaseURL:
            return "Invalid iFlytek base URL"
        case .invalidAuthURL:
            return "Failed to build authenticated URL"
        case .audioConversionFailed:
            return "Failed to convert audio to PCM 16kHz format"
        case .audioConversionError(let msg):
            return "Audio conversion error: \(msg)"
        case .apiError(let code, let message):
            return "iFlytek API error (\(code)): \(message)"
        }
    }
}
