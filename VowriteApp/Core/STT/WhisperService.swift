import Foundation

final class WhisperService {
    func transcribe(audioURL: URL, apiKey: String) async throws -> String {
        let baseURL = APIConfig.baseURL
        let model = APIConfig.sttModel
        let endpoint = "\(baseURL)/audio/transcriptions"

        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        // OpenRouter requires HTTP-Referer
        if APIConfig.provider == .openrouter {
            request.setValue("https://vowrite.com", forHTTPHeaderField: "HTTP-Referer")
            request.setValue("Vowrite", forHTTPHeaderField: "X-Title")
        }

        let audioData = try Data(contentsOf: audioURL)
        var body = Data()

        // model field
        body.appendMultipart(boundary: boundary, name: "model", value: model)

        // response_format
        body.appendMultipart(boundary: boundary, name: "response_format", value: "text")

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
    mutating func appendMultipart(boundary: String, name: String, value: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }
}

enum VowriteError: LocalizedError {
    case networkError(String)
    case apiError(String)
    case recordingError(String)

    var errorDescription: String? {
        switch self {
        case .networkError(let msg): return msg
        case .apiError(let msg): return msg
        case .recordingError(let msg): return msg
        }
    }
}
