import Foundation

public final class AIPolishService {
    private let claudeService = ClaudePolishService()

    public init() {}

    public func polish(text: String, modeConfig: ModeConfig? = nil, promptContext: PromptContext? = nil) async throws -> String {
        let configuration = APIConfig.polish
        let baseURL = configuration.resolvedBaseURL
        let provider = configuration.provider
        let config = modeConfig ?? ModeManager.currentModeConfig

        // Use mode-specific polish model or fall back to effective config
        let model = config.polishModel ?? configuration.model

        // Build system prompt: base + output style + mode-specific override or scene fallback
        var systemPrompt = PromptConfig.effectiveSystemPrompt

        // Output style template (applied before mode prompt so mode can override/supplement)
        if let stylePrompt = OutputStyleManager.templatePrompt(for: config.outputStyleId) {
            systemPrompt += "\n\n---\nOutput style:\n\(stylePrompt)"
        }

        // F-045: Expand context variables in mode prompts
        var modeSystemPrompt = config.systemPrompt
        var modeUserPrompt = config.userPrompt
        if let ctx = promptContext {
            modeSystemPrompt = ctx.expandAll(modeSystemPrompt, text: text)
            modeUserPrompt = ctx.expandAll(modeUserPrompt, text: text)
        }

        if !modeSystemPrompt.isEmpty {
            systemPrompt += "\n\n---\nOutput formatting for current mode (\(config.modeName)):\n\(modeSystemPrompt)"
        }

        // Mode-specific user prompt
        if !modeUserPrompt.isEmpty {
            systemPrompt += "\n\n---\nAdditional user preferences for this mode:\n\(modeUserPrompt)"
        }

        // F-051: Inject user vocabulary for better correction awareness
        if let vocabHint = ReplacementManager.llmVocabularyHint {
            systemPrompt += "\n\n---\nImportant vocabulary (always use these exact spellings when relevant): \(vocabHint)"
        }

        // Wrap transcript in delimiters so the model treats it as data, not conversation
        let wrappedText = """
        Clean up the following speech transcript. Output ONLY the cleaned text, nothing else.

        --- TRANSCRIPT START ---
        \(text)
        --- TRANSCRIPT END ---
        """

        // Claude uses its own Messages API
        if provider == .claude {
            guard let apiKey = configuration.key else {
                throw VowriteError.apiError("No API key configured for Claude")
            }
            let result = try await claudeService.polish(
                text: text,
                systemPrompt: systemPrompt,
                userPrompt: wrappedText,
                apiKey: apiKey,
                model: model,
                baseURL: baseURL,
                temperature: config.temperature
            )
            return result.strippingThinkTags()
        }

        // OpenAI-compatible path
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

        return content.strippingThinkTags()
    }
}

// MARK: - Think Tag Stripping

extension String {
    /// Strips `<think>...</think>` tags (used by reasoning models like DeepSeek, QwQ)
    /// from LLM output. Handles both closed and unclosed/truncated tags.
    func strippingThinkTags() -> String {
        self
            .replacingOccurrences(of: "<think>[\\s\\S]*?</think>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "<think>[\\s\\S]*$", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
