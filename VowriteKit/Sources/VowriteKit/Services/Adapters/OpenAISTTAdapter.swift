import Foundation

/// STT adapter for OpenAI-compatible `/audio/transcriptions` endpoints.
/// Covers: OpenAI, Groq, SiliconFlow, Together, Ollama, Custom.
struct OpenAISTTAdapter: STTAdapter {

    func transcribe(
        audioURL: URL,
        model: String,
        language: String?,
        prompt: String?,
        apiKey: String?,
        baseURL: String,
        provider: APIProvider
    ) async throws -> String {
        let endpoint = "\(baseURL)/audio/transcriptions"

        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        if let apiKey = apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 180
        provider.applyHeaders(to: &request)

        let audioData = try Data(contentsOf: audioURL)

        let fileSizeMB = Double(audioData.count) / (1024 * 1024)
        if fileSizeMB > 25 {
            throw VowriteError.apiError("录音文件过大（\(String(format: "%.1f", fileSizeMB))MB），Whisper 限制 25MB。请缩短录音时间。")
        }

        var body = Data()
        body.appendMultipart(boundary: boundary, name: "model", value: model)
        body.appendMultipart(boundary: boundary, name: "response_format", value: "text")

        if let language = language, !language.isEmpty {
            body.appendMultipart(boundary: boundary, name: "language", value: language)
        }
        if let prompt = prompt, !prompt.isEmpty {
            body.appendMultipart(boundary: boundary, name: "prompt", value: prompt)
        }

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
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

        try? FileManager.default.removeItem(at: audioURL)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
