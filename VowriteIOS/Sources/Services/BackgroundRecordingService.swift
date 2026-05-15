import AVFoundation
import SwiftUI
import VowriteKit

// MARK: - BGServiceDuration

enum BGServiceDuration: Int, CaseIterable, Identifiable {
    case oneMinute = 60
    case fiveMinutes = 300
    case tenMinutes = 600
    case always = 0

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .oneMinute:   return "1 min"
        case .fiveMinutes: return "5 min"
        case .tenMinutes:  return "10 min"
        case .always:      return "Always"
        }
    }

    var seconds: TimeInterval? {
        self == .always ? nil : TimeInterval(rawValue)
    }
}

/// Main App background recording service.
/// Listens for commands from keyboard extension via Darwin Notifications,
/// records audio, processes STT + AI polish, and writes results back via IPC.
///
/// Architecture: The keyboard extension is a remote control only.
/// All recording happens here in the main app process.
///
/// Audio strategy — Background Audio Session pattern (industry standard):
/// - AVAudioEngine with persistent input tap (started in foreground, runs in background)
/// - The engine input tap itself provides UIBackgroundModes: audio activity (no silent player needed)
/// - Session activated once in foreground, stays warm for configured duration, then auto-closes
/// - Keyboard auto-jumps to container app for activation when session is not active
/// - Same approach used by Typeless, Willow, iFlytek (讯飞), Baidu Input
///
/// References:
/// - https://developer.apple.com/documentation/avfaudio/avaudionode/1387122-installtap
/// - https://github.com/Picovoice/ios-voice-processor
/// - https://developer.apple.com/videos/play/wwdc2019/510/
@MainActor
final class BackgroundRecordingService: ObservableObject {
    @Published var isActive = false
    @Published var isRecording = false
    @Published var activationError: String?
    @Published var remainingTime: TimeInterval? = nil

    private let ipc = BackgroundRecordingIPC.shared
    private let whisperService = WhisperService()
    private let aiPolishService = AIPolishService()
    private let speculativePolish = SpeculativePolish()

    // MARK: - Audio Engine (replaces AVAudioRecorder)
    // AVAudioEngine with input tap keeps microphone active continuously.
    // iOS allows this in background because the engine was started in foreground.
    // "Recording" = opening a file and writing tap data (not starting new input).
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?     // non-nil = actively writing audio to file
    private var inputFormat: AVAudioFormat?
    private nonisolated(unsafe) var lastRMSLevel: Float = 0
    /// Peak RMS observed during current recording session — for silence detection.
    private nonisolated(unsafe) var peakRMS: Float = 0
    private let fileLock = NSLock()         // protects audioFile across audio render + main threads

    private var recordingTimer: Timer?
    private var levelTimer: Timer?
    private var heartbeatTimer: Timer?
    private var recordingStartTime: Date?
    private var recordingURL: URL?
    private var interruptionObserver: NSObjectProtocol?
    private var promptContext: PromptContext?

    /// F-064: One-shot Mode override resolved at recording start. When set,
    /// `effectiveModeConfig` returns this Mode's config instead of the user's
    /// persisted current Mode. Cleared at the end of every recording lifecycle.
    private var sessionMode: Mode?

    /// F-064: Read ModeManager.currentModeConfig unless a session override was
    /// installed at recording start, in which case use that. Mirrors the
    /// macOS DictationEngine.effectiveModeConfig pattern from F-063.
    private var effectiveModeConfig: ModeConfig {
        if let mode = sessionMode {
            return ModeConfig(from: mode)
        }
        return ModeManager.currentModeConfig
    }

    /// F-064: Clear the one-shot override at the end of a session and tell the
    /// keyboard so the next recording falls back to the user's persisted Mode.
    private func clearSessionMode() {
        sessionMode = nil
        ipc.clearSessionModeOverride()
    }

    // MARK: - Auto-deactivation timer
    private var countdownTimer: Timer?
    private var activatedAt: Date?
    private var activeDuration: BGServiceDuration = .always
    private var pendingAutoDeactivation = false

