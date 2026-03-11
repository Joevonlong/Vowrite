import Foundation

final class AIPolishService {
    func polish(text: String, apiKey: String, modeConfig: ModeConfig? = nil) async throws -> String {
        // F-019: Use dual API config for Polish pipeline
        let effectiveKey = DualAPIConfig.effectivePolishAPIKey ?? apiKey
        let baseURL = DualAPIConfig.effectivePolishBaseURL
        let provider = DualAPIConfig.effectivePolishProvider
        let config = modeConfig ?? ModeManager.currentModeConfig

        // Use mode-specific polish model or fall back to effective config
        let model = config.polishModel ?? DualAPIConfig.effectivePolishModel
        let endpoint = "\(baseURL)/chat/completions"

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(effectiveKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Longer timeout for large text (more tokens = longer generation)
        request.timeoutInterval = 120

        // OpenRouter requires these headers
        if provider == .openrouter {
            request.setValue("https://vowrite.com", forHTTPHeaderField: "HTTP-Referer")
            request.setValue("Vowrite", forHTTPHeaderField: "X-Title")
        }

        // Build system prompt: base + mode-specific override or scene fallback
        var systemPrompt = PromptConfig.effectiveSystemPrompt

        if !config.systemPrompt.isEmpty {
            systemPrompt += "\n\n---\nOutput formatting for current mode (\(config.modeName)):\n\(config.systemPrompt)"
        } else {
            // Backward compat: check SceneManager if mode has no custom prompt
            let scenePrompt = SceneManager.currentScenePrompt
            if !scenePrompt.isEmpty {
                systemPrompt += "\n\n---\nOutput formatting for current scene:\n\(scenePrompt)"
            }
        }

        // Mode-specific user prompt
        if !config.userPrompt.isEmpty {
            systemPrompt += "\n\n---\nAdditional user preferences for this mode:\n\(config.userPrompt)"
        }

        // Language preservation is already enforced in the system prompt.
        // Do NOT add extra language rules here — they can conflict with
        // the "preserve every word in its original language" directive.

        let payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "temperature": config.temperature,
            "max_tokens": 4096
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
            throw VowriteError.apiError("Polish API error: \(errorBody)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw VowriteError.apiError("Failed to parse polish response")
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
