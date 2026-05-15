import Foundation

public enum APIConnectionTester {
    public static func testChatCompletion(
        configuration: APIEndpointConfiguration,
        apiKeyOverride: String? = nil
    ) async throws {
        let apiKey = apiKeyOverride?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? configuration.key

        // Claude uses its own Messages API
        if configuration.provider == .claude {
            try await testClaudeConnection(configuration: configuration, apiKey: apiKey)
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

        let payload: [String: Any] = [
            "model": configuration.model,
            "messages": [["role": "user", "content": "Say hi"]],
            "max_tokens": 5
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VowriteError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            if httpResponse.statusCode == 401 {
                let keyStatus = apiKey != nil ? "key present" : "NO KEY FOUND"
                throw VowriteError.apiError("\(configuration.provider.rawValue): 401 Unauthorized [\(keyStatus)]")
            }
            throw VowriteError.apiError("Error \(httpResponse.statusCode): \(body)")
        }
    }

    // MARK: - Claude Connection Test

    private static func testClaudeConnection(
        configuration: APIEndpointConfiguration,
        apiKey: String?
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

        let payload: [String: Any] = [
            "model": configuration.model,
            "max_tokens": 5,
            "messages": [["role": "user", "content": "Say hi"]]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VowriteError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            if httpResponse.statusCode == 401 {
                let keyStatus = apiKey != nil ? "key present" : "NO KEY FOUND"
                throw VowriteError.apiError("Claude (Anthropic): 401 Unauthorized [\(keyStatus)]")
            }
            throw VowriteError.apiError("Error \(httpResponse.statusCode): \(body)")
        }
    }

    // MARK: - STT Connection Test

    /// Validates the STT provider's API key by hitting the /models endpoint.
    /// This is lighter than sending audio and works across all OpenAI-compatible APIs.
    public static func testSTTConnection(
        configuration: APIEndpointConfiguration
    ) async throws {
        guard configuration.provider.hasSTTSupport else {
            throw VowriteError.apiError("\(configuration.provider.rawValue) doesn't support STT")
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
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            if httpResponse.statusCode == 401 {
                let keyStatus = configuration.key != nil ? "key present" : "NO KEY FOUND"
                throw VowriteError.apiError("\(configuration.provider.rawValue): 401 Unauthorized [\(keyStatus)]")
            }
            throw VowriteError.apiError("STT Error \(httpResponse.statusCode): \(body)")
        }
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
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            if httpResponse.statusCode == 401 {
                let keyStatus = configuration.key != nil ? "key present" : "NO KEY FOUND"
                throw VowriteError.apiError("Deepgram: 401 Unauthorized [\(keyStatus)]")
            }
            throw VowriteError.apiError("Deepgram STT Error \(httpResponse.statusCode): \(body)")
        }
    }

}
