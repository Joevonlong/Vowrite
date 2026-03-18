import SwiftUI
import SwiftData
import Combine

enum VowriteState: Equatable {
    case idle
    case recording
    case processing
    case error(String)
}

@MainActor
final class AppState: ObservableObject {
    @Published var state: VowriteState = .idle
    @Published var audioLevel: Float = 0
    @Published var recordingDuration: TimeInterval = 0
    @Published var lastResult: String?
    @Published var lastRawTranscript: String?

    let modelContainer: ModelContainer
    private let audioEngine = AudioEngine()
    private let whisperService = WhisperService()
    private let aiPolishService = AIPolishService()
    private let textInjector = TextInjector()
    let hotkeyManager = HotkeyManager()

    private var recordingTimer: Timer?
    private var levelTimer: Timer?
    private var escGlobalMonitor: Any?
    private var escLocalMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    var menuBarIcon: String {
        switch state {
        case .idle: return "mic"
        case .recording: return "mic.fill"
        case .processing: return "ellipsis.circle"
        case .error: return "exclamationmark.triangle"
        }
    }

    var isRecording: Bool { state == .recording }

    // MARK: Stats
    var totalDictationTime: TimeInterval {
        UserDefaults.standard.double(forKey: "totalDictationTime")
    }
    var totalWords: Int {
        UserDefaults.standard.integer(forKey: "totalWords")
    }
    var totalDictations: Int {
        UserDefaults.standard.integer(forKey: "totalDictations")
    }

    private func updateStats(duration: TimeInterval, text: String) {
        let wordCount = text.split(separator: " ").count + text.split(separator: "\u{3000}").count
        UserDefaults.standard.set(totalDictationTime + duration, forKey: "totalDictationTime")
        UserDefaults.standard.set(totalWords + wordCount, forKey: "totalWords")
        UserDefaults.standard.set(totalDictations + 1, forKey: "totalDictations")
        objectWillChange.send()
    }

    var hasAPIKey: Bool {
        isReadyForCurrentMode
    }

    init() {
        APIConfigMigration.runIfNeeded()

        do {
            let schema = Schema([DictationRecord.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        setupHotkey()
        AppStateHolder.shared = self
    }

    private func setupHotkey() {
        hotkeyManager.onToggle = { [weak self] in
            Task { @MainActor in
                self?.toggleRecording()
            }
        }
        // F-018: Push to Talk — release stops recording
        hotkeyManager.onPushToTalkRelease = { [weak self] in
            Task { @MainActor in
                if self?.state == .recording {
                    self?.stopRecording()
                }
            }
        }
        // F-018: Mode switching via ⌃1-⌃9
        hotkeyManager.onModeSwitch = { [weak self] index in
            Task { @MainActor in
                self?.switchToMode(at: index)
            }
        }
        hotkeyManager.register()
    }

    /// F-018: Switch to mode by index (0-based)
    func switchToMode(at index: Int) {
        let modes = ModeManager.shared.modes
        guard index >= 0, index < modes.count else { return }
        ModeManager.shared.select(modes[index])
    }

    func toggleRecording() {
        switch state {
        case .idle, .error:
            startRecording()
        case .recording:
            stopRecording()
        case .processing:
            break
        }
    }

    func startRecording() {
        guard PermissionManager.hasMicrophoneAccess() else {
            PermissionManager.requestMicrophoneAccess { [weak self] granted in
                if granted {
                    Task { @MainActor in self?.startRecording() }
                }
            }
            return
        }

        // Remember which app has focus BEFORE we start (so we can paste back into it)
        textInjector.saveFrontmostApp()

        do {
            try audioEngine.startRecording()
            state = .recording
            recordingDuration = 0
            audioLevel = 0

            // Show floating overlay
            RecordingOverlayController.shared.show(appState: self)

            // Start recording sound
            NSSound(named: .init("Tink"))?.play()

            // Listen for ESC key to cancel recording (both global and local)
            let escHandler: (NSEvent) -> Void = { [weak self] event in
                if event.keyCode == 53 {
                    Task { @MainActor in
                        self?.cancelRecording()
                    }
                }
            }
            escGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: escHandler)
            escLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if event.keyCode == 53 {
                    Task { @MainActor in
                        self?.cancelRecording()
                    }
                    return nil
                }
                return event
            }

            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.recordingDuration += 0.1
                }
            }
            levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.audioLevel = self?.audioEngine.currentLevel ?? 0
                    RecordingOverlayController.shared.update()
                }
            }
        } catch {
            state = .error("录音失败，请检查麦克风权限")
        }
    }

    func stopRecording() {
        recordingTimer?.invalidate()
        levelTimer?.invalidate()
        if let m = escGlobalMonitor { NSEvent.removeMonitor(m); escGlobalMonitor = nil }
        if let m = escLocalMonitor { NSEvent.removeMonitor(m); escLocalMonitor = nil }

        guard let audioURL = audioEngine.stopRecording() else {
            state = .error("未录到音频，请重试")
            RecordingOverlayController.shared.hide()
            return
        }

        state = .processing
        // Overlay stays visible but shows "Thinking"
        RecordingOverlayController.shared.update()

        processAudio(url: audioURL)
    }

    func cancelRecording() {
        recordingTimer?.invalidate()
        levelTimer?.invalidate()
        if let m = escGlobalMonitor { NSEvent.removeMonitor(m); escGlobalMonitor = nil }
        if let m = escLocalMonitor { NSEvent.removeMonitor(m); escLocalMonitor = nil }
        _ = audioEngine.stopRecording()
        state = .idle
        RecordingOverlayController.shared.hide()
        NSSound(named: .init("Basso"))?.play()
    }

    private func processAudio(url: URL) {
        Task {
            do {
                // Load current mode config
                let modeConfig = ModeManager.currentModeConfig

                if let setupError = setupErrorMessage(for: modeConfig) {
                    state = .error(setupError)
                    RecordingOverlayController.shared.hide()
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
                    RecordingOverlayController.shared.hide()
                    return
                }

                // Step 2: AI Polish (skip if mode has polishEnabled=false)
                var finalText = rawTranscript
                if modeConfig.polishEnabled {
                    do {
                        #if DEBUG
                        print("[Vowrite] Starting AI polish...")
                        #endif
                        let polished = try await aiPolishService.polish(text: rawTranscript, modeConfig: modeConfig)
                        finalText = polished
                        #if DEBUG
                        print("[Vowrite] Polish result: '\(polished)'")
                        #endif
                    } catch {
                        #if DEBUG
                        print("[Vowrite] Polish failed (using raw transcript): \(error)")
                        #endif
                    }
                } else {
                    #if DEBUG
                    print("[Vowrite] Polish skipped (Dictation mode)")
                    #endif
                }
                lastResult = finalText

                // Step 3: Hide overlay
                RecordingOverlayController.shared.hide()

                // Step 4: Activate the previous app and inject text
                if modeConfig.autoPaste {
                    textInjector.inject(text: finalText)
                }

                // Step 5: Save to history
                let record = DictationRecord(
                    rawTranscript: rawTranscript,
                    polishedText: finalText,
                    duration: recordingDuration,
                    detectedLanguage: nil
                )
                let context = modelContainer.mainContext
                context.insert(record)
                try context.save()

                // Step 6: Update stats
                updateStats(duration: recordingDuration, text: finalText)

                // Step 7: Success feedback
                NSSound(named: .init("Tink"))?.play()
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
                state = .error(message)
                RecordingOverlayController.shared.hide()
                NSSound(named: .init("Basso"))?.play()
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
}
