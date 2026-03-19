import Foundation

// MARK: - Model Manager

@MainActor
public final class ModelManager: ObservableObject {
    public static let shared = ModelManager()

    @Published public var availableModels: [OpenRouterModel] = []
    @Published public var isLoading: Bool = false
    @Published public var error: String? = nil

    private init() {}

    public func refreshModels() async {
        let usesOpenRouter = APIConfig.stt.provider == .openrouter || APIConfig.polish.provider == .openrouter
        guard usesOpenRouter else { return }
        guard let apiKey = KeyVault.key(for: .openrouter), !apiKey.isEmpty else {
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

    public var sttModels: [OpenRouterModel] {
        availableModels.filter { model in
            Self.sttKeywords.contains(where: { model.id.localizedCaseInsensitiveContains($0) })
        }
    }

    public var polishModels: [OpenRouterModel] {
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

    public func isRecommendedPolishModel(_ model: OpenRouterModel) -> Bool {
        Self.recommendedPolishKeywords.contains(where: { model.id.localizedCaseInsensitiveContains($0) })
    }

    public func isRecommendedSTTModel(_ model: OpenRouterModel) -> Bool {
        model.id.localizedCaseInsensitiveContains("whisper")
    }
}
