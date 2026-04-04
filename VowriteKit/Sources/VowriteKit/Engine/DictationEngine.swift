import SwiftUI
import Combine

public enum VowriteState: Equatable {
    case idle
    case recording
    case processing
    case error(String)
}

@MainActor
public final class DictationEngine: ObservableObject {
    @Published public var state: VowriteState = .idle
    @Published public var audioLevel: Float = 0
    @Published public var recordingDuration: TimeInterval = 0
    @Published public var lastResult: String?
    @Published public var lastRawTranscript: String?

    public let audioEngine = AudioEngine()
    public let whisperService = WhisperService()
    public let aiPolishService = AIPolishService()
    private let speculativePolish = SpeculativePolish()

    private let textOutput: TextOutputProvider
    private let permissions: PermissionProvider
    private let overlay: OverlayProvider
    private let feedback: FeedbackProvider

    private var recordingTimer: Timer?
    private var levelTimer: Timer?
    private var promptContext: PromptContext?

    public var isRecording: Bool { state == .recording }

    public var menuBarIcon: String {
        switch state {
        case .idle: return "mic"
        case .recording: return "mic.fill"
        case .processing: return "ellipsis.circle"
        case .error: return "exclamationmark.triangle"
        }
    }

    // MARK: Stats
    public var totalDictationTime: TimeInterval {
        VowriteStorage.defaults.double(forKey: "totalDictationTime")
    }
    public var totalWords: Int {
        VowriteStorage.defaults.integer(forKey: "totalWords")
    }
    public var totalDictations: Int {
        VowriteStorage.defaults.integer(forKey: "totalDictations")
    }

    /// External override for polishEnabled. nil = use Mode default.
    /// Used by keyboard extension's temporary AI toggle.
    public var polishEnabledOverride: Bool? = nil

    /// When true, always insert text regardless of Mode's autoPaste setting.
    /// Keyboard extension sets this to true (not inserting text makes no sense in a keyboard).
    public var forceAutoPaste: Bool = false

    public var hasAPIKey: Bool {
        isReadyForCurrentMode
    }

    public init(textOutput: TextOutputProvider, permissions: PermissionProvider,
                overlay: OverlayProvider, feedback: FeedbackProvider) {
        self.textOutput = textOutput
        self.permissions = permissions
        self.overlay = overlay
        self.feedback = feedback
    }

    private func updateStats(duration: TimeInterval, text: String) {
        let wordCount = text.split(separator: " ").count + text.split(separator: "\u{3000}").count
        VowriteStorage.defaults.set(totalDictationTime + duration, forKey: "totalDictationTime")
        VowriteStorage.defaults.set(totalWords + wordCount, forKey: "totalWords")
        VowriteStorage.defaults.set(totalDictations + 1, forKey: "totalDictations")
        objectWillChange.send()
    }

    public func toggleRecording() {
        switch state {
        case .idle, .error:
            startRecording()
        case .recording:
            stopRecording()
        case .processing:
            break
        }
    }

