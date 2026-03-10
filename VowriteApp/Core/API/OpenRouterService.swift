import Foundation

// MARK: - OpenRouter Models

struct OpenRouterModel: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let pricing: OpenRouterPricing?

    enum CodingKeys: String, CodingKey {
        case id, name, description, pricing
    }
}

struct OpenRouterPricing: Codable {
    let prompt: String
    let completion: String
}

// MARK: - OpenRouter Service

enum OpenRouterService {
    private struct ModelsResponse: Codable {
        let data: [OpenRouterModel]
    }

    static func fetchModels(apiKey: String) async throws -> [OpenRouterModel] {
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
