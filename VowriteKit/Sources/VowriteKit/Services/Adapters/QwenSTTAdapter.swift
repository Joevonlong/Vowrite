import Foundation
import AVFoundation

/// STT adapter for Qwen (通义千问) ASR models via DashScope API.
/// Supports only Qwen3-ASR-Flash's synchronous multimodal file path. Realtime
/// and async task models require a different contract and fail before upload.
struct QwenSTTAdapter: STTAdapter {

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
        // V-021: always clean up the recording temp file, even on failure.
        defer { try? FileManager.default.removeItem(at: audioURL) }

        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw VowriteError.apiError("Qwen API key is required for STT.")
        }

        guard model == "qwen3-asr-flash" else {
            throw VowriteError.apiError(
                "Qwen STT model '\(model)' is unavailable in Vowrite's synchronous file path. Use qwen3-asr-flash."
            )
        }

        let audioData = try Data(contentsOf: audioURL)
        guard audioData.count <= 10 * 1024 * 1024 else {
            throw VowriteError.apiError("Qwen ASR supports files up to 10 MB in the synchronous path.")
        }
        guard let audioFile = try? AVAudioFile(forReading: audioURL), audioFile.fileFormat.sampleRate > 0 else {
            throw VowriteError.apiError("Qwen ASR requires a readable audio file.")
        }
        let duration = Double(audioFile.length) / audioFile.fileFormat.sampleRate
        guard duration <= 5 * 60 else {
            throw VowriteError.apiError("Qwen ASR supports recordings up to 5 minutes in the synchronous path.")
        }
        let base64Audio = audioData.base64EncodedString()
        let mimeType = audioURL.pathExtension.lowercased() == "wav" ? "audio/wav" : "audio/m4a"
        return try await transcribeSync(base64Audio: base64Audio, mimeType: mimeType, model: model, language: language, apiKey: apiKey, baseURL: baseURL)
    }

    // MARK: - Sync mode (Qwen3-ASR-Flash via chat/completions variant)

    private func transcribeSync(
        base64Audio: String,
        mimeType: String,
        model: String,
        language: String?,
        apiKey: String,
        baseURL: String
    ) async throws -> String {
        // DashScope multimodal generation endpoint
        let endpoint = baseURL.replacingOccurrences(of: "/compatible-mode/v1", with: "/api/v1/services/aigc/multimodal-generation/generation")
        var request = URLRequest(url: try URL.validated(endpoint, label: "Qwen ASR endpoint"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 180

        let payload: [String: Any] = [
            "model": model,
            "input": [
                "messages": [
                    [
                        "role": "user",
                        "content": [
                            ["audio": "data:\(mimeType);base64,\(base64Audio)"]
                        ]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VowriteError.networkError("Invalid response from Qwen ASR API")
        }
        guard httpResponse.statusCode == 200 else {
            throw ProviderHTTPErrorPolicy.publicError(
                context: .qwenASRRequest,
                response: httpResponse,
                discardingResponseBody: data
            )
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let output = json["output"] as? [String: Any],
              let choices = output["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? [[String: Any]],
              let textEntry = content.first(where: { $0["text"] != nil }),
              let text = textEntry["text"] as? String else {
            throw VowriteError.apiError("Qwen ASR: failed to parse transcription from response")
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

}
