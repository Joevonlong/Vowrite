import Foundation

public final class AIPolishService {
    public init() {}

    public func polish(text: String, modeConfig: ModeConfig? = nil) async throws -> String {
        let configuration = APIConfig.polish
        let baseURL = configuration.resolvedBaseURL
        let provider = configuration.provider
        let config = modeConfig ?? ModeManager.currentModeConfig

        // Use mode-specific polish model or fall back to effective config
        let model = config.polishModel ?? configuration.model
        let endpoint = "\(baseURL)/chat/completions"

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        if let apiKey = configuration.key {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Longer timeout for large text (more tokens = longer generation)
        request.timeoutInterval = 120

        // Provider-specific headers (e.g. OpenRouter requires HTTP-Referer)
        provider.applyHeaders(to: &request)

        // Build system prompt: base + output style + mode-specific override or scene fallback
        var systemPrompt = PromptConfig.effectiveSystemPrompt

        // Output style template (applied before mode prompt so mode can override/supplement)
        if let stylePrompt = OutputStyleManager.templatePrompt(for: config.outputStyleId) {
            systemPrompt += "\n\n---\nOutput style:\n\(stylePrompt)"
        }

        if !config.systemPrompt.isEmpty {
            systemPrompt += "\n\n---\nOutput formatting for current mode (\(config.modeName)):\n\(config.systemPrompt)"
        }

        // Mode-specific user prompt
        if !config.userPrompt.isEmpty {
            systemPrompt += "\n\n---\nAdditional user preferences for this mode:\n\(config.userPrompt)"
        }

        // Wrap transcript in delimiters so the model treats it as data, not conversation
        let wrappedText = """
        Clean up the following speech transcript. Output ONLY the cleaned text, nothing else.

        --- TRANSCRIPT START ---
        \(text)
        --- TRANSCRIPT END ---
        """

        let payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": wrappedText]
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
