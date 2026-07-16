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
        KimiBaseURLRepairMigration.runIfNeeded()

        let schema = Schema([DictationRecord.self])
        let primary = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        if let container = try? ModelContainer(for: schema, configurations: [primary]) {
            modelContainer = container
        } else {
            // Fallback to in-memory store so the app still boots; HistoryView shows a banner.
            let inMemory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                modelContainer = try ModelContainer(for: schema, configurations: [inMemory])
            } catch {
                fatalError("In-memory model container failed to initialize: \(error)")
            }
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

        // BUG-017: any polish/translate failure that fell back to the raw
        // transcript must be visibly surfaced, not just noted in the menu-bar
        // dropdown text (which the user has to open to ever see). Reuses the
        // toast facility introduced for F-053's vocabulary-learned
        // notification (`CorrectionMonitor`/`ToastPresenter`) so the warning
        // shows near paste time without stealing focus. `engine.$state`
        // already carries `.error` for this case (menu-bar behavior is
        // unchanged) — `polishWarning` is a narrower signal so this toast
        // fires only for the polish/translate-fallback case, not every hard
        // failure (STT/API errors etc.), which already has its own
        // "nothing was pasted yet" context and doesn't need a toast.
        engine.$polishWarning
            .compactMap { $0 }
            .sink { message in
                ToastPresenter.show("⚠️ \(message)")
            }
            .store(in: &cancellables)

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
            do {
                try context.save()
            } catch {
                Log.history.error("Failed to save DictationRecord: \(error.localizedDescription, privacy: .public)")
            }
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
        // F-081: this is a manual Mode switch — note it so a per-app mapping
        // doesn't immediately overwrite the user's explicit pick on the next
        // recording (see PerAppModeManager.noteManualModeSwitch).
        hotkeyManager.onModeSwitch = { [weak self] index in
            Task { @MainActor in
                self?.engine.switchToMode(at: index)
                PerAppModeManager.shared.noteManualModeSwitch()
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

    func toggleRecording() {
        // F-081: only resolve/apply a per-app mapping right before an actual
        // "start" — mirrors DictationEngine.toggleRecording()'s own switch so
        // we don't waste a mapping resolution (or worse, stomp a mid-flight
        // sessionModeOverride) on what's really a "stop" tap.
        switch engine.state {
        case .idle, .error:
            applyPerAppModeOverrideIfNeeded()
        case .recording, .processing:
            break
        }
        engine.toggleRecording()
    }
    func startRecording() { engine.startRecording() }
    func stopRecording() { engine.stopRecording() }
    func cancelRecording() { engine.cancelRecording() }

    /// F-081: Normal hotkey path only — resolve whether the frontmost app
    /// has a per-app Mode mapping and, if so, apply it as this session's
    /// oneshot override via the same seam F-063 uses for translate. Reads
    /// `NSWorkspace.frontmostApplication` synchronously here (not inside
    /// `DictationEngine`, which is cross-platform Kit code and can't import
    /// AppKit) — at this point in the call stack nothing has run yet that
    /// could steal focus, so it's equivalent to reading it at the top of
    /// `engine.startRecording()` alongside `PromptContext.capture()`.
    private func applyPerAppModeOverrideIfNeeded() {
        guard let modeId = PerAppModeManager.shared.resolveSessionOverride(isTranslateSession: false),
              let mode = ModeManager.shared.modes.first(where: { $0.id == modeId }) else { return }
        engine.setSessionModeOverride(mode)
    }

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
