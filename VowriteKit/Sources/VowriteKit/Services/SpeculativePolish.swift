import CryptoKit
import Foundation

/// Pre-builds a Polish API request during STT, so when transcription completes
/// the LLM call fires instantly on a pre-warmed connection.
///
/// Usage:
///   1. `prepare(modeConfig:)` — call when recording stops (builds system prompt, request template)
///   2. `execute(transcript:)` — call when STT completes (injects text, fires request)
///   3. `warmUpConnection()` — call when recording starts (pre-warms TCP/TLS)
public final class SpeculativePolish {
    typealias FallbackPolish = (
        _ text: String,
        _ modeConfig: ModeConfig,
        _ promptContext: PromptContext?
    ) async throws -> String

    enum TransportStrategy: Equatable {
        case nativeService
        case preparedOpenAICompatible
    }

    struct RequestIdentity: Equatable {
        let providerID: String
        let baseURL: String
        let model: String
        let authMethod: String
        let credentialHash: String?
    }

    static func transportStrategy(for provider: APIProvider) -> TransportStrategy {
        provider == .claude ? .nativeService : .preparedOpenAICompatible
    }

    static func requestIdentity(
        providerID: String,
        baseURL: String,
        model: String,
        authMethod: String,
        credential: String?
    ) -> RequestIdentity {
        let credentialHash = credential.map {
            SHA256.hash(data: Data($0.utf8)).map { String(format: "%02x", $0) }.joined()
        }
        return RequestIdentity(
            providerID: providerID,
            baseURL: baseURL,
            model: model,
            authMethod: authMethod,
            credentialHash: credentialHash
        )
    }

    private var preparedConfig: PreparedConfig?
    private var warmedSession: URLSession?
    private let configurationProvider: () -> APIEndpointConfiguration
    private let fallbackPolish: FallbackPolish

    public convenience init() {
        self.init(
            configurationProvider: { APIConfig.polish },
            fallbackPolish: { text, modeConfig, promptContext in
                try await AIPolishService().polish(
                    text: text,
                    modeConfig: modeConfig,
                    promptContext: promptContext
                )
            }
        )
    }

    init(
        configurationProvider: @escaping () -> APIEndpointConfiguration,
        fallbackPolish: @escaping FallbackPolish
    ) {
        self.configurationProvider = configurationProvider
        self.fallbackPolish = fallbackPolish
    }

    // MARK: - Step 1: Connection warmup (call on recording start)

