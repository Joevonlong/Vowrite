import Foundation

public enum APIProvider: String, CaseIterable, Identifiable, Codable {
    case openai = "OpenAI"
    case openrouter = "OpenRouter"
    case groq = "Groq"
    case together = "Together AI"
    case deepseek = "DeepSeek"
    case ollama = "Ollama (Local)"
    case custom = "Custom"

    public var id: String { rawValue }

    public var defaultBaseURL: String {
        switch self {
        case .openai: return "https://api.openai.com/v1"
        case .openrouter: return "https://openrouter.ai/api/v1"
        case .groq: return "https://api.groq.com/openai/v1"
        case .together: return "https://api.together.xyz/v1"
        case .deepseek: return "https://api.deepseek.com/v1"
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
        case .ollama: return ["qwen3:8b", "llama3.1:8b", "gemma3:4b", "mistral:7b"]
        case .custom: return []
        }
    }

    public var hasSTTSupport: Bool {
        switch self {
        case .openai, .groq, .together, .ollama, .custom:
            return true
        case .openrouter, .deepseek:
            return false
        }
    }

    public var sttSupportNote: String? {
        switch self {
        case .openrouter:
            return "OpenRouter does not proxy the Whisper transcription API."
        case .deepseek:
            return "DeepSeek does not offer speech-to-text."
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
        case .ollama: return "No key required"
        case .custom: return "API Key"
        }
    }

    public var requiresAPIKey: Bool {
        self != .ollama
    }

    public var keyURL: String {
        switch self {
        case .openai: return "https://platform.openai.com/api-keys"
        case .openrouter: return "https://openrouter.ai/keys"
        case .groq: return "https://console.groq.com/keys"
        case .together: return "https://api.together.xyz/settings/api-keys"
        case .deepseek: return "https://platform.deepseek.com/api_keys"
        case .ollama: return "https://ollama.com/download"
        case .custom: return ""
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
        case "qwen3:8b": return "Local default"
        case "llama3.1:8b": return "Local general-purpose"
        case "gemma3:4b": return "Lightweight local option"
        case "mistral:7b": return "Good multilingual local option"
        default: return nil
        }
    }
}
