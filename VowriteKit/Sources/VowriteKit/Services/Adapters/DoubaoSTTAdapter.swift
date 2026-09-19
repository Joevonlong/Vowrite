import AVFoundation
import Foundation

/// Doubao Speech BigASR Flash adapter. This is deliberately separate from
/// Volcengine Ark: it uses the Speech console APP Key in `X-Api-Key` and the
/// synchronous recording-file protocol, not Ark's bearer-token chat API.
struct DoubaoSTTAdapter: STTAdapter {
    static let flashModel = "volc.bigasr.auc_turbo"
    private static let maximumInputBytes = 100 * 1024 * 1024
    private static let maximumDuration: TimeInterval = 2 * 60 * 60
    private static let targetBytesPerSecond = 16_000 * 2

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func transcribe(
        audioURL: URL,
        model: String,
        language: String?,
        prompt: String?,
        apiKey: String?,
        baseURL: String,
        provider: APIProvider
    ) async throws -> String {
        defer { try? FileManager.default.removeItem(at: audioURL) }

        guard model == Self.flashModel else {
            throw VowriteError.apiError("Doubao Speech supports only the synchronous BigASR Flash model.")
        }
        guard let apiKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines), !apiKey.isEmpty else {
            throw VowriteError.apiError("A Doubao Speech console APP Key is required for transcription.")
        }
        try Task.checkCancellation()

        let wavURL = try convertToWAV(audioURL)
        defer { try? FileManager.default.removeItem(at: wavURL) }
        try Task.checkCancellation()

        let wavData = try Data(contentsOf: wavURL)
        guard wavData.count <= Self.maximumInputBytes else {
            throw VowriteError.apiError("Doubao Speech audio exceeds the 100 MB limit.")
        }

        let endpoint = "\(baseURL)/recognize/flash"
        var request = URLRequest(url: try URL.validated(endpoint, label: "Doubao Speech endpoint"))
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        request.setValue(Self.flashModel, forHTTPHeaderField: "X-Api-Resource-Id")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Api-Request-Id")
        request.setValue("-1", forHTTPHeaderField: "X-Api-Sequence")

        var transcriptionRequest: [String: Any] = [
            "model_name": "bigmodel",
            "enable_itn": true,
            "enable_punc": true,
            "enable_ddc": false,
        ]
        var audio: [String: Any] = ["format": "wav", "data": wavData.base64EncodedString()]
        if let language = supportedLanguage(language) {
            audio["language"] = language
        } else {
            // Flash documents corpus support, but its corpus and automatic
            // language modes conflict. This narrow integration intentionally
            // defers corpus/hotword configuration and uses the documented
            // automatic-language option when no exact hint is available.
            transcriptionRequest["enable_auto_lang"] = true
        }
        let payload: [String: Any] = [
            "user": ["uid": UUID().uuidString],
            "audio": audio,
            "request": transcriptionRequest,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VowriteError.networkError("Invalid response from Doubao Speech.")
        }
        guard httpResponse.statusCode == 200 else {
            throw publicError(httpStatus: httpResponse.statusCode, providerStatus: nil)
        }

        let statusCode = httpResponse.value(forHTTPHeaderField: "X-Api-Status-Code")
        if statusCode == "20000003" {
            return ""
        }
        guard statusCode == "20000000" else {
            throw publicError(httpStatus: nil, providerStatus: statusCode)
        }
        guard let responseObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = responseObject["result"] as? [String: Any],
              let text = result["text"] as? String else {
            throw VowriteError.apiError("Doubao Speech returned an invalid transcription response.")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Maps only documented numeric transport/provider status to fixed prose.
    /// Response bodies and headers other than the numeric status are deliberately
    /// excluded because they can echo audio metadata or credentials.
    private func publicError(httpStatus: Int?, providerStatus: String?) -> VowriteError {
        if httpStatus == 401 || httpStatus == 403 {
            return .apiError("Doubao Speech rejected the APP Key or its service permission. Check the Speech console APP Key and access.")
        }
        if httpStatus == 429 {
            return .apiError("Doubao Speech quota or concurrency limit was reached (HTTP 429). Try again after capacity is available.")
        }
        if providerStatus == "55000031" {
            return .apiError("Doubao Speech is busy (provider code 55000031). Try again shortly.")
        }
        if let httpStatus {
            return .apiError("Doubao Speech transcription failed (HTTP \(httpStatus)).")
        }
        if let providerStatus, providerStatus.allSatisfy({ $0.isNumber }) {
            return .apiError("Doubao Speech transcription failed (provider code \(providerStatus)).")
        }
        return .apiError("Doubao Speech transcription failed.")
    }

    /// Creates the same valid, short WAV payload used by the connection probe.
    static func makeSilentProbeWAV() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("vowrite-doubao-probe-\(UUID().uuidString).wav")
        try SoundFeedback.wavData(
            samples: Array(repeating: Int16(0), count: 1_600),
            sampleRate: 16_000,
            channels: 1,
            bitsPerSample: 16
        ).write(to: url)
        return url
    }