    public func startRecording() {
        guard permissions.hasMicrophoneAccess() else {
            Task {
                let granted = await permissions.requestMicrophoneAccess()
                if granted {
                    startRecording()
                }
            }
            return
        }

        // Remember which app has focus BEFORE we start (so we can paste back into it)
        textOutput.prepareForOutput()

        // F-045: Capture selected text and clipboard before overlay changes focus
        promptContext = PromptContext.capture()

        do {
            try audioEngine.startRecording()
            state = .recording
            recordingDuration = 0
            audioLevel = 0

            // Show floating overlay
            overlay.showRecording()

            // Pre-warm Polish API connection during recording
            speculativePolish.warmUpConnection()

            // Start recording sound
            feedback.playStartSound()

            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.recordingDuration += 0.1
                }
            }
            levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.audioLevel = self.audioEngine.currentLevel
                    self.overlay.updateLevel(self.audioLevel)
                }
            }
        } catch {
            #if DEBUG
            print("[Vowrite] startRecording failed: \(error)")
            #endif
            let desc = error.localizedDescription
            let truncated = desc.count > 80 ? String(desc.prefix(80)) + "..." : desc
            state = .error("录音失败: \(truncated)")
        }
    }

    public func stopRecording() {
        recordingTimer?.invalidate()
        levelTimer?.invalidate()

        let wasSilent = audioEngine.wasSilent
        guard let audioURL = audioEngine.stopRecording() else {
            state = .error("未录到音频，请重试")
            overlay.hide()
            return
        }

        // Layer 2: Minimum duration check — block accidental taps
        guard recordingDuration >= 0.5 else {
            try? FileManager.default.removeItem(at: audioURL)
            state = .error("录音太短，请重试")
            overlay.hide()
            return
        }

        // Layer 1: Pre-API silence detection — skip Whisper if no speech detected
        guard !wasSilent else {
            try? FileManager.default.removeItem(at: audioURL)
            state = .error("未检测到语音，请重试")
            overlay.hide()
            return
        }

        state = .processing
        // Overlay stays visible but shows "Thinking"
        overlay.showProcessing()

        // F-033: Pre-build Polish request during STT (runs in parallel)
        let modeConfig = ModeManager.currentModeConfig
        let effectivePolishEnabled = polishEnabledOverride ?? modeConfig.polishEnabled
        if effectivePolishEnabled {
            speculativePolish.prepare(modeConfig: modeConfig, promptContext: promptContext)
        }

        processAudio(url: audioURL)
    }

    public func cancelRecording() {
        recordingTimer?.invalidate()
        levelTimer?.invalidate()
        _ = audioEngine.stopRecording()
        speculativePolish.reset()
        promptContext = nil
        state = .idle
        overlay.hide()
        feedback.playErrorSound()
    }

    /// Callback for saving to history — set by platform AppState
    public var onRecordComplete: ((String, String, TimeInterval) -> Void)?

    private func processAudio(url: URL) {
        Task {
            do {
                // Refresh OAuth tokens before API calls (3s timeout, silent on failure)
                await CredentialManager.prepareCredentials(for: APIConfig.current)

                // Load current mode config
                let modeConfig = ModeManager.currentModeConfig

                if let setupError = setupErrorMessage(for: modeConfig) {
                    state = .error(setupError)
                    overlay.hide()
                    return
                }

                // Step 1: Whisper STT
                #if DEBUG
                print("[Vowrite] Starting STT transcription (mode: \(modeConfig.modeName))...")
                #endif
                // Mode language override > global language setting
                let whisperLanguage: String?
                if let modeLang = modeConfig.language,
                   let lang = SupportedLanguage(rawValue: modeLang) {
                    whisperLanguage = lang.whisperCode
                } else {
                    whisperLanguage = LanguageConfig.globalLanguage.whisperCode
                }
                let vocabPrompt = VocabularyManager.whisperPrompt
                let rawTranscript = try await whisperService.transcribe(audioURL: url, language: whisperLanguage, prompt: vocabPrompt)
                lastRawTranscript = rawTranscript
                #if DEBUG
                print("[Vowrite] STT result: '\(rawTranscript)'")
                #endif

                guard !rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    state = .error("未检测到语音，请重试")
                    overlay.hide()
                    return
                }

                // Layer 3: Post-transcription hallucination filter
                guard !HallucinationFilter.isHallucination(rawTranscript) else {
                    #if DEBUG
                    print("[Vowrite] Hallucination filtered: '\(rawTranscript)'")
                    #endif
                    state = .error("未检测到语音，请重试")
                    overlay.hide()
                    return
                }

                // Step 1.5: F-051 — Apply text replacement rules after STT
                let correctedTranscript = ReplacementManager.apply(to: rawTranscript)
                #if DEBUG
                if correctedTranscript != rawTranscript {
                    print("[Vowrite] Replacement applied: '\(rawTranscript)' → '\(correctedTranscript)'")
                }
                #endif

                // Step 2: AI Polish (skip if mode has polishEnabled=false)
                // F-033: Uses speculative pre-built request for near-instant LLM fire
                var finalText = correctedTranscript
                let effectivePolishEnabled = polishEnabledOverride ?? modeConfig.polishEnabled
                if effectivePolishEnabled {
                    do {
                        #if DEBUG
                        print("[Vowrite] Starting AI polish (speculative)...")
                        #endif
                        let polished = try await speculativePolish.execute(
                            transcript: correctedTranscript,
                            modeConfig: modeConfig,
                            promptContext: promptContext,
                            onPartial: { [weak self] partial in
                                Task { @MainActor in
                                    self?.lastResult = partial
                                }
                            }
                        )
                        // F-051: Apply replacement rules again after LLM (catches re-introduced errors)
                        finalText = ReplacementManager.apply(to: polished)
                        #if DEBUG
                        print("[Vowrite] Polish result: '\(polished)'")
                        if finalText != polished {
                            print("[Vowrite] Post-polish replacement: '\(polished)' → '\(finalText)'")
                        }
                        #endif
                    } catch {
                        #if DEBUG
                        print("[Vowrite] Polish failed (using corrected transcript): \(error)")
                        #endif
                    }
                } else {
                    #if DEBUG
                    print("[Vowrite] Polish skipped (Dictation mode)")
                    #endif
                }
                lastResult = finalText

                // Step 3: Hide overlay
                overlay.hide()

                // Step 4: Output text (inject or copy)
                if forceAutoPaste || modeConfig.autoPaste {
                    await textOutput.output(text: finalText)
                }

                // Step 5: Save to history via callback
                onRecordComplete?(rawTranscript, finalText, recordingDuration)

                // Step 6: Update stats
                updateStats(duration: recordingDuration, text: finalText)

                // Step 7: Success feedback
                speculativePolish.reset()
                promptContext = nil
                feedback.playSuccessSound()
                state = .idle

            } catch {
                let message: String
                let desc = error.localizedDescription
                #if DEBUG
                print("[Vowrite] Error: \(desc)")
                #endif
                if desc.contains("insufficient_quota") {
                    message = "API 额度不足，请充值"
                } else if desc.contains("invalid_api_key") || desc.contains("Incorrect API key") || desc.contains("401") {
                    message = "API Key 无效，请在设置中检查"
                } else if desc.contains("rate_limit") || desc.contains("429") {
                    message = "请求过于频繁，请稍后重试"
                } else if desc.contains("404") || desc.contains("not found") || desc.contains("Not Found") {
                    message = "API 端点不支持，请检查 Provider 设置"
                } else if (error as? URLError)?.code == .notConnectedToInternet {
                    message = "无网络连接"
                } else if (error as? URLError)?.code == .timedOut {
                    message = "请求超时，请检查 API 设置或网络"
                } else if (error as? URLError)?.code == .networkConnectionLost {
                    message = "网络连接中断"
                } else {
                    // Show actual error for debugging — truncate if too long
                    let truncated = desc.count > 80 ? String(desc.prefix(80)) + "..." : desc
                    message = truncated
                }
                speculativePolish.reset()
                state = .error(message)
                overlay.hide()
                feedback.playErrorSound()
            }
        }
    }

    private var isReadyForCurrentMode: Bool {
        setupErrorMessage(for: ModeManager.currentModeConfig) == nil
    }

    private func setupErrorMessage(for modeConfig: ModeConfig) -> String? {
        let sttConfiguration = APIConfig.stt
        if !sttConfiguration.provider.hasSTTSupport {
            return "\(sttConfiguration.provider.rawValue) 不支持语音识别，请在设置中修改 STT Provider"
        }
        if sttConfiguration.requiresAPIKey && sttConfiguration.key == nil {
            return "请先在设置中配置 \(sttConfiguration.provider.rawValue) API Key"
        }

        if modeConfig.polishEnabled {
            let polishConfiguration = APIConfig.polish
            if polishConfiguration.requiresAPIKey && polishConfiguration.key == nil {
                return "请先在设置中配置 \(polishConfiguration.provider.rawValue) API Key"
            }
        }

        return nil
    }

    /// F-018: Switch to mode by index (0-based)
    public func switchToMode(at index: Int) {
        let modes = ModeManager.shared.modes
        guard index >= 0, index < modes.count else { return }
        ModeManager.shared.select(modes[index])
    }
}
