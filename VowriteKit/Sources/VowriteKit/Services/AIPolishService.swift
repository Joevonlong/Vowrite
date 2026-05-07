import Foundation

public final class AIPolishService {
    private let claudeService = ClaudePolishService()

    public init() {}

    public func polish(text: String, modeConfig: ModeConfig? = nil, promptContext: PromptContext? = nil) async throws -> String {
        let configuration = APIConfig.polish
        let baseURL = configuration.resolvedBaseURL
        let provider = configuration.provider
        let config = modeConfig ?? ModeManager.currentModeConfig

        // Use mode-specific polish model or fall back to effective config.
        // OAuth-active providers may rewrite the requested model server-side
        // (e.g. Kimi Code Coding Plan → `kimi-for-coding`), so when no mode
        // override is set, prefer the OAuth-resolved model alias.
        let model = config.polishModel ?? configuration.resolvedModel

        // F-063: branch translation vs polish via shared helper for consistency.
        var systemPrompt = SpeculativePolish.buildSystemPrompt(for: config)

        // F-045: Expand context variables. Translation mode skips expansion —
        // its prompt has no placeholders and PromptContext (clipboard/selected)
        // must NOT leak into translation content.
        if !config.isTranslation, let ctx = promptContext {
            systemPrompt = ctx.expandAll(systemPrompt, text: text)
        }

        // Wrap transcript in delimiters so the model treats it as data, not conversation
        let wrappedText: String
        if config.isTranslation {
            wrappedText = """
            Translate the following transcript. Output ONLY the translation, nothing else.

            --- TRANSCRIPT START ---
            \(text)
            --- TRANSCRIPT END ---
            """
        } else {
            wrappedText = """
            Clean up the following speech transcript. Output ONLY the cleaned text, nothing else.

            --- TRANSCRIPT START ---
            \(text)
            --- TRANSCRIPT END ---
            """
        }

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

        // Kimi Code Coding Plan endpoint requires coding-agent UA + device headers
        if provider == .kimi,
           KeyVault.preferredAuthMethod(for: provider) == "oauth",
           KeyVault.hasValidOAuthToken(for: provider) {
            KimiCodeOAuthService.applyCodingPlanHeaders(to: &request)
        }

        // F-073: Resolve per-model polish overrides (e.g. disable thinking mode)
        // from providers.json before building the final payload.
        let resolvedOverrides = ProviderRegistry.shared.polishOverrides(
            providerID: provider.providerID,
            modelID: model
        )

        var payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": wrappedText]
            ],
            "temperature": config.temperature,
            "max_tokens": 4096
        ]
        applyPolishOverrides(to: &payload, overrides: resolvedOverrides)

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