    /// Pre-warms TCP/TLS connection to the Polish endpoint during recording.
    /// Runs in background, fire-and-forget.
    public func warmUpConnection() {
        let configuration = configurationProvider()
        guard Self.transportStrategy(for: configuration.provider) == .preparedOpenAICompatible else {
            warmedSession?.invalidateAndCancel()
            warmedSession = nil
            return
        }
        let baseURL = configuration.resolvedBaseURL
        guard let url = URL(string: "\(baseURL)/chat/completions") else { return }

        // Use a dedicated session that keeps the connection alive
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForResource = 10
        let session = URLSession(configuration: sessionConfig)
        warmedSession = session

        // Lightweight HEAD request just to establish the connection
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5
        if let apiKey = configuration.key {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let task = session.dataTask(with: request) { _, _, _ in
            // We don't care about the response — the connection is now warm
        }
        task.resume()
    }

    // MARK: - Step 2: Prepare request template (call when recording stops, runs during STT)

    /// Pre-builds everything for the Polish request except the transcript text.
    /// Call this right when recording stops — it runs in parallel with STT.
    public func prepare(modeConfig: ModeConfig, promptContext: PromptContext? = nil) {
        let configuration = configurationProvider()
        let provider = configuration.provider
        guard Self.transportStrategy(for: provider) == .preparedOpenAICompatible else {
            preparedConfig = nil
            return
        }

        let baseURL = configuration.resolvedBaseURL
        let selectedModel = modeConfig.polishModel ?? configuration.resolvedModel
        let model = ProviderModelSafetyRules.safeModel(
            providerID: provider.providerID,
            capability: .polish,
            storedModel: selectedModel
        )
        let endpoint = "\(baseURL)/chat/completions"

        guard let url = URL(string: endpoint) else {
            preparedConfig = nil
            return
        }

        // Build the full system prompt (translation branch or polish branch)
        let systemPrompt = Self.buildSystemPrompt(for: modeConfig)

        // Build request headers
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if let apiKey = configuration.key {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120
        provider.applyHeaders(to: &request)

        // Kimi Code Coding Plan endpoint requires coding-agent UA + device headers
        if provider == .kimi,
           KeyVault.preferredAuthMethod(for: provider) == "oauth",
           KeyVault.hasValidOAuthToken(for: provider) {
            KimiCodeOAuthService.applyCodingPlanHeaders(to: &request)
        }

        // F-073: Resolve per-model polish overrides (e.g. disable thinking mode) once
        // at prepare time; apply them at execute time when the payload is serialized.
        let resolvedOverrides = ProviderRegistry.shared.polishOverrides(
            providerID: provider.providerID,
            modelID: model
        )

        preparedConfig = PreparedConfig(
            request: request,
            systemPrompt: systemPrompt,
            requestIdentity: Self.requestIdentity(
                providerID: provider.providerID,
                baseURL: baseURL,
                model: model,
                authMethod: KeyVault.preferredAuthMethod(for: provider),
                credential: configuration.key
            ),
            model: model,
            temperature: modeConfig.temperature,
            promptContext: promptContext,
            polishOverrides: resolvedOverrides
        )
    }

    // MARK: - Step 3: Execute with transcript (call when STT completes)

    /// Fires the pre-built Polish request with the actual transcript.
    /// Falls back to standard AIPolishService if no prepared config exists.
    /// - Parameter onPartial: Optional callback invoked with accumulated partial text as tokens stream in.
    ///   When provided, uses SSE streaming for lower perceived latency.
    public func execute(
        transcript: String,
        modeConfig: ModeConfig,
        promptContext: PromptContext? = nil,
        onPartial: ((String) -> Void)? = nil
    ) async throws -> String {
        let currentConfiguration = configurationProvider()
        let currentProvider = currentConfiguration.provider
        let currentSelectedModel = modeConfig.polishModel ?? currentConfiguration.resolvedModel
        let currentModel = ProviderModelSafetyRules.safeModel(
            providerID: currentProvider.providerID,
            capability: .polish,
            storedModel: currentSelectedModel
        )
        let currentIdentity = Self.requestIdentity(
            providerID: currentProvider.providerID,
            baseURL: currentConfiguration.resolvedBaseURL,
            model: currentModel,
            authMethod: KeyVault.preferredAuthMethod(for: currentProvider),
            credential: currentConfiguration.key
        )
        guard let config = preparedConfig,
              Self.transportStrategy(for: currentProvider) == .preparedOpenAICompatible,
              config.requestIdentity == currentIdentity else {
            // Fallback: no prepared config, use standard path
            return try await fallbackPolish(transcript, modeConfig, promptContext)
        }

        // F-045: Expand context variables in the pre-built system prompt.
        // F-063: Translation mode prompt has no placeholders; expansion is a no-op
        // but stays cheap enough to leave on the polish-shared path.
        var expandedSystemPrompt = config.systemPrompt
        if !modeConfig.isTranslation, let ctx = config.promptContext ?? promptContext {
            expandedSystemPrompt = ctx.expandAll(expandedSystemPrompt, text: transcript)
        }

        let wrappedText: String
        if modeConfig.isTranslation {
            wrappedText = """
            Translate the following transcript. Output ONLY the translation, nothing else.

            --- TRANSCRIPT START ---
            \(transcript)
            --- TRANSCRIPT END ---
            """
        } else {
            wrappedText = """
            Clean up the following speech transcript. Output ONLY the cleaned text, nothing else.

            --- TRANSCRIPT START ---
            \(transcript)
            --- TRANSCRIPT END ---
            """
        }

        // F-055: Streaming path for OpenAI-compatible providers (when caller wants partial updates)
        if onPartial != nil {
            return try await executeStreaming(
                config: config,
                expandedSystemPrompt: expandedSystemPrompt,
                wrappedText: wrappedText,
                onPartial: onPartial!
            )
        }

        // Non-streaming path
        let payload = makeOpenAICompatiblePolishPayload(
            model: config.model,
            systemPrompt: expandedSystemPrompt,
            userPrompt: wrappedText,
            temperature: config.temperature,
            stream: false,
            overrides: config.polishOverrides
        )

        var request = config.request
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        // Use the warm session if available, otherwise default
        let session = warmedSession ?? URLSession.shared
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VowriteError.networkError("Invalid response from polish API")
        }
        guard httpResponse.statusCode == 200 else {
            throw ProviderHTTPErrorPolicy.publicError(
                context: .polishRequest,
                response: httpResponse,
                discardingResponseBody: data
            )
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw VowriteError.apiError("Failed to parse polish response")
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines).strippingThinkTags()
    }

    // MARK: - Streaming SSE (F-055)

    private func executeStreaming(
        config: PreparedConfig,
        expandedSystemPrompt: String,
        wrappedText: String,
        onPartial: (String) -> Void
    ) async throws -> String {
        let streamPayload = makeOpenAICompatiblePolishPayload(
            model: config.model,
            systemPrompt: expandedSystemPrompt,
            userPrompt: wrappedText,
            temperature: config.temperature,
            stream: true,
            overrides: config.polishOverrides
        )

        var request = config.request
        request.httpBody = try JSONSerialization.data(withJSONObject: streamPayload)

        let session = warmedSession ?? URLSession.shared
        let (bytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VowriteError.networkError("Invalid streaming response from polish API")
        }
        guard httpResponse.statusCode == 200 else {
            // Do not consume or accumulate a provider error stream. Public failures
            // are derived entirely from bounded response metadata.
            throw ProviderHTTPErrorPolicy.publicError(
                context: .polishStreamingRequest,
                response: httpResponse
            )
        }

        var result = ""
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonString = String(line.dropFirst(6))
            guard jsonString != "[DONE]",
                  let data = jsonString.data(using: .utf8),
                  let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = event["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let token = delta["content"] as? String,
                  !token.isEmpty else { continue }

            result += token
            onPartial(Self.displayPartial(forAccumulated: result))
        }

        guard !result.isEmpty else {
            throw VowriteError.apiError("Empty streaming response from polish API")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines).strippingThinkTags()
    }

    /// Reset prepared state (call after completion or cancellation).
    public func reset() {
        preparedConfig = nil
    }

    /// Test-visible request boundary evidence. Claude-native preparation keeps
    /// this nil, proving no OpenAI-compatible endpoint was constructed.
    var preparedRequestURL: URL? {
        preparedConfig?.request.url
    }

    /// Maps the accumulated raw streaming buffer to the display-ready partial
    /// surfaced via `onPartial`. Strips reasoning-model `<think>` content so the
    /// chain-of-thought never flashes in the live partial as tokens arrive (V-024).
    /// Pure; unit-tested.
    static func displayPartial(forAccumulated raw: String) -> String {
        raw.strippingThinkTags()
    }

    // MARK: - Internal

    private struct PreparedConfig {
        let request: URLRequest
        let systemPrompt: String
        let requestIdentity: RequestIdentity
        let model: String
        let temperature: Double
        let promptContext: PromptContext?
        /// F-073: Per-model overrides resolved at prepare() time (from providers.json).
        let polishOverrides: [String: JSONValue]?
    }

    /// Build the system prompt for either polish or translation mode.
    /// Shared between SpeculativePolish.prepare() and AIPolishService so the two
    /// paths stay consistent.
    static func buildSystemPrompt(for modeConfig: ModeConfig) -> String {
        // F-063: Translation mode uses a dedicated prompt and skips
        // outputStyle / userPrompt to avoid contaminating translation output.
        if modeConfig.isTranslation, let target = modeConfig.targetLanguage {
            // F-079: `SupportedLanguage.displayName` is already region-qualified
            // for variants (e.g. "zh-TW" -> "Chinese (Traditional, Taiwan)"),
            // so {targetLanguageName} renders correctly with no extra work.
            let langName = SupportedLanguage(rawValue: target)?.displayName ?? target
            var prompt = PromptConfig.translationSystemPromptTemplate
                .replacingOccurrences(of: "{targetLanguageName}", with: langName)

            // F-079: region variant (e.g. Traditional Taiwan vs. Hong Kong)
            // gets an explicit script/spelling instruction beyond the language name.
            if let regionInstruction = LanguageConfig.polishRegionInstruction(for: target) {
                prompt += "\n\n---\nRegion convention:\n\(regionInstruction)"
            }

            // Optional advanced override: user-specified extra instructions
            // (e.g. "Translate into British English"). Empty by default.
            let extra = modeConfig.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
            if !extra.isEmpty {
                prompt += "\n\n---\nAdditional instructions:\n\(extra)"
            }

            // Vocabulary hint still helps preserve proper-noun spellings
            if let vocabHint = ReplacementManager.llmVocabularyHint {
                prompt += "\n\n---\nImportant vocabulary (preserve exact spelling): \(vocabHint)"
            }
            return prompt
        }

        // Standard polish path
        var systemPrompt = PromptConfig.effectiveSystemPrompt

        // F-079: when the mode has an explicit language override with a
        // region variant (e.g. Mode.language == "zh-TW"), tell the LLM which
        // script/spelling convention to render output in. Note: this only
        // fires for an explicit per-mode override — a global default
        // language variant (Mode.language == nil) is not resolved here, to
        // keep this function free of a dependency on `LanguageConfig.globalLanguage`.
        if let modeLang = modeConfig.language, let regionInstruction = LanguageConfig.polishRegionInstruction(for: modeLang) {
            systemPrompt += "\n\n---\nRegion convention:\n\(regionInstruction)"
        }

        if let stylePrompt = OutputStyleManager.templatePrompt(for: modeConfig.outputStyleId) {
            systemPrompt += "\n\n---\nOutput style:\n\(stylePrompt)"
        }
        if !modeConfig.systemPrompt.isEmpty {
            systemPrompt += "\n\n---\nOutput formatting for current mode (\(modeConfig.modeName)):\n\(modeConfig.systemPrompt)"
        }
        if !modeConfig.userPrompt.isEmpty {
            systemPrompt += "\n\n---\nAdditional user preferences for this mode:\n\(modeConfig.userPrompt)"
        }
        if let vocabHint = ReplacementManager.llmVocabularyHint {
            systemPrompt += "\n\n---\nImportant vocabulary (always use these exact spellings when relevant): \(vocabHint)"
        }
        return systemPrompt
    }
}
