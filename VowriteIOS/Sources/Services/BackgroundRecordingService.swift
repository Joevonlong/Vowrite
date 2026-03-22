import AVFoundation
import SwiftUI
import VowriteKit

/// Main App background recording service.
/// Listens for commands from keyboard extension via Darwin Notifications,
/// records audio, processes STT + AI polish, and writes results back via IPC.
///
/// Architecture: The keyboard extension is a remote control only.
/// All recording happens here in the main app process.
///
/// Audio strategy (based on Apple docs & production patterns):
/// - AVAudioEngine with persistent input tap (started in foreground, runs in background)
/// - Silent AVAudioPlayer for UIBackgroundModes: audio keep-alive
/// - Recording = routing existing engine input data to file (not starting new recording)
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

    private let ipc = BackgroundRecordingIPC.shared
    private let whisperService = WhisperService()
    private let aiPolishService = AIPolishService()

    // MARK: - Audio Engine (replaces AVAudioRecorder)
    // AVAudioEngine with input tap keeps microphone active continuously.
    // iOS allows this in background because the engine was started in foreground.
    // "Recording" = opening a file and writing tap data (not starting new input).
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?     // non-nil = actively writing audio to file
    private var inputFormat: AVAudioFormat?
    private nonisolated(unsafe) var lastRMSLevel: Float = 0
    private let fileLock = NSLock()         // protects audioFile across audio render + main threads

    /// Silent audio player to keep the app alive in background (UIBackgroundModes: audio)
    private var silentPlayer: AVAudioPlayer?

    private var recordingTimer: Timer?
    private var levelTimer: Timer?
    private var heartbeatTimer: Timer?
    private var recordingStartTime: Date?
    private var recordingURL: URL?
    private var interruptionObserver: NSObjectProtocol?

    init() {}

    // MARK: - Activate / Deactivate

    func activate() {
        guard !isActive else {
            #if DEBUG
            print("[Vowrite BG] activate() called but already active, skipping")
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
                        self?.activate()
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
                options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers]
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

                // Calculate RMS for waveform display (only when recording)
                if self.isRecording {
                    self.lastRMSLevel = self.calculateRMS(buffer: buffer)
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

        // 4. Start silent audio loop to maintain background session (UIBackgroundModes: audio)
        startSilentAudio()

        // 5. Observe audio interruptions (phone calls, etc.)
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
        #if DEBUG
        print("[Vowrite BG] Background recording service ACTIVATED successfully")
        #endif
    }

    func deactivate() {
        guard isActive else { return }

        if isRecording {
            cancelRecording()
        }

        heartbeatTimer?.invalidate()
        heartbeatTimer = nil

        silentPlayer?.stop()
        silentPlayer = nil

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

        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif

        isActive = false
        #if DEBUG
        print("[Vowrite BG] Background recording service deactivated")
        #endif
    }

    // MARK: - Silent Audio (Background Keep-Alive)

    /// Play a silent audio loop to keep the app alive in background.
    /// This is how Typeless and similar apps maintain their background session.
    private func startSilentAudio() {
        // Generate 1 second of silence as WAV
        let sampleRate: Double = 44100
        let duration: Double = 1.0
        let numSamples = Int(sampleRate * duration)

        var header = Data()
        let dataSize = UInt32(numSamples * 2) // 16-bit mono
        let fileSize = UInt32(36 + dataSize)

        // WAV header
        header.append(contentsOf: "RIFF".utf8)
        header.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Array($0) })
        header.append(contentsOf: "WAVE".utf8)
        header.append(contentsOf: "fmt ".utf8)
        header.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) }) // chunk size
        header.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })  // PCM
        header.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })  // mono
        header.append(contentsOf: withUnsafeBytes(of: UInt32(44100).littleEndian) { Array($0) }) // sample rate
        header.append(contentsOf: withUnsafeBytes(of: UInt32(88200).littleEndian) { Array($0) }) // byte rate
        header.append(contentsOf: withUnsafeBytes(of: UInt16(2).littleEndian) { Array($0) })  // block align
        header.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Array($0) }) // bits per sample
        header.append(contentsOf: "data".utf8)
        header.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })

        // Silent samples
        header.append(Data(count: Int(dataSize)))

        do {
            let player = try AVAudioPlayer(data: header)
            player.numberOfLoops = -1 // Loop forever
            player.volume = 0.0
            player.play()
            silentPlayer = player
            #if DEBUG
            print("[Vowrite BG] Silent audio loop started for background keep-alive")
            #endif
        } catch {
            #if DEBUG
            print("[Vowrite BG] Failed to start silent audio: \(error)")
            #endif
        }
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
                    silentPlayer?.play()
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
                        self.silentPlayer?.play()
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
            return
        }

        // Do NOT stop silent player — .playAndRecord supports simultaneous play + record.
        // Silent player keeps app alive; engine input tap keeps mic active.

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
        recordingStartTime = Date()
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

    /// Ensure silent player is running for background keep-alive.
    private func resumeBackgroundKeepAlive() {
        #if os(iOS)
        if silentPlayer == nil || !(silentPlayer?.isPlaying ?? false) {
            startSilentAudio()
        }
        #if DEBUG
        print("[Vowrite BG] Background keep-alive verified")
        #endif
        #endif
    }

    private func stopRecording() {
        guard isRecording else { return }

        recordingTimer?.invalidate()
        levelTimer?.invalidate()
        isRecording = false

        let duration = ipc.recordingDuration

        // Close audio file (stop writing, flush data)
        fileLock.lock()
        audioFile = nil
        fileLock.unlock()

        guard let audioURL = recordingURL else {
            ipc.state = .error
            ipc.errorMessage = "No audio captured"
            return
        }

        ipc.state = .processing

        #if DEBUG
        print("[Vowrite BG] Recording stopped (\(String(format: "%.1f", duration))s), processing...")
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
        ipc.clearResult()

        #if DEBUG
        print("[Vowrite BG] Recording cancelled")
        #endif
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

                // Load mode config
                let modeConfig = ModeManager.currentModeConfig

                // Check API setup
                let sttConfig = APIConfig.stt
                if !sttConfig.provider.hasSTTSupport {
                    ipc.state = .error
                    ipc.errorMessage = "\(sttConfig.provider.rawValue) doesn't support STT"
                    return
                }
                if sttConfig.requiresAPIKey && sttConfig.key == nil {
                    ipc.state = .error
                    ipc.errorMessage = "Missing \(sttConfig.provider.rawValue) API Key"
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
                    ipc.state = .error
                    ipc.errorMessage = "No speech detected"
                    return
                }

                ipc.rawTranscript = rawTranscript

                // Step 2: AI Polish
                var finalText = rawTranscript
                let effectivePolishEnabled = aiEnabled && modeConfig.polishEnabled
                if effectivePolishEnabled {
                    let polishConfig = APIConfig.polish
                    if polishConfig.requiresAPIKey && polishConfig.key == nil {
                        // Skip polish, use raw
                    } else {
                        do {
                            finalText = try await aiPolishService.polish(text: rawTranscript, modeConfig: modeConfig)
                        } catch {
                            #if DEBUG
                            print("[Vowrite BG] Polish failed, using raw: \(error)")
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

                // Clean up temp file
                try? FileManager.default.removeItem(at: url)

                #if DEBUG
                print("[Vowrite BG] Processing complete: '\(finalText)'")
                #endif

            } catch {
                #if DEBUG
                print("[Vowrite BG] Processing error: \(error)")
                #endif
                ipc.state = .error
                let desc = error.localizedDescription
                ipc.errorMessage = desc.count > 80 ? String(desc.prefix(80)) + "..." : desc
            }
        }
    }
}
