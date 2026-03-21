import SwiftUI
import VowriteKit

@MainActor
final class KeyboardState: ObservableObject {
    // UI state
    @Published var viewState: ViewState = .idle
    @Published var audioLevel: Float = 0
    @Published var recordingDuration: TimeInterval = 0
    @Published var processingStage: ProcessingStage = .stt

    // Configuration state
    @Published var currentMode: Mode = Mode.builtinModes[1] // Clean
    @Published var modes: [Mode] = Mode.builtinModes
    @Published var styles: [OutputStyle] = OutputStyle.builtinStyles
    @Published var aiEnabled: Bool = true
    @Published var currentStyleName: String = "Default"
    @Published var hasFullAccess: Bool = false
    @Published var isConfigured: Bool = false

    // Engine
    let engine: DictationEngine
    private var textOutput: KeyboardTextOutput
    weak var inputViewController: UIInputViewController?

    enum ViewState: Equatable {
        case idle, recording, processing, error(String), noFullAccess, noAPIKey
    }

    enum ProcessingStage {
        case stt, polish
    }

    init(inputViewController: UIInputViewController) {
        self.inputViewController = inputViewController
        self.textOutput = KeyboardTextOutput(proxy: inputViewController.textDocumentProxy)

        self.engine = DictationEngine(
            textOutput: textOutput,
            permissions: KeyboardPermissionProvider(),
            overlay: KeyboardOverlayProvider(),
            feedback: KeyboardFeedback()
        )

        // Force auto-paste in keyboard (inserting text is the whole point)
        engine.forceAutoPaste = true

        // Save pending records instead of writing SwiftData directly
        engine.onRecordComplete = { rawTranscript, finalText, duration in
            let record = PendingRecord(
                rawTranscript: rawTranscript,
                polishedText: finalText,
                duration: duration
            )
            PendingRecordStore.save(record)
        }

        // Forward engine state
        engine.$state.receive(on: RunLoop.main).sink { [weak self] state in
            guard let self else { return }
            switch state {
            case .idle: self.viewState = self.hasFullAccess ? (self.isConfigured ? .idle : .noAPIKey) : .noFullAccess
            case .recording: self.viewState = .recording
            case .processing: self.viewState = .processing
            case .error(let msg): self.viewState = .error(msg)
            }
        }.store(in: &cancellables)

        engine.$audioLevel.receive(on: RunLoop.main).assign(to: &$audioLevel)
        engine.$recordingDuration.receive(on: RunLoop.main).assign(to: &$recordingDuration)

        reloadConfiguration()
    }

    private var cancellables = Set<AnyCancellable>()

    func reloadConfiguration() {
        hasFullAccess = inputViewController?.hasFullAccess ?? false

        if !hasFullAccess {
            viewState = .noFullAccess
            return
        }

        // Reload all Managers
        let modeManager = ModeManager.shared
        modeManager.reload()
        OutputStyleManager.shared.reload()
        VocabularyManager.shared.reload()

        modes = modeManager.modes
        styles = OutputStyleManager.shared.styles
        currentMode = modeManager.currentMode
        aiEnabled = currentMode.polishEnabled

        if let styleId = currentMode.outputStyleId {
            currentStyleName = styles.first { $0.id == styleId }?.name ?? "Default"
        } else {
            currentStyleName = "Default"
        }

        isConfigured = engine.hasAPIKey

        if !isConfigured {
            viewState = .noAPIKey
            return
        }

        viewState = .idle
    }

    func updateProxy(_ proxy: UITextDocumentProxy) {
        textOutput.proxy = proxy
    }

    func switchMode(to mode: Mode) {
        ModeManager.shared.select(mode)
        currentMode = mode
        aiEnabled = mode.polishEnabled
        if let styleId = mode.outputStyleId {
            currentStyleName = styles.first { $0.id == styleId }?.name ?? "Default"
        } else {
            currentStyleName = "Default"
        }
    }

    func toggleAI() {
        aiEnabled.toggle()
        // Temporary state, not persisted. Resets to Mode default when keyboard reopens.
    }

    func startRecording() {
        // Memory check
        if MemoryMonitor.isUnderPressure {
            aiEnabled = false  // Force downgrade
        }
        engine.polishEnabledOverride = aiEnabled ? nil : false
        engine.startRecording()
    }

    func stopRecording() {
        engine.stopRecording()
    }

    func cancelRecording() {
        engine.cancelRecording()
    }

    func advanceToNextKeyboard() {
        inputViewController?.advanceToNextInputMode()
    }

    // Bottom bar actions
    func insertSpace() {
        inputViewController?.textDocumentProxy.insertText(" ")
    }

    func insertReturn() {
        inputViewController?.textDocumentProxy.insertText("\n")
    }

    func deleteBackward() {
        inputViewController?.textDocumentProxy.deleteBackward()
    }
}

import Combine