    init() {}

    // MARK: - Activate / Deactivate

    func activate(duration: BGServiceDuration = .always) {
        // If already active, just update the timer (e.g. user changed duration picker)
        if isActive {
            activeDuration = duration
            setupAutoDeactivation(duration: duration)
            #if DEBUG
            print("[Vowrite BG] activate() called while active, updated duration to \(duration.label)")
            #endif
            return
        }
        activationError = nil

        #if DEBUG
        print("[Vowrite BG] activate() starting...")
        #endif

        #if os(iOS)
        // 1. Check microphone permission
        let micPermission = AVAudioApplication.shared.recordPermission
        #if DEBUG
        print("[Vowrite BG] Mic permission: \(micPermission == .granted ? "granted" : micPermission == .denied ? "denied" : "undetermined")")
        #endif

        if micPermission == .denied {
            activationError = "Microphone access denied. Go to Settings → Vowrite → Microphone to enable."
            return
        }

        if micPermission == .undetermined {
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                Task { @MainActor in
                    if granted {
                        self?.activate(duration: duration)
                    } else {
                        self?.activationError = "Microphone access denied."
                    }
                }
            }
            return
        }

        // 2. Configure audio session (.playAndRecord + .mixWithOthers)
        //    This session supports simultaneous silent playback + engine recording.
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetoothHFP, .mixWithOthers]
            )
            try session.setActive(true)
            #if DEBUG
            print("[Vowrite BG] Audio session configured: .playAndRecord + mixWithOthers, active=true")
            print("[Vowrite BG] Input available: \(session.isInputAvailable), routes: \(session.currentRoute.inputs.map(\.portName))")
            #endif
        } catch {
            activationError = "Audio session failed: \(error.localizedDescription)"
            #if DEBUG
            print("[Vowrite BG] Audio session setup FAILED: \(error)")
            #endif
            return
        }

        // 3. Start AVAudioEngine with continuous input tap.
        //    This keeps the microphone input active even when the app is in background.
        //    When recording is needed, we just open a file and the tap writes to it.
        //    Ref: https://developer.apple.com/documentation/avfaudio/avaudionode/1387122-installtap
        do {
            let engine = AVAudioEngine()
            let inputNode = engine.inputNode
            let format = inputNode.outputFormat(forBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
                guard let self else { return }

                // Calculate RMS for waveform display + silence detection (only when recording)
                if self.isRecording {
                    let rms = self.calculateRMS(buffer: buffer)
                    self.lastRMSLevel = rms
                    // Track peak RMS across session for silence detection
                    if rms > self.peakRMS { self.peakRMS = rms }
                }

                // Write to file only when audioFile is set (= recording active)
                self.fileLock.lock()
                let file = self.audioFile
                self.fileLock.unlock()
                if let file {
                    try? file.write(from: buffer)
                }
            }

            try engine.start()
            self.audioEngine = engine
            self.inputFormat = format
            #if DEBUG
            print("[Vowrite BG] AVAudioEngine started, input: \(format.sampleRate)Hz \(format.channelCount)ch")
            #endif
        } catch {
            activationError = "Audio engine failed: \(error.localizedDescription)"
            #if DEBUG
            print("[Vowrite BG] AVAudioEngine start FAILED: \(error)")
            #endif
            return
        }

        // 4. Observe audio interruptions (phone calls, etc.)
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil, queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleInterruption(notification)
            }
        }
        #endif

        // Reset IPC state
        ipc.clearResult()
        ipc.serviceActive = true
        ipc.serviceHeartbeat = Date()

        // Start heartbeat timer (2s interval, keyboard checks within 5s window)
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.ipc.serviceHeartbeat = Date()
            }
        }

        // Listen for keyboard commands via Darwin Notifications
        ipc.observeCommands { [weak self] command in
            Task { @MainActor in
                #if DEBUG
                print("[Vowrite BG] Received command from keyboard: \(command)")
                #endif
                self?.handleCommand(command)
            }
        }

        isActive = true
        activeDuration = duration
        setupAutoDeactivation(duration: duration)
        #if DEBUG
        print("[Vowrite BG] Background recording service ACTIVATED successfully (duration: \(duration.label))")
        #endif
    }

    func deactivate() {
        guard isActive else { return }

        if isRecording {
            cancelRecording()
        }

        // Clean up auto-deactivation timers
        countdownTimer?.invalidate()
        countdownTimer = nil
        remainingTime = nil
        activatedAt = nil
        pendingAutoDeactivation = false

        heartbeatTimer?.invalidate()
        heartbeatTimer = nil

        // Stop audio engine and remove input tap
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputFormat = nil

        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
            interruptionObserver = nil
        }

        ipc.stopObserving()
        ipc.serviceActive = false
        ipc.clearResult()
        ipc.clearSessionModeOverride()

        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif

        isActive = false
        #if DEBUG
        print("[Vowrite BG] Background recording service deactivated")
        #endif
    }

    // MARK: - Auto-Deactivation Timer

    private func setupAutoDeactivation(duration: BGServiceDuration) {
        countdownTimer?.invalidate()
        countdownTimer = nil

        if let seconds = duration.seconds {
            // Check if resuming from a persisted activation timestamp
            let persistedAt = VowriteStorage.defaults.double(forKey: "bgServiceActivatedAt")
            if persistedAt > 0 {
                let elapsed = Date().timeIntervalSince(Date(timeIntervalSince1970: persistedAt))
                let remaining = seconds - elapsed
                if remaining <= 0 {
                    // Timer already expired (e.g. app was killed)
                    performAutoDeactivation()
                    return
                }
                activatedAt = Date(timeIntervalSince1970: persistedAt)
            } else {
                activatedAt = Date()
                VowriteStorage.defaults.set(Date().timeIntervalSince1970, forKey: "bgServiceActivatedAt")
            }
            startCountdown(totalSeconds: seconds)
        } else {
            // "Always" mode — no timer
            activatedAt = nil
            remainingTime = nil
            VowriteStorage.defaults.removeObject(forKey: "bgServiceActivatedAt")
        }
    }

    private func startCountdown(totalSeconds: TimeInterval) {
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let activated = self.activatedAt else { return }
                let elapsed = Date().timeIntervalSince(activated)
                let remaining = totalSeconds - elapsed
                if remaining <= 0 {
                    self.autoDeactivate()
                } else {
                    self.remainingTime = remaining
                }
            }
        }
        // Set initial remaining time
        if let activated = activatedAt {
            remainingTime = totalSeconds - Date().timeIntervalSince(activated)
        } else {
            remainingTime = totalSeconds
        }
    }

    private func autoDeactivate() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        remainingTime = 0

        if isRecording {
            pendingAutoDeactivation = true
            #if DEBUG
            print("[Vowrite BG] Timer expired during recording, will deactivate after recording completes")
            #endif
        } else {
            performAutoDeactivation()
        }
    }

    private func performAutoDeactivation() {
        #if DEBUG
        print("[Vowrite BG] Auto-deactivated (timer expired)")
        #endif
        deactivate()
        VowriteStorage.defaults.set(false, forKey: "bgServiceEnabled")
        VowriteStorage.defaults.removeObject(forKey: "bgServiceActivatedAt")
    }

    // MARK: - Audio Interruption Handling

    private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            #if DEBUG
            print("[Vowrite BG] Audio interruption began")
            #endif
            if isRecording {
                cancelRecording()
                ipc.state = .error
                ipc.errorMessage = "Recording interrupted (phone call or other audio)"
            }
            audioEngine?.pause()

        case .ended:
            #if DEBUG
            print("[Vowrite BG] Audio interruption ended")
            #endif
            let options = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let shouldResume = AVAudioSession.InterruptionOptions(rawValue: options)
                .contains(.shouldResume)

            if shouldResume {
                do {
                    try AVAudioSession.sharedInstance().setActive(true)
                    try audioEngine?.start()
                    #if DEBUG
                    print("[Vowrite BG] Session + engine reactivated after interruption")
                    #endif
                } catch {
                    #if DEBUG
                    print("[Vowrite BG] Reactivation failed, retrying in 0.5s: \(error)")
                    #endif
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        try? AVAudioSession.sharedInstance().setActive(true)
                        try? self.audioEngine?.start()
                    }
                }
            } else {
                #if DEBUG
                print("[Vowrite BG] shouldResume=false, not reactivating")
                #endif
            }

        @unknown default:
            break
        }
    }

    // MARK: - Command handling

    private func handleCommand(_ command: RecordingCommand) {
        switch command {
        case .start:
            startRecording()
        case .stop:
            stopRecording()
        case .cancel:
            cancelRecording()
        }
    }

    // MARK: - Recording (via AVAudioEngine input tap → file)

    private func startRecording() {
        guard !isRecording else {
            #if DEBUG
            print("[Vowrite BG] startRecording() called but already recording, ignoring")
            #endif
            return
        }

        guard let format = inputFormat else {
            ipc.state = .error
            ipc.errorMessage = "Audio engine not initialized"
            #if DEBUG
            print("[Vowrite BG] startRecording() failed: no inputFormat (engine not started)")
            #endif
            // Drop any stale override the keyboard may have written before the failure.
            clearSessionMode()
            return
        }

        // F-064: Resolve one-shot Mode override (e.g., translate from keyboard arc).
        // Read once at start so a Mode change mid-session can't leak in.
        if let overrideId = ipc.sessionModeOverrideId,
           let uuid = UUID(uuidString: overrideId),
           let mode = ModeManager.shared.modes.first(where: { $0.id == uuid }) {
            sessionMode = mode
            #if DEBUG
            print("[Vowrite BG] Session mode override: \(mode.name) (isTranslation=\(mode.isTranslation), target=\(mode.targetLanguage ?? "—"))")
            #endif
        } else {
            sessionMode = nil
        }

        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent("vowrite_\(UUID().uuidString).wav")

        do {
            // Write in input node's native format (usually 48kHz Float32).
            // Whisper API accepts various audio formats — no need to downsample.
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            fileLock.lock()
            self.audioFile = file  // tap callback detects non-nil → starts writing
            fileLock.unlock()
            self.recordingURL = url
            #if DEBUG
            print("[Vowrite BG] Recording file created: \(url.lastPathComponent), format: \(format.sampleRate)Hz")
            #endif
        } catch {
            #if DEBUG
            print("[Vowrite BG] File creation failed: \(error)")
            #endif
            ipc.state = .error
            ipc.errorMessage = "Recording failed: \(error.localizedDescription)"
            return
        }

        isRecording = true
        peakRMS = 0
        recordingStartTime = Date()
        promptContext = PromptContext.capture()
        speculativePolish.warmUpConnection()
        ipc.state = .recording
        ipc.recordingDuration = 0
        ipc.audioLevel = 0

        // Duration timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let start = self.recordingStartTime else { return }
                self.ipc.recordingDuration = Date().timeIntervalSince(start)
            }
        }

        // Level timer — reads RMS calculated in the tap callback
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isRecording else { return }
                self.ipc.audioLevel = self.lastRMSLevel
            }
        }

        #if DEBUG
        print("[Vowrite BG] Recording STARTED (engine input tap routing to file)")
        #endif
    }

    private func stopRecording() {
        guard isRecording else { return }

        recordingTimer?.invalidate()
        levelTimer?.invalidate()

        let duration = ipc.recordingDuration
        let wasSilent = peakRMS < 0.01

        isRecording = false

        // Close audio file (stop writing, flush data)
        fileLock.lock()
        audioFile = nil
        fileLock.unlock()

        guard let audioURL = recordingURL else {
            // No audio file ever materialized. Treat as a silent tap and
            // silently bounce the keyboard back to standby instead of
            // showing the red-triangle error UI.
            ipc.clearResult()
            clearSessionMode()
            return
        }

        // Layer 2: Minimum duration check — block accidental taps.
        // Silent reset: user likely tapped twice by mistake.
        guard duration >= 0.5 else {
            try? FileManager.default.removeItem(at: audioURL)
            recordingURL = nil
            ipc.clearResult()
            #if DEBUG
            print("[Vowrite BG] Recording too short (\(String(format: "%.1f", duration))s), skipping")
            #endif
            clearSessionMode()
            return
        }

        // Layer 1: Pre-API silence detection — skip Whisper if no speech detected.
        // Silent reset: user said nothing, just return to standby.
        guard !wasSilent else {
            try? FileManager.default.removeItem(at: audioURL)
            recordingURL = nil
            ipc.clearResult()
            #if DEBUG
            print("[Vowrite BG] Silent recording (peakRMS=\(peakRMS)), skipping Whisper")
            #endif
            clearSessionMode()
            return
        }

        ipc.state = .processing

        // F-033: Pre-build Polish request during STT (runs in parallel)
        let modeConfig = effectiveModeConfig
        let effectivePolishEnabled = ipc.requestedAIEnabled && modeConfig.polishEnabled
        if effectivePolishEnabled {
            speculativePolish.prepare(modeConfig: modeConfig, promptContext: promptContext)
        }

        #if DEBUG
        print("[Vowrite BG] Recording stopped (\(String(format: "%.1f", duration))s, peakRMS=\(peakRMS)), processing...")
        #endif

        processAudio(url: audioURL, duration: duration)
    }

    private func cancelRecording() {
        recordingTimer?.invalidate()
        levelTimer?.invalidate()

        // Close audio file
        fileLock.lock()
        audioFile = nil
        fileLock.unlock()

        // Clean up temp file
        if let url = recordingURL { try? FileManager.default.removeItem(at: url) }
        recordingURL = nil
        isRecording = false
        promptContext = nil
        speculativePolish.reset()
        ipc.clearResult()
        clearSessionMode()

        #if DEBUG
        print("[Vowrite BG] Recording cancelled")
        #endif

        if pendingAutoDeactivation {
            pendingAutoDeactivation = false
            performAutoDeactivation()
        }
    }

    // MARK: - Audio Level (RMS from engine tap buffer)

    /// Calculate RMS level from audio buffer for waveform display.
    /// Called on the audio render thread from the input tap callback.
    /// Ref: https://github.com/Picovoice/ios-voice-processor
    private nonisolated func calculateRMS(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }

        var sum: Float = 0
        let data = channelData[0] // channel 0
        for i in 0..<frameLength {
            let sample = data[i]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frameLength))
        // Amplify for UI visibility (speech RMS is typically 0.01-0.1)
        return min(rms * 5.0, 1.0)
    }

    // MARK: - Processing

    private func processAudio(url: URL, duration: TimeInterval) {
        Task {
            do {
                // Read keyboard's requested config
                let aiEnabled = ipc.requestedAIEnabled

                // Load mode config (honors F-064 one-shot override),
                // applying keyboard's style override if set.
                // Translation modes ignore the style override — they have a
                // dedicated prompt path that doesn't consume OutputStyle.
                var modeConfig = effectiveModeConfig
                if !modeConfig.isTranslation,
                   let styleName = self.ipc.requestedStyleName,
                   let styleId = OutputStyleManager.styleId(forName: styleName),
                   styleId != modeConfig.outputStyleId {
                    modeConfig = modeConfig.withStyleOverride(styleId)
                }

                // Check API setup
                let sttConfig = APIConfig.stt
                if !sttConfig.provider.hasSTTSupport {
                    ipc.state = .error
                    ipc.errorMessage = "\(sttConfig.provider.rawValue) doesn't support STT"
                    clearSessionMode()
                    return
                }
                if sttConfig.requiresAPIKey && sttConfig.key == nil {
                    ipc.state = .error
                    ipc.errorMessage = "Missing \(sttConfig.provider.rawValue) API Key"
                    clearSessionMode()
                    return
                }

                // Step 1: STT
                let whisperLanguage: String?
                if let modeLang = modeConfig.language,
                   let lang = SupportedLanguage(rawValue: modeLang) {
                    whisperLanguage = lang.whisperCode
                } else {
                    whisperLanguage = LanguageConfig.globalLanguage.whisperCode
                }
                let vocabPrompt = VocabularyManager.whisperPrompt
                let rawTranscript = try await whisperService.transcribe(audioURL: url, language: whisperLanguage, prompt: vocabPrompt)

                guard !rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    // STT returned empty → user said nothing meaningful.
                    // Silent reset back to standby.
                    ipc.clearResult()
                    clearSessionMode()
                    return
                }

                // Layer 3: Post-transcription hallucination filter
                guard !HallucinationFilter.isHallucination(rawTranscript) else {
                    #if DEBUG
                    print("[Vowrite BG] Hallucination filtered: <redacted>")
                    #endif
                    // Hallucination = noise/silence misinterpreted by STT.
                    // Silent reset, same UX as raw silence.
                    ipc.clearResult()
                    clearSessionMode()
                    return
                }

                // Step 1.5: F-051 — Apply text replacement rules after STT
                let correctedTranscript = ReplacementManager.apply(to: rawTranscript)

                // Step 2: AI Polish (F-033: uses speculative pre-built request)
                var finalText = correctedTranscript
                let effectivePolishEnabled = aiEnabled && modeConfig.polishEnabled
                if effectivePolishEnabled {
                    let polishConfig = APIConfig.polish
                    if polishConfig.requiresAPIKey && polishConfig.key == nil {
                        // Skip polish, use raw
                    } else {
                        do {
                            let polished = try await speculativePolish.execute(
                                transcript: correctedTranscript,
                                modeConfig: modeConfig,
                                promptContext: promptContext
                            )
                            // F-051: Apply replacement rules again after LLM
                            finalText = ReplacementManager.apply(to: polished)
                        } catch {
                            #if DEBUG
                            print("[Vowrite BG] Polish failed, using corrected: \(error)")
                            #endif
                        }
                    }
                }

                ipc.result = finalText
                ipc.state = .done

                // Save pending record for history
                let record = PendingRecord(
                    rawTranscript: rawTranscript,
                    polishedText: finalText,
                    duration: duration
                )
                PendingRecordStore.save(record)

                // Update stats
                let wordCount = finalText.split(separator: " ").count + finalText.split(separator: "\u{3000}").count
                let totalTime = VowriteStorage.defaults.double(forKey: "totalDictationTime") + duration
                let totalWords = VowriteStorage.defaults.integer(forKey: "totalWords") + wordCount
                let totalDictations = VowriteStorage.defaults.integer(forKey: "totalDictations") + 1
                VowriteStorage.defaults.set(totalTime, forKey: "totalDictationTime")
                VowriteStorage.defaults.set(totalWords, forKey: "totalWords")
                VowriteStorage.defaults.set(totalDictations, forKey: "totalDictations")

                // Clean up
                speculativePolish.reset()
                promptContext = nil
                clearSessionMode()
                try? FileManager.default.removeItem(at: url)

                #if DEBUG
                print("[Vowrite BG] Processing complete")
                #endif

            } catch {
                #if DEBUG
                print("[Vowrite BG] Processing error: \(error)")
                #endif
                ipc.state = .error
                let desc = error.localizedDescription
                ipc.errorMessage = desc.count > 80 ? String(desc.prefix(80)) + "..." : desc
                clearSessionMode()
            }

            if pendingAutoDeactivation {
                pendingAutoDeactivation = false
                performAutoDeactivation()
            }
        }
    }
}
