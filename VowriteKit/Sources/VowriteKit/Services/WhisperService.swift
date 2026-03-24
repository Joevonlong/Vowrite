import Foundation

public final class WhisperService {
    public init() {}

    public func transcribe(audioURL: URL, language: String? = nil, prompt: String? = nil) async throws -> String {
        let configuration = APIConfig.stt
        let baseURL = configuration.resolvedBaseURL
        let model = configuration.model
        let provider = configuration.provider
        let endpoint = "\(baseURL)/audio/transcriptions"

        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        if let apiKey = configuration.key {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        // Longer timeout for large audio files (upload + server processing)
        request.timeoutInterval = 180

        // Provider-specific headers (e.g. OpenRouter requires HTTP-Referer)
        provider.applyHeaders(to: &request)

        let audioData = try Data(contentsOf: audioURL)

        // Whisper API file size limit: 25MB
        let fileSizeMB = Double(audioData.count) / (1024 * 1024)
        if fileSizeMB > 25 {
            throw VowriteError.apiError("录音文件过大（\(String(format: "%.1f", fileSizeMB))MB），Whisper 限制 25MB。请缩短录音时间。")
        }
        var body = Data()

        // model field
        body.appendMultipart(boundary: boundary, name: "model", value: model)

        // response_format
        body.appendMultipart(boundary: boundary, name: "response_format", value: "text")

        // language (if specified, not auto-detect)
        if let language = language, !language.isEmpty {
            body.appendMultipart(boundary: boundary, name: "language", value: language)
        }

        // prompt (for vocabulary guidance)
        if let prompt = prompt, !prompt.isEmpty {
            body.appendMultipart(boundary: boundary, name: "prompt", value: prompt)
        }

        // audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VowriteError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw VowriteError.apiError("STT API error (\(httpResponse.statusCode)): \(errorBody)")
        }

        guard let text = String(data: data, encoding: .utf8) else {
            throw VowriteError.apiError("Failed to decode STT response")
        }

        // Clean up temp audio file
        try? FileManager.default.removeItem(at: audioURL)

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension Data {
    public mutating func appendMultipart(boundary: String, name: String, value: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }
}
