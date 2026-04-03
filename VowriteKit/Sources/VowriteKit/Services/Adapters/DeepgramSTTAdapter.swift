import Foundation

/// STT adapter for Deepgram's `/listen` endpoint.
/// Uses Token auth (not Bearer) and raw binary body (not multipart).
struct DeepgramSTTAdapter: STTAdapter {

    func transcribe(
        audioURL: URL,
        model: String,
        language: String?,
        prompt: String?,
        apiKey: String?,
        baseURL: String,
        provider: APIProvider
    ) async throws -> String {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw VowriteError.apiError("Deepgram API key is required for STT.")
        }

        var components = URLComponents(string: "\(baseURL)/listen")!
        var queryItems = [
            URLQueryItem(name: "model", value: model),
            URLQueryItem(name: "smart_format", value: "true"),
        ]
        if let language = language, !language.isEmpty {
            queryItems.append(URLQueryItem(name: "language", value: language))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw VowriteError.apiError("Invalid Deepgram URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("audio/mp4", forHTTPHeaderField: "Content-Type")
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60

        let audioData = try Data(contentsOf: audioURL)
        request.httpBody = audioData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VowriteError.networkError("Invalid response")
        }
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            if httpResponse.statusCode == 401 {
                throw VowriteError.apiError("Deepgram: 401 Unauthorized — check your API key")
            }
            throw VowriteError.apiError("Deepgram STT error (\(httpResponse.statusCode)): \(errorBody)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [String: Any],
              let channels = results["channels"] as? [[String: Any]],
              let firstChannel = channels.first,
              let alternatives = firstChannel["alternatives"] as? [[String: Any]],
              let firstAlt = alternatives.first,
              let transcript = firstAlt["transcript"] as? String
        else {
            throw VowriteError.apiError("Failed to parse Deepgram response")
        }

        try? FileManager.default.removeItem(at: audioURL)
        return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
