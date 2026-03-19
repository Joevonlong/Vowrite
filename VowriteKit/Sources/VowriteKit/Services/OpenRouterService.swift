import Foundation

// MARK: - OpenRouter Models

public struct OpenRouterModel: Codable, Identifiable {
    public let id: String
    public let name: String
    public let description: String?
    public let pricing: OpenRouterPricing?

    enum CodingKeys: String, CodingKey {
        case id, name, description, pricing
    }
}

public struct OpenRouterPricing: Codable {
    public let prompt: String
    public let completion: String
}

// MARK: - OpenRouter Service

public enum OpenRouterService {
    private struct ModelsResponse: Codable {
        let data: [OpenRouterModel]
    }

    public static func fetchModels(apiKey: String) async throws -> [OpenRouterModel] {
        guard let url = URL(string: "https://openrouter.ai/api/v1/models") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("https://vowrite.app", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("Vowrite", forHTTPHeaderField: "X-Title")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw URLError(.badServerResponse, userInfo: [
                NSLocalizedDescriptionKey: "OpenRouter API returned status \(statusCode)"
            ])
        }

        let decoded = try JSONDecoder().decode(ModelsResponse.self, from: data)
        return decoded.data
    }
}
