import Foundation

public enum APIConnectionTester {
    public static func testChatCompletion(
        configuration: APIEndpointConfiguration,
        apiKeyOverride: String? = nil
    ) async throws {
        let apiKey = apiKeyOverride?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? configuration.key
        let payload = chatCompletionProbePayload(configuration: configuration)

        // Claude uses its own Messages API
        if configuration.provider == .claude {
            try await testClaudeConnection(configuration: configuration, apiKey: apiKey, payload: payload)
            return
        }

        let endpoint = "\(configuration.resolvedBaseURL)/chat/completions"
        guard let url = URL(string: endpoint) else {
            throw VowriteError.apiError("Invalid base URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        if let apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        // Provider-specific headers (e.g. OpenRouter requires HTTP-Referer)
        configuration.provider.applyHeaders(to: &request)

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VowriteError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            throw ProviderHTTPErrorPolicy.publicError(
                context: .connectionTest,
                response: httpResponse,
                discardingResponseBody: data
            )
        }
    }

    // MARK: - Claude Connection Test

    private static func testClaudeConnection(
        configuration: APIEndpointConfiguration,
        apiKey: String?,
        payload: [String: Any]
    ) async throws {
        let endpoint = "\(configuration.resolvedBaseURL)/messages"
        guard let url = URL(string: endpoint) else {
            throw VowriteError.apiError("Invalid Claude base URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 15

        if let apiKey {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VowriteError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            throw ProviderHTTPErrorPolicy.publicError(
                context: .claudeConnectionTest,
                response: httpResponse,
                discardingResponseBody: data
            )
        }
    }

    /// Pure probe payload construction used by both OpenAI-compatible and
    /// Claude-native connection tests. Probe requests obey the same model
    /// safety and per-model override rules as production dictation requests.
    static func chatCompletionProbePayload(
        configuration: APIEndpointConfiguration
    ) -> [String: Any] {
        let provider = configuration.provider
        let model = ProviderModelSafetyRules.safeModel(
            providerID: provider.providerID,
            capability: .polish,
            storedModel: configuration.resolvedModel
        )
        let overrides = ProviderRegistry.shared.polishOverrides(
            providerID: provider.providerID,
            modelID: model
        )
        var payload: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": "Say hi"]],
            "max_tokens": 5
        ]
        applyPolishOverrides(to: &payload, overrides: overrides)
        return payload
    }

    // MARK: - STT Connection Test

    /// Validates an STT provider key. OpenAI-compatible providers use `/models`;
    /// providers with non-OpenAI contracts use their own safe probe instead.
    public static func testSTTConnection(
        configuration: APIEndpointConfiguration,
        apiKeyOverride: String? = nil,
        session: URLSession = .shared
    ) async throws {
        guard configuration.provider.hasSTTSupport else {
            throw VowriteError.apiError("\(configuration.provider.rawValue) doesn't support STT")
        }

        if configuration.provider == .doubaoSpeech {
            try await testDoubaoSpeechConnection(
                configuration: configuration,
                apiKeyOverride: apiKeyOverride,
                session: session
            )
            return
        }

        if configuration.provider == .deepgram {
            try await testDeepgramConnection(configuration: configuration)
            return
        }

        let endpoint = "\(configuration.resolvedBaseURL)/models"
        guard let url = URL(string: endpoint) else {
            throw VowriteError.apiError("Invalid base URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15

        if let apiKey = configuration.key {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VowriteError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            throw ProviderHTTPErrorPolicy.publicError(
                context: .sttConnectionTest,
                response: httpResponse,
                discardingResponseBody: data
            )
        }
    }

    /// Doubao Speech does not expose an OpenAI `/models` endpoint. Test the
    /// configured key against the same Flash adapter used for dictation, using
    /// a generated all-zero WAV so no recorded audio is ever uploaded.
    private static func testDoubaoSpeechConnection(
        configuration: APIEndpointConfiguration,
        apiKeyOverride: String?,
        session: URLSession
    ) async throws {
        let override = apiKeyOverride?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let apiKey = override ?? configuration.key
        guard let apiKey else {
            throw VowriteError.apiError("A Doubao Speech console API Key is required for the connection test.")
        }

        let probeURL = try DoubaoSTTAdapter.makeSilentProbeWAV()
        defer { try? FileManager.default.removeItem(at: probeURL) }
        _ = try await DoubaoSTTAdapter(session: session).transcribe(
            audioURL: probeURL,
            model: configuration.model,
            language: nil,
            prompt: nil,
            apiKey: apiKey,
            baseURL: APIEndpointConfiguration.normalizeBaseURL(configuration.baseURL, provider: .doubaoSpeech),
            provider: .doubaoSpeech
        )
    }

    // MARK: - Deepgram Connection Test

    /// Deepgram has no /models endpoint; validate via GET /projects with Token auth.
    private static func testDeepgramConnection(
        configuration: APIEndpointConfiguration
    ) async throws {
        let endpoint = "\(configuration.resolvedBaseURL)/projects"
        guard let url = URL(string: endpoint) else {
            throw VowriteError.apiError("Invalid Deepgram base URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15

        if let apiKey = configuration.key {
            request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VowriteError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            throw ProviderHTTPErrorPolicy.publicError(
                context: .deepgramConnectionTest,
                response: httpResponse,
                discardingResponseBody: data
            )
        }
    }

}