    private func convertToWAV(_ sourceURL: URL) throws -> URL {
        let attributes = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
        guard (attributes[.size] as? NSNumber)?.intValue ?? 0 <= Self.maximumInputBytes else {
            throw VowriteError.apiError("Doubao Speech audio exceeds the 100 MB limit.")
        }
        let source = try AVAudioFile(forReading: sourceURL)
        let sourceFormat = source.processingFormat
        guard sourceFormat.sampleRate > 0 else {
            throw VowriteError.apiError("Doubao Speech requires a readable audio file.")
        }
        let duration = Double(source.length) / sourceFormat.sampleRate
        guard duration <= Self.maximumDuration else {
            throw VowriteError.apiError("Doubao Speech supports recordings up to 2 hours.")
        }
        let expectedBytes = duration * Double(Self.targetBytesPerSecond) + 44
        guard expectedBytes <= Double(Self.maximumInputBytes) else {
            throw VowriteError.apiError("Converted Doubao Speech audio exceeds the 100 MB limit.")
        }

        let target = try Self.targetFormat()
        guard let converter = AVAudioConverter(from: sourceFormat, to: target) else {
            throw VowriteError.apiError("Unable to convert audio for Doubao Speech.")
        }
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("vowrite-doubao-\(UUID().uuidString).wav")
        FileManager.default.createFile(atPath: destinationURL.path, contents: Data(repeating: 0, count: 44))
        let destination = try FileHandle(forWritingTo: destinationURL)
        var pcmByteCount = 0
        do {
            func appendPCM(_ buffer: AVAudioPCMBuffer) throws {
                let audioBuffer = buffer.audioBufferList.pointee.mBuffers
                guard let bytes = audioBuffer.mData, audioBuffer.mDataByteSize > 0 else { return }
                let data = Data(bytes: bytes, count: Int(audioBuffer.mDataByteSize))
                guard pcmByteCount + data.count <= Self.maximumInputBytes - 44 else {
                    throw VowriteError.apiError("Converted Doubao Speech audio exceeds the 100 MB limit.")
                }
                try destination.write(contentsOf: data)
                pcmByteCount += data.count
            }
            let sourceCapacity: AVAudioFrameCount = 4_096
            while source.framePosition < source.length {
                try Task.checkCancellation()
                guard let input = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: sourceCapacity) else {
                    throw VowriteError.apiError("Unable to convert audio for Doubao Speech.")
                }
                try source.read(into: input, frameCount: sourceCapacity)
                guard input.frameLength > 0 else { break }
                let outputCapacity = AVAudioFrameCount(ceil(Double(input.frameLength) * target.sampleRate / sourceFormat.sampleRate)) + 64
                guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: outputCapacity) else {
                    throw VowriteError.apiError("Unable to convert audio for Doubao Speech.")
                }
                var converterError: NSError?
                var consumed = false
                _ = converter.convert(to: output, error: &converterError) { _, status in
                    if consumed {
                        status.pointee = .noDataNow
                        return nil
                    }
                    consumed = true
                    status.pointee = .haveData
                    return input
                }
                if converterError != nil {
                    throw VowriteError.apiError("Unable to convert audio for Doubao Speech.")
                }
                if output.frameLength > 0 {
                    try appendPCM(output)
                }
            }
            // AVAudioConverter can retain a short resampling tail. Drain it
            // into bounded buffers before closing the WAV so final syllables
            // are not truncated at a chunk boundary.
            while true {
                try Task.checkCancellation()
                guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: 4_160) else {
                    throw VowriteError.apiError("Unable to convert audio for Doubao Speech.")
                }
                var converterError: NSError?
                let status = converter.convert(to: output, error: &converterError) { _, inputStatus in
                    inputStatus.pointee = .endOfStream
                    return nil
                }
                if converterError != nil {
                    throw VowriteError.apiError("Unable to convert audio for Doubao Speech.")
                }
                if output.frameLength > 0 {
                    try appendPCM(output)
                }
                if status == .endOfStream || output.frameLength == 0 {
                    break
                }
            }
            try destination.seek(toOffset: 0)
            try destination.write(contentsOf: wavHeader(pcmByteCount: pcmByteCount))
            try destination.close()
            return destinationURL
        } catch {
            try? destination.close()
            try? FileManager.default.removeItem(at: destinationURL)
            throw error
        }
    }

    private static func targetFormat() throws -> AVAudioFormat {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16_000,
            channels: 1,
            interleaved: true
        ) else {
            throw VowriteError.apiError("Unable to prepare Doubao Speech audio.")
        }
        return format
    }

    private func supportedLanguage(_ language: String?) -> String? {
        guard let language else { return nil }
        let normalized = language.replacingOccurrences(of: "_", with: "-").lowercased()
        let supported = [
            "zh-cn", "en-us", "ja-jp", "id-id", "es-mx", "pt-br", "de-de",
            "fr-fr", "ko-kr", "fil-ph", "ms-my", "th-th", "ar-sa", "it-it",
            "bn-bd", "el-gr", "nl-nl", "ru-ru", "tr-tr", "vi-vn", "pl-pl",
            "ro-ro", "ne-np", "uk-ua", "yue-cn",
        ]
        return supported.first { $0 == normalized }.map { value in
            let pieces = value.split(separator: "-", maxSplits: 1)
            return "\(pieces[0])-\(pieces[1].uppercased())"
        }
    }

    private func wavHeader(pcmByteCount: Int) -> Data {
        let dataSize = UInt32(pcmByteCount)
        var data = Data()
        data.append("RIFF".data(using: .ascii)!)
        data.appendLittleEndian(UInt32(36) + dataSize)
        data.append("WAVEfmt ".data(using: .ascii)!)
        data.appendLittleEndian(UInt32(16))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt32(16_000))
        data.appendLittleEndian(UInt32(32_000))
        data.appendLittleEndian(UInt16(2))
        data.appendLittleEndian(UInt16(16))
        data.append("data".data(using: .ascii)!)
        data.appendLittleEndian(dataSize)
        return data
    }
}

private extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var value = value.littleEndian
        Swift.withUnsafeBytes(of: &value) { append(contentsOf: $0) }
    }
}
