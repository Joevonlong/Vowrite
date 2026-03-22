import Foundation

public enum APIConnectionTester {
    public static func testChatCompletion(
        configuration: APIEndpointConfiguration,
        apiKeyOverride: String? = nil
    ) async throws {
        let endpoint = "\(configuration.resolvedBaseURL)/chat/completions"
        guard let url = URL(string: endpoint) else {
            throw VowriteError.apiError("Invalid base URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let apiKey = apiKeyOverride?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? configuration.key
        if let apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        if configuration.provider == .openrouter {
            request.setValue("https://vowrite.com", forHTTPHeaderField: "HTTP-Referer")
            request.setValue("Vowrite", forHTTPHeaderField: "X-Title")
        }

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
                let keyStatus = apiKey != nil ? "key present (\(apiKey!.prefix(4))...)" : "NO KEY FOUND"
                throw VowriteError.apiError("\(configuration.provider.rawValue): 401 Unauthorized [\(keyStatus)]")
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
}
