import Foundation

public enum APIProvider: String, CaseIterable, Identifiable, Codable {
    case openai = "OpenAI"
    case openrouter = "OpenRouter"
    case groq = "Groq"
    case together = "Together AI"
    case deepseek = "DeepSeek"
    case siliconflow = "SiliconFlow (硅基流动)"
    case kimi = "Kimi (月之暗面)"
    case minimax = "MiniMax"
    case ollama = "Ollama (Local)"
    case custom = "Custom"

    public var id: String { rawValue }

    /// Whether this provider uses standard OpenAI-compatible API format.
    /// When a non-OpenAI provider is needed (e.g. 讯飞 WebSocket), this becomes
    /// the branching point for introducing Protocol abstraction.
    public var isOpenAICompatible: Bool { true }

    public var defaultBaseURL: String {
        switch self {
        case .openai: return "https://api.openai.com/v1"
        case .openrouter: return "https://openrouter.ai/api/v1"
        case .groq: return "https://api.groq.com/openai/v1"
        case .together: return "https://api.together.xyz/v1"
        case .deepseek: return "https://api.deepseek.com/v1"
        case .siliconflow: return "https://api.siliconflow.cn/v1"
        case .kimi: return "https://api.moonshot.cn/v1"
        case .minimax: return "https://api.minimax.chat/v1"
        case .ollama: return "http://localhost:11434/v1"
        case .custom: return ""
        }
    }

    public var defaultSTTModel: String {
        switch self {
        case .openai: return "gpt-4o-mini-transcribe"
        case .openrouter: return "openai/whisper-large-v3"
        case .groq: return "whisper-large-v3-turbo"
        case .together: return "whisper-large-v3"
        case .deepseek: return "whisper-1"
        case .siliconflow: return "FunAudioLLM/SenseVoiceSmall"
        case .kimi: return ""
        case .minimax: return ""
        case .ollama: return "whisper-large-v3-turbo"
        case .custom: return "whisper-1"
        }
    }

    public var defaultPolishModel: String {
        switch self {
        case .openai: return "gpt-4o-mini"
        case .openrouter: return "openai/gpt-4o-mini"
        case .groq: return "llama-3.3-70b-versatile"
        case .together: return "meta-llama/Llama-3.1-8B-Instruct-Turbo"
        case .deepseek: return "deepseek-chat"
        case .siliconflow: return "Qwen/Qwen2.5-72B-Instruct"
        case .kimi: return "kimi-k2.5"
        case .minimax: return "MiniMax-Text-02"
        case .ollama: return "qwen3:8b"
        case .custom: return "gpt-4o-mini"
        }
    }

    public var presetSTTModels: [String] {
        switch self {
        case .openai: return ["gpt-4o-mini-transcribe", "gpt-4o-transcribe", "whisper-1"]
        case .openrouter: return []
        case .groq: return ["whisper-large-v3-turbo", "whisper-large-v3"]
        case .together: return ["whisper-large-v3"]
        case .deepseek: return []
        case .siliconflow: return ["FunAudioLLM/SenseVoiceSmall", "TeleAI/TeleSpeechASR"]
        case .kimi: return []
        case .minimax: return []
        case .ollama: return ["whisper-large-v3-turbo", "whisper-large-v3", "whisper-base"]
        case .custom: return []
        }
    }

    public var presetPolishModels: [String] {
        switch self {
        case .openai: return ["gpt-4o-mini", "gpt-4o"]
        case .openrouter: return []
        case .groq: return ["llama-3.3-70b-versatile", "llama-3.1-8b-instant", "qwen-qwq-32b"]
        case .together: return ["meta-llama/Llama-3.1-8B-Instruct-Turbo"]
        case .deepseek: return ["deepseek-chat", "deepseek-reasoner"]
        case .siliconflow: return ["Qwen/Qwen2.5-72B-Instruct", "Qwen/Qwen3-8B", "deepseek-ai/DeepSeek-V3", "THUDM/GLM-4-9B-Chat"]
        case .kimi: return ["kimi-k2.5", "moonshot-v1-128k", "moonshot-v1-32k", "moonshot-v1-8k"]
        case .minimax: return ["MiniMax-Text-02", "MiniMax-Text-01"]
        case .ollama: return ["qwen3:8b", "llama3.1:8b", "gemma3:4b", "mistral:7b"]
        case .custom: return []
        }
    }

    public var hasSTTSupport: Bool {
        switch self {
        case .openai, .groq, .together, .siliconflow, .ollama, .custom:
            return true
        case .openrouter, .deepseek, .kimi, .minimax:
            return false
        }
    }

