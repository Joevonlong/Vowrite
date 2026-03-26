import Foundation

/// STT adapter for Volcengine Seed-ASR 2.0 (字节跳动).
/// Uses async submit→poll pattern via proprietary REST API.
struct VolcengineSTTAdapter: STTAdapter {

    private let submitURL = "https://openspeech.bytedance.com/api/v3/auc/bigmodel/submit"
    private let queryURL = "https://openspeech.bytedance.com/api/v3/auc/bigmodel/query"
    private let pollInterval: TimeInterval = 1.5
    private let maxPollTime: TimeInterval = 300 // 5 minutes

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
            throw VowriteError.apiError("Volcengine API key is required for STT.")
        }

        // Read audio and encode as base64
        let audioData = try Data(contentsOf: audioURL)
        let base64Audio = audioData.base64EncodedString()

        // Step 1: Submit transcription task
        let taskId = try await submitTask(base64Audio: base64Audio, language: language, apiKey: apiKey)

        // Step 2: Poll for result
        let result = try await pollResult(taskId: taskId, apiKey: apiKey)

        // Cleanup
        try? FileManager.default.removeItem(at: audioURL)

        return result
    }

    private func submitTask(base64Audio: String, language: String?, apiKey: String) async throws -> String {
        var request = URLRequest(url: URL(string: submitURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        var payload: [String: Any] = [
            "audio": ["data": base64Audio, "format": "m4a"],
        ]
        if let language = language, !language.isEmpty {
            payload["language"] = language
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw VowriteError.apiError("Volcengine STT submit failed: \(body)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let taskId = json["id"] as? String ?? (json["resp"] as? [String: Any])?["id"] as? String else {
            throw VowriteError.apiError("Volcengine STT: no task ID in response")
        }

        return taskId
    }

    private func pollResult(taskId: String, apiKey: String) async throws -> String {
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < maxPollTime {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))

            var request = URLRequest(url: URL(string: queryURL)!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 15

            let payload: [String: Any] = ["id": taskId]
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)

            let (data, _) = try await URLSession.shared.data(for: request)

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            let status = json["code"] as? Int ?? (json["resp"] as? [String: Any])?["code"] as? Int ?? -1

            if status == 0 || (json["text"] as? String) != nil {
                // Success
                if let text = json["text"] as? String {
                    return text.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if let resp = json["resp"] as? [String: Any], let text = resp["text"] as? String {
                    return text.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                throw VowriteError.apiError("Volcengine STT: task completed but no text in response")
            }

            // Check for permanent failure
            if status > 0 && status != 1 { // 1 = still processing
                let msg = json["message"] as? String ?? "Unknown error (code: \(status))"
                throw VowriteError.apiError("Volcengine STT error: \(msg)")
            }
        }

        throw VowriteError.apiError("Volcengine STT: transcription timed out after \(Int(maxPollTime))s")
    }
}
