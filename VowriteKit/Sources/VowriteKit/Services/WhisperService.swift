import Foundation

/// Speech-to-text router: delegates to the correct adapter based on provider.
public final class WhisperService {
    private static let openAIAdapter = OpenAISTTAdapter()
    private static let volcengineAdapter = VolcengineSTTAdapter()
    private static let qwenAdapter = QwenSTTAdapter()

    public init() {}

    public func transcribe(audioURL: URL, language: String? = nil, prompt: String? = nil) async throws -> String {
        let configuration = APIConfig.stt
        let provider = configuration.provider
        let adapter = Self.adapter(for: provider)

        return try await adapter.transcribe(
            audioURL: audioURL,
            model: configuration.model,
            language: language,
            prompt: prompt,
            apiKey: configuration.key,
            baseURL: configuration.resolvedBaseURL,
            provider: provider
        )
    }

    private static func adapter(for provider: APIProvider) -> STTAdapter {
        switch provider {
        case .volcengine:
            return volcengineAdapter
        case .qwen:
            return qwenAdapter
        default:
            return openAIAdapter
        }
    }
}

extension Data {
    public mutating func appendMultipart(boundary: String, name: String, value: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }
}
