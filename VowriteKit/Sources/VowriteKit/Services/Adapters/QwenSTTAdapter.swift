import Foundation

/// STT adapter for Qwen (通义千问) ASR models via DashScope API.
/// Supports Qwen3-ASR-Flash (sync, chat/completions variant with audio input)
/// and Paraformer/Fun-ASR (async task submission).
struct QwenSTTAdapter: STTAdapter {

    private let pollInterval: TimeInterval = 1.5
    private let maxPollTime: TimeInterval = 300

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
            throw VowriteError.apiError("Qwen API key is required for STT.")
        }

        let audioData = try Data(contentsOf: audioURL)
        let base64Audio = audioData.base64EncodedString()

        let result: String
        if model.contains("qwen") || model.contains("asr-flash") {
            // Qwen3-ASR-Flash: sync via multimodal generation endpoint
            result = try await transcribeSync(base64Audio: base64Audio, model: model, language: language, apiKey: apiKey, baseURL: baseURL)
        } else {
            // Paraformer/Fun-ASR: async task API
            result = try await transcribeAsync(base64Audio: base64Audio, model: model, language: language, apiKey: apiKey, baseURL: baseURL)
        }

        try? FileManager.default.removeItem(at: audioURL)
        return result
    }

    // MARK: - Sync mode (Qwen3-ASR-Flash via chat/completions variant)

    private func transcribeSync(
        base64Audio: String,
        model: String,
        language: String?,
        apiKey: String,
        baseURL: String
    ) async throws -> String {
        // DashScope multimodal generation endpoint
        let endpoint = baseURL.replacingOccurrences(of: "/compatible-mode/v1", with: "/api/v1/services/aigc/multimodal-generation/generation")
        var request = URLRequest(url: URL(string: endpoint)!)
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
                            ["audio": "data:audio/m4a;base64,\(base64Audio)"]
                        ]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw VowriteError.apiError("Qwen ASR error: \(body)")
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

    // MARK: - Async mode (Paraformer/Fun-ASR via task API)

    private func transcribeAsync(
        base64Audio: String,
        model: String,
        language: String?,
        apiKey: String,
        baseURL: String
    ) async throws -> String {
        let endpoint = baseURL.replacingOccurrences(of: "/compatible-mode/v1", with: "/api/v1/services/audio/asr/transcription")
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        var input: [String: Any] = ["file_urls": ["data:audio/m4a;base64,\(base64Audio)"]]
        if let language = language, !language.isEmpty {
            input["language_hints"] = [language]
        }
        let payload: [String: Any] = [
            "model": model,
            "input": input,
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw VowriteError.apiError("Qwen ASR submit failed: \(body)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let output = json["output"] as? [String: Any],
              let taskId = output["task_id"] as? String else {
            throw VowriteError.apiError("Qwen ASR: no task_id in response")
        }

        // Poll for result
        return try await pollAsyncResult(taskId: taskId, apiKey: apiKey, baseURL: baseURL)
    }

    private func pollAsyncResult(taskId: String, apiKey: String, baseURL: String) async throws -> String {
        let statusEndpoint = baseURL.replacingOccurrences(of: "/compatible-mode/v1", with: "/api/v1/tasks/\(taskId)")
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < maxPollTime {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))

            var request = URLRequest(url: URL(string: statusEndpoint)!)
            request.httpMethod = "GET"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 15

            let (data, _) = try await URLSession.shared.data(for: request)

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let output = json["output"] as? [String: Any],
                  let status = output["task_status"] as? String else {
                continue
            }

            if status == "SUCCEEDED" {
                if let results = output["results"] as? [[String: Any]],
                   let first = results.first,
                   let text = first["text"] as? String {
                    return text.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                throw VowriteError.apiError("Qwen ASR: task succeeded but no text in results")
            }

            if status == "FAILED" {
                let msg = output["message"] as? String ?? "Unknown error"
                throw VowriteError.apiError("Qwen ASR error: \(msg)")
            }
        }

        throw VowriteError.apiError("Qwen ASR: transcription timed out after \(Int(maxPollTime))s")
    }
}