    public var sttSupportNote: String? {
        switch self {
        case .openrouter:
            return "OpenRouter does not proxy the Whisper transcription API."
        case .deepseek:
            return "DeepSeek does not offer speech-to-text."
        case .kimi:
            return "Kimi (Moonshot) does not offer speech-to-text."
        case .minimax:
            return "MiniMax does not offer OpenAI-compatible speech-to-text."
        case .siliconflow:
            return "Uses SenseVoice — excellent Chinese speech recognition. Duration ≤ 1 hour, file ≤ 50MB."
        case .ollama:
            return "Requires a local Whisper model, for example `ollama pull whisper-large-v3-turbo`."
        case .custom:
            return "Your endpoint must support OpenAI-compatible `/audio/transcriptions`."
        default:
            return nil
        }
    }

    public var keyPlaceholder: String {
        switch self {
        case .openai: return "sk-..."
        case .openrouter: return "sk-or-..."
        case .groq: return "gsk_..."
        case .together: return "..."
        case .deepseek: return "sk-..."
        case .siliconflow: return "sk-..."
        case .kimi: return "sk-..."
        case .minimax: return "eyJ..."
        case .ollama: return "No key required"
        case .custom: return "API Key"
        }
    }

    public var requiresAPIKey: Bool {
        self != .ollama
    }

    /// Providers available on the current platform (iOS excludes Ollama)
    public static var availableCases: [APIProvider] {
        #if os(iOS)
        return allCases.filter { $0 != .ollama }
        #else
        return allCases
        #endif
    }

    /// Providers that support STT on the current platform
    public static var availableSTTCases: [APIProvider] {
        availableCases.filter(\.hasSTTSupport)
    }

    public var keyURL: String {
        switch self {
        case .openai: return "https://platform.openai.com/api-keys"
        case .openrouter: return "https://openrouter.ai/keys"
        case .groq: return "https://console.groq.com/keys"
        case .together: return "https://api.together.xyz/settings/api-keys"
        case .deepseek: return "https://platform.deepseek.com/api_keys"
        case .siliconflow: return "https://cloud.siliconflow.cn/account/ak"
        case .kimi: return "https://platform.moonshot.cn/console/api-keys"
        case .minimax: return "https://platform.minimaxi.com/"
        case .ollama: return "https://ollama.com/download"
        case .custom: return ""
        }
    }

    /// Apply provider-specific HTTP headers to a request.
    /// Centralizes header logic that was previously scattered in WhisperService/AIPolishService.
    public func applyHeaders(to request: inout URLRequest) {
        switch self {
        case .openrouter:
            request.setValue("https://vowrite.com", forHTTPHeaderField: "HTTP-Referer")
            request.setValue("Vowrite", forHTTPHeaderField: "X-Title")
        default:
            break
        }
    }

    public static func sttModelDescription(_ modelID: String) -> String? {
        switch modelID {
        case "gpt-4o-mini-transcribe": return "Fast and low-cost"
        case "gpt-4o-transcribe": return "Highest OpenAI quality"
        case "whisper-1": return "Classic Whisper endpoint"
        case "whisper-large-v3-turbo": return "Fastest Groq/Ollama option"
        case "whisper-large-v3": return "Higher accuracy"
        case "whisper-base": return "Lightweight local model"
        case "FunAudioLLM/SenseVoiceSmall": return "Alibaba SenseVoice — excellent multilingual STT"
        case "TeleAI/TeleSpeechASR": return "TeleAI ASR model"
        default: return nil
        }
    }

    public static func polishModelDescription(_ modelID: String) -> String? {
        switch modelID {
        case "gpt-4o-mini": return "Balanced quality and speed"
        case "gpt-4o": return "Highest quality"
        case "llama-3.3-70b-versatile": return "Strong value on Groq"
        case "llama-3.1-8b-instant": return "Very fast"
        case "qwen-qwq-32b": return "Reasoning-focused"
        case "deepseek-chat": return "Recommended DeepSeek default"
        case "deepseek-reasoner": return "Slower, more deliberate"
        case "Qwen/Qwen2.5-72B-Instruct": return "High quality Chinese + English"
        case "Qwen/Qwen3-8B": return "Fast, lightweight"
        case "deepseek-ai/DeepSeek-V3": return "DeepSeek via SiliconFlow"
        case "THUDM/GLM-4-9B-Chat": return "Zhipu GLM"
        case "kimi-k2.5": return "Latest Kimi flagship"
        case "moonshot-v1-128k": return "128K context window"
        case "moonshot-v1-32k": return "32K context, faster"
        case "moonshot-v1-8k": return "8K context, fastest"
        case "MiniMax-Text-02": return "Latest MiniMax flagship"
        case "MiniMax-Text-01": return "Previous generation"
        case "qwen3:8b": return "Local default"
        case "llama3.1:8b": return "Local general-purpose"
        case "gemma3:4b": return "Lightweight local option"
        case "mistral:7b": return "Good multilingual local option"
        default: return nil
        }
    }
}
