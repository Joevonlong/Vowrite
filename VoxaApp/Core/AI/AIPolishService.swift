import Foundation

final class AIPolishService {
    private let systemPrompt = """
    You are a voice dictation assistant. Your job is to clean up raw speech transcripts into polished, well-written text.

    Rules:
    1. Remove filler words (um, uh, like, you know, 嗯, 啊, 那个, 就是说, 然后)
    2. When the speaker corrects themselves ("no wait, I mean..." or "不对，应该是..."), keep ONLY the final corrected version
    3. Remove unnecessary repetitions
    4. Add proper punctuation and paragraph breaks
    5. Fix obvious grammar issues
    6. Preserve the speaker's original meaning and intent exactly
    7. Do NOT add information that wasn't spoken
    8. Do NOT change the language — if they spoke Chinese, output Chinese; if mixed, keep mixed
    9. Keep the tone natural, not overly formal
    10. Output ONLY the cleaned text, no explanations or commentary
    """

    func polish(text: String, apiKey: String) async throws -> String {
        let baseURL = APIConfig.baseURL
        let model = APIConfig.polishModel
        let endpoint = "\(baseURL)/chat/completions"

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        // OpenRouter requires these headers
        if APIConfig.provider == .openrouter {
            request.setValue("https://voxa.app", forHTTPHeaderField: "HTTP-Referer")
            request.setValue("Voxa", forHTTPHeaderField: "X-Title")
        }

        let payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.3,
            "max_tokens": 4096
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
            throw VoxaError.apiError("Polish API error: \(errorBody)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw VoxaError.apiError("Failed to parse polish response")
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
