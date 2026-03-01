import Foundation

// MARK: - Model Manager

@MainActor
final class ModelManager: ObservableObject {
    static let shared = ModelManager()

    @Published var availableModels: [OpenRouterModel] = []
    @Published var isLoading: Bool = false
    @Published var error: String? = nil

    private init() {}

    func refreshModels() async {
        guard APIConfig.provider == .openrouter else { return }
        guard let apiKey = KeychainHelper.getAPIKey(), !apiKey.isEmpty else {
            error = "API key required to fetch models"
            return
        }

        isLoading = true
        error = nil

        do {
            availableModels = try await OpenRouterService.fetchModels(apiKey: apiKey)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Filtered Model Lists

    private static let sttKeywords = ["whisper"]
    private static let excludeKeywords = ["whisper", "image", "embedding", "vision", "dall-e", "stable-diffusion", "midjourney"]
    private static let recommendedPolishKeywords = ["glm", "kimi", "qwen"]

    var sttModels: [OpenRouterModel] {
        availableModels.filter { model in
            Self.sttKeywords.contains(where: { model.id.localizedCaseInsensitiveContains($0) })
        }
    }

    var polishModels: [OpenRouterModel] {
        let filtered = availableModels.filter { model in
            !Self.excludeKeywords.contains(where: { model.id.localizedCaseInsensitiveContains($0) })
        }
        // Sort recommended models first
        return filtered.sorted { a, b in
            let aRecommended = isRecommendedPolishModel(a)
            let bRecommended = isRecommendedPolishModel(b)
            if aRecommended != bRecommended { return aRecommended }
            return a.name < b.name
        }
    }

    func isRecommendedPolishModel(_ model: OpenRouterModel) -> Bool {
        Self.recommendedPolishKeywords.contains(where: { model.id.localizedCaseInsensitiveContains($0) })
    }

    func isRecommendedSTTModel(_ model: OpenRouterModel) -> Bool {
        model.id.localizedCaseInsensitiveContains("whisper")
    }
}
