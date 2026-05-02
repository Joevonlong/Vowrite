import SwiftUI
import SwiftData
import Combine
import VowriteKit

@MainActor
final class AppState: ObservableObject {
    @Published var state: VowriteState = .idle
    @Published var audioLevel: Float = 0
    @Published var recordingDuration: TimeInterval = 0
    @Published var lastResult: String?
    @Published var lastRawTranscript: String?
    @Published var historyUnavailable: Bool = false

    let modelContainer: ModelContainer
    let engine: DictationEngine
    let hotkeyManager = MacHotkeyManager()

    private var cancellables = Set<AnyCancellable>()
    private var escGlobalMonitor: Any?
    private var escLocalMonitor: Any?

    var menuBarIcon: String { engine.menuBarIcon }
    var isRecording: Bool { engine.isRecording }
    var hasAPIKey: Bool { engine.hasAPIKey }

    // MARK: Stats
    var totalDictationTime: TimeInterval { engine.totalDictationTime }
    var totalWords: Int { engine.totalWords }
    var totalDictations: Int { engine.totalDictations }

    init() {
        MiniMaxMigration.runIfNeeded()
        MiniMaxOAuthPurge.runIfNeeded()
        APIConfigMigration.runIfNeeded()
        APIConfig.migratePresetIDs()

        let schema = Schema([DictationRecord.self])
        let primary = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        if let container = try? ModelContainer(for: schema, configurations: [primary]) {
            modelContainer = container
        } else {
            // Fallback to in-memory store so the app still boots; HistoryView shows a banner.
            let inMemory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            modelContainer = try! ModelContainer(for: schema, configurations: [inMemory])
            historyUnavailable = true
        }

        let overlay = MacOverlayController.shared
        engine = DictationEngine(
            textOutput: MacTextInjector(),
            permissions: MacPermissionProvider(),
            overlay: overlay,
            feedback: MacFeedback()
        )

        // Forward engine state to AppState for views
        engine.$state.assign(to: &$state)
        engine.$audioLevel.assign(to: &$audioLevel)
        engine.$recordingDuration.assign(to: &$recordingDuration)
        engine.$lastResult.assign(to: &$lastResult)
        engine.$lastRawTranscript.assign(to: &$lastRawTranscript)

        // Wire overlay to AppState reference
        overlay.appState = self

        // Wire history save callback
        engine.onRecordComplete = { [weak self] rawTranscript, finalText, duration, wasTranslation in
            guard let self = self else { return }
            let record = DictationRecord(
                rawTranscript: rawTranscript,
                polishedText: finalText,
                duration: duration,
                detectedLanguage: nil,
                wasTranslation: wasTranslation ? true : nil
            )
            let context = self.modelContainer.mainContext
            context.insert(record)
            try? context.save()
        }

        // Wire ESC monitor for cancel on recording start/stop
        engine.$state.sink { [weak self] newState in
            guard let self = self else { return }
            if newState == .recording {
                self.installEscMonitors()
            } else {
                self.removeEscMonitors()
            }
        }.store(in: &cancellables)

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
                self?.engine.switchToMode(at: index)
            }
        }
        // F-063: Translate hotkey — start recording in Translate mode (oneshot
        // session override). Ignored if a recording is already in progress so
        // it can't accidentally clobber an active normal-dictation session.
        hotkeyManager.onTranslateToggle = { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                if self.engine.isRecording { return }
                self.engine.startTranslateRecording()
            }
        }
        hotkeyManager.register()
    }

    func toggleRecording() { engine.toggleRecording() }
    func startRecording() { engine.startRecording() }
    func stopRecording() { engine.stopRecording() }
    func cancelRecording() { engine.cancelRecording() }

    // MARK: - ESC monitors

    private func installEscMonitors() {
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
    }

    private func removeEscMonitors() {
        if let m = escGlobalMonitor { NSEvent.removeMonitor(m); escGlobalMonitor = nil }
        if let m = escLocalMonitor { NSEvent.removeMonitor(m); escLocalMonitor = nil }
    }
}
