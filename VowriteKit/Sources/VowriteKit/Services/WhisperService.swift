import Foundation

/// Speech-to-text router: delegates to the correct adapter based on provider's sttAdapter field in the Registry.
public final class WhisperService {
    // Built-in adapter instances (keyed by sttAdapter id from providers.json)
    private static let adapterMap: [String: STTAdapter] = [
        "openai-compatible": OpenAISTTAdapter(),
        "deepgram": DeepgramSTTAdapter(),
        "volcengine": VolcengineSTTAdapter(),
        "qwen": QwenSTTAdapter(),
        "iflytek": IflytekSTTAdapter(),
        "sherpa": SherpaSTTAdapter(),
    ]

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
        let adapterID = ProviderRegistry.shared.sttAdapterID(for: provider.providerID)
        return adapterMap[adapterID] ?? adapterMap["openai-compatible"]!
    }
}

extension Data {
    public mutating func appendMultipart(boundary: String, name: String, value: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }
}
