import SwiftUI
import SwiftData
import Combine

enum VoxaState: Equatable {
    case idle
    case recording
    case processing
    case error(String)
}

@MainActor
final class AppState: ObservableObject {
    @Published var state: VoxaState = .idle
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
        guard let key = KeychainHelper.getAPIKey() else { return false }
        return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init() {
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
        hotkeyManager.register()
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

        // Remember which app has focus BEFORE we start (so we can paste back to it)
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
            state = .error("Recording failed: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        recordingTimer?.invalidate()
        levelTimer?.invalidate()

        guard let audioURL = audioEngine.stopRecording() else {
            state = .error("No audio recorded")
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
        _ = audioEngine.stopRecording()
        state = .idle
        RecordingOverlayController.shared.hide()
        NSSound(named: .init("Basso"))?.play()
    }

    private func processAudio(url: URL) {
        Task {
            do {
                let apiKey = KeychainHelper.getAPIKey() ?? ""
                guard !apiKey.isEmpty else {
                    state = .error("No API key set.")
                    RecordingOverlayController.shared.hide()
                    return
                }

                // Step 1: Whisper STT
                print("[Voxa] Starting STT transcription...")
                let rawTranscript = try await whisperService.transcribe(audioURL: url, apiKey: apiKey)
                lastRawTranscript = rawTranscript
                print("[Voxa] STT result: '\(rawTranscript)'")

                guard !rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    state = .error("No speech detected")
                    RecordingOverlayController.shared.hide()
                    return
                }

                // Step 2: AI Polish (graceful fallback to raw text on failure)
                var finalText = rawTranscript
                do {
                    print("[Voxa] Starting AI polish...")
                    let polished = try await aiPolishService.polish(text: rawTranscript, apiKey: apiKey)
                    finalText = polished
                    print("[Voxa] Polish result: '\(polished)'")
                } catch {
                    print("[Voxa] Polish failed (using raw transcript): \(error)")
                }
                lastResult = finalText

                // Step 3: Hide overlay
                RecordingOverlayController.shared.hide()

                // Step 4: Wait for focus to return to the previous app
                try await Task.sleep(nanoseconds: 300_000_000) // 300ms

                // Step 5: Activate the previous app and inject text
                textInjector.inject(text: finalText)

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
                state = .error(error.localizedDescription)
                RecordingOverlayController.shared.hide()
                NSSound(named: .init("Basso"))?.play()
            }
        }
    }
}
