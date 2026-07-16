import Foundation

/// Claude (Anthropic) Messages API client for text polishing.
/// Claude uses its own API format — not OpenAI-compatible.
public actor ClaudePolishService {

    public init() {}

    public func polish(
        text: String,
        systemPrompt: String,
        userPrompt: String,
        apiKey: String,
        model: String,
        baseURL: String,
        temperature: Double,
        overrides: [String: JSONValue]? = nil
    ) async throws -> String {
        let endpoint = "\(baseURL)/messages"
        guard let url = URL(string: endpoint) else {
            throw VowriteError.apiError("Invalid Claude base URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        // F-082: per-model overrides from providers.json apply to the native
        // Messages payload too. Claude 5-era models need them: Sonnet 5 wants
        // {"thinking": {"type": "disabled"}} for low-latency polish, and
        // Sonnet 5 / Opus 4.7+ reject non-default `temperature` with HTTP 400,
        // handled by declaring {"temperature": null} (null = omit the key).
        var payload: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userPrompt]
            ],
            "temperature": temperature,
            "stream": true
        ]
        applyPolishOverrides(to: &payload, overrides: overrides)

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VowriteError.networkError("Invalid response from Claude API")
        }

        guard httpResponse.statusCode == 200 else {
            var errorBody = ""
            for try await line in bytes.lines { errorBody += line }
            throw VowriteError.apiError("Claude API error \(httpResponse.statusCode): \(errorBody)")
        }

        var result = ""
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonString = String(line.dropFirst(6))
            guard let data = jsonString.data(using: .utf8),
                  let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = event["type"] as? String else { continue }

            if type == "content_block_delta",
               let delta = event["delta"] as? [String: Any],
               let text = delta["text"] as? String {
                result += text
            } else if type == "message_stop" {
                break
            }
        }

        guard !result.isEmpty else {
            throw VowriteError.apiError("Empty response from Claude API")
        }

        return result
    }
}
