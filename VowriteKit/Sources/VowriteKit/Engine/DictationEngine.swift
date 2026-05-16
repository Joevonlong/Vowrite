import SwiftUI
import Combine
import os

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

    private let logger = Logger(subsystem: "com.vowrite.kit", category: "dictation")

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

    /// F-063: Oneshot mode override for the current recording session.
    /// Set by `startTranslateRecording()` and cleared on completion / cancel.
    /// When set, `effectiveModeConfig` returns this Mode instead of the
    /// user's currently-selected ModeManager mode — so a translate hotkey
    /// press never mutates the user's selected Mode.
    private var sessionModeOverride: Mode?

    /// F-063: True while the current recording was started by the translate hotkey.
    /// Read by the overlay to render the target-language badge.
    public var isInTranslateSession: Bool {
        sessionModeOverride?.isTranslation == true
    }

    /// F-063: Target language for the active translate session, or nil if not in one.
    /// Returns the SupportedLanguage rawValue (e.g. "en", "zh-Hans").
    public var sessionTranslationTarget: String? {
        guard let mode = sessionModeOverride, mode.isTranslation else { return nil }
        return mode.targetLanguage
    }

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

    /// F-063: Start a recording that will translate to the configured target
    /// language instead of polishing in the current mode. Called by the
    /// dedicated translate hotkey. No-op if already recording.
    public func startTranslateRecording() {
        guard state != .recording, state != .processing else { return }

        let translateMode = ModeManager.shared.modes.first { $0.isTranslation }
        guard let mode = translateMode else {
            state = .error("未找到翻译模式")
            return
        }
        sessionModeOverride = mode
        startRecording()
    }

    /// F-063: Returns the override mode config if a translate session is active,
    /// otherwise the user's currently-selected mode config. All pipeline reads
    /// of ModeManager.currentModeConfig inside this engine go through here so
    /// that mid-recording mode switches don't change the active session.
    private var effectiveModeConfig: ModeConfig {
        if let override = sessionModeOverride {
            return ModeConfig(from: override)
        }
        return ModeManager.currentModeConfig
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
                guard let self else { return }
                Task { @MainActor [self] in
                    self.recordingDuration += 0.1
                }
            }
            levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor [self] in
                    self.audioLevel = self.audioEngine.currentLevel
                    self.overlay.updateLevel(self.audioLevel)
                }
            }
        } catch {
            logger.error("startRecording failed: \(error.localizedDescription, privacy: .public)")
            let desc = error.localizedDescription
            let truncated = desc.count > 80 ? String(desc.prefix(80)) + "..." : desc
            state = .error("录音失败: \(truncated)")
            // F-063: clear oneshot translate override so the next normal hotkey
            // press doesn't accidentally inherit translate mode.
            sessionModeOverride = nil
        }
    }

    public func stopRecording() {
        recordingTimer?.invalidate()
        levelTimer?.invalidate()

        let wasSilent = audioEngine.wasSilent
        guard let audioURL = audioEngine.stopRecording() else {
            sessionModeOverride = nil   // F-063
            state = .error("未录到音频，请重试")
            overlay.hide()
            return
        }

        // Layer 2: Minimum duration check — block accidental taps
        guard recordingDuration >= 0.5 else {
            try? FileManager.default.removeItem(at: audioURL)
            sessionModeOverride = nil   // F-063
            state = .error("录音太短，请重试")
            overlay.hide()
            return
        }

        // Layer 1: Pre-API silence detection — skip Whisper if no speech detected
        guard !wasSilent else {
            try? FileManager.default.removeItem(at: audioURL)
            sessionModeOverride = nil   // F-063
            state = .error("未检测到语音，请重试")
            overlay.hide()
            return
        }

        state = .processing
        // Overlay stays visible but shows "Thinking"
        overlay.showProcessing()

        // F-033: Pre-build Polish request during STT (runs in parallel)
        // F-063: Use effectiveModeConfig so a translate session uses the override
        // mode for prompt building instead of whatever ModeManager has selected.
        let modeConfig = effectiveModeConfig
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
        sessionModeOverride = nil   // F-063: clear oneshot translate override on cancel
        state = .idle
        overlay.hide()
        feedback.playErrorSound()
    }

    /// Callback for saving to history — set by platform AppState.
    /// F-063: 4th argument indicates whether the record came from translate mode,
    /// so the platform layer can persist `wasTranslation` for History filtering.
    public var onRecordComplete: ((String, String, TimeInterval, Bool) -> Void)?

    private func processAudio(url: URL) {
        Task {
            defer { try? FileManager.default.removeItem(at: url) }
            do {
                // Refresh OAuth tokens before API calls (3s timeout, silent on failure)
                await CredentialManager.prepareCredentials(for: APIConfig.current)

                // Load current mode config — F-063: read through effectiveModeConfig
                // so a translate session uses the override mode regardless of what
                // ModeManager.currentModeId may have been switched to mid-recording.
                let modeConfig = effectiveModeConfig

                if let setupError = setupErrorMessage(for: modeConfig) {
                    sessionModeOverride = nil   // F-063
                    state = .error(setupError)
                    overlay.hide()
                    return
                }

                // Step 1: Whisper STT
                logger.debug("Starting STT transcription (mode: \(modeConfig.modeName, privacy: .public))...")
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
                logger.debug("STT result: '\(rawTranscript, privacy: .private)'")

                guard !rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    sessionModeOverride = nil   // F-063
                    state = .error("未检测到语音，请重试")
                    overlay.hide()
                    return
                }

                // Layer 3: Post-transcription hallucination filter
                guard !HallucinationFilter.isHallucination(rawTranscript) else {
                    logger.debug("Hallucination filtered: '\(rawTranscript, privacy: .private)'")
                    sessionModeOverride = nil   // F-063
                    state = .error("未检测到语音，请重试")
                    overlay.hide()
                    return
                }

                // Step 1.5: F-051 — Apply text replacement rules after STT
                let correctedTranscript = ReplacementManager.apply(to: rawTranscript)
                if correctedTranscript != rawTranscript {
                    logger.debug("Replacement applied: '\(rawTranscript, privacy: .private)' → '\(correctedTranscript, privacy: .private)'")
                }

                // Step 2: AI Polish (skip if mode has polishEnabled=false)
                // F-033: Uses speculative pre-built request for near-instant LLM fire
                var finalText = correctedTranscript
                var translationFailed = false   // F-063
                let effectivePolishEnabled = polishEnabledOverride ?? modeConfig.polishEnabled
                if effectivePolishEnabled {
                    do {
                        logger.debug("Starting AI polish (speculative)...")
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
                        logger.debug("Polish result: '\(polished, privacy: .private)'")
                        if finalText != polished {
                            logger.debug("Post-polish replacement: '\(polished, privacy: .private)' → '\(finalText, privacy: .private)'")
                        }
                    } catch {
                        logger.debug("Polish failed (using corrected transcript): \(error.localizedDescription, privacy: .public)")
                        // F-063: For translation mode, falling back to the raw
                        // transcript means the user gets the source language back
                        // instead of the expected translation — surface this
                        // explicitly so the user can retry instead of being
                        // confused by silently-wrong output.
                        if modeConfig.isTranslation {
                            translationFailed = true
                        }
                    }
                } else {
                    logger.debug("Polish skipped (Dictation mode)")
                }
                lastResult = finalText

                // Step 3: Hide overlay
                overlay.hide()

                // Step 4: Output text (inject or copy)
                if forceAutoPaste || modeConfig.autoPaste {
                    await textOutput.output(text: finalText)
                }

                // Step 5: Save to history via callback
                onRecordComplete?(rawTranscript, finalText, recordingDuration, modeConfig.isTranslation)

                // Step 6: Update stats
                updateStats(duration: recordingDuration, text: finalText)

                // Step 7: Success feedback (or translate-failed warning)
                speculativePolish.reset()
                promptContext = nil
                sessionModeOverride = nil   // F-063: clear oneshot translate override
                if translationFailed {
                    feedback.playErrorSound()
                    state = .error("翻译失败，已输出原文")
                } else {
                    feedback.playSuccessSound()
                    state = .idle
                }

            } catch {
                let message: String
                let desc = error.localizedDescription
                logger.error("processAudio error: \(desc, privacy: .public)")
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
                sessionModeOverride = nil   // F-063: clear oneshot translate override on hard failure
                state = .error(message)
                overlay.hide()
                feedback.playErrorSound()
            }
        }
    }

    private var isReadyForCurrentMode: Bool {
        // F-063: prefer effectiveModeConfig so a queued translate session also
        // validates against the override (in case Translate mode requires polish
        // and the user's selected mode does not).
        setupErrorMessage(for: effectiveModeConfig) == nil
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
