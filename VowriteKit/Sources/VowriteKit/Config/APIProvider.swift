import Foundation

public enum APIProvider: String, CaseIterable, Identifiable, Codable {
    case openai = "OpenAI"
    case openrouter = "OpenRouter"
    case groq = "Groq"
    case deepgram = "Deepgram"
    case together = "Together AI"
    case deepseek = "DeepSeek"
    case siliconflow = "SiliconFlow (硅基流动)"
    case kimi = "Kimi (月之暗面)"
    case minimax = "MiniMax"
    case volcengine = "Volcengine (火山引擎)"
    case qwen = "Qwen (通义千问)"
    case gemini = "Google Gemini"
    case zhipu = "Zhipu (智谱清言)"
    case claude = "Claude (Anthropic)"
    case ollama = "Ollama (Local)"
    case mlxServer = "MLX Server (Local)"
    case iflytek = "iFlytek (讯飞)"
    case sherpa = "Sherpa (Offline)"
    case custom = "Custom"

    public var id: String { rawValue }

    // MARK: - Registry Bridge

    /// Maps this enum case to the JSON provider id used in providers.json.
    public var providerID: String {
        switch self {
        case .openai: return "openai"
        case .openrouter: return "openrouter"
        case .groq: return "groq"
        case .deepgram: return "deepgram"
        case .together: return "together"
        case .deepseek: return "deepseek"
        case .siliconflow: return "siliconflow"
        case .kimi: return "kimi"
        case .minimax: return "minimax"
        case .volcengine: return "volcengine"
        case .qwen: return "qwen"
        case .gemini: return "gemini"
        case .zhipu: return "zhipu"
        case .claude: return "claude"
        case .ollama: return "ollama"
        case .mlxServer: return "mlxServer"
        case .iflytek: return "iflytek"
        case .sherpa: return "sherpa"
        case .custom: return "custom"
        }
    }

    /// The provider definition from the registry. All metadata flows through this.
    private var definition: ProviderDefinition? {
        ProviderRegistry.shared.provider(for: providerID)
    }

    // MARK: - Metadata (delegated to Registry)

    public var isOpenAICompatible: Bool {
        definition?.isOpenAICompatible ?? true
    }

    public var defaultBaseURL: String {
        definition?.baseURL ?? ""
    }

    public var defaultSTTModel: String {
        definition?.defaultSTTModel ?? ""
    }

    public var defaultPolishModel: String {
        definition?.defaultPolishModel ?? ""
    }

    public var presetSTTModels: [String] {
        definition?.presetSTTModels ?? []
    }

    public var presetPolishModels: [String] {
        definition?.presetPolishModels ?? []
    }

    public var hasSTTSupport: Bool {
        definition?.hasSTTSupport ?? false
    }

    public var sttSupportNote: String? {
        definition?.sttNote
    }

    public var keyPlaceholder: String {
        definition?.auth.keyPlaceholder ?? "API Key"
    }

    public var requiresAPIKey: Bool {
        definition?.requiresAPIKey ?? true
    }

    public var keyURL: String {
        definition?.auth.keyURL ?? ""
    }

    // MARK: - Platform Filtering

    /// Providers available on the current platform (iOS excludes local-only providers)
    public static var availableCases: [APIProvider] {
        #if os(iOS)
        return allCases.filter { $0 != .ollama && $0 != .mlxServer && $0 != .sherpa }
        #else
        return allCases
        #endif
    }

    /// Providers that support STT on the current platform
    public static var availableSTTCases: [APIProvider] {
        availableCases.filter(\.hasSTTSupport)
    }

    // MARK: - Headers

    /// Apply provider-specific HTTP headers to a request.
    public func applyHeaders(to request: inout URLRequest) {
        guard let headers = definition?.headers else { return }
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
    }

    // MARK: - Model Descriptions

    public static func sttModelDescription(_ modelID: String) -> String? {
        ProviderRegistry.shared.sttModelDescription(modelID)
    }

    public static func polishModelDescription(_ modelID: String) -> String? {
        ProviderRegistry.shared.polishModelDescription(modelID)
    }
}
