import SwiftUI
import Combine
import AVFoundation
import VowriteKit

@MainActor
final class KeyboardState: ObservableObject {
    // UI state
    @Published var viewState: ViewState = .idle
    @Published var audioLevel: Float = 0
    @Published var recordingDuration: TimeInterval = 0
    @Published var showGlobe: Bool = true
    /// True when background service is not active and user needs to activate it.
    /// The orb is still shown but with a different label ("点击激活").
    @Published var needsActivation: Bool = false

    // Configuration state
    @Published var currentMode: Mode = Mode.builtinModes[1] // Clean
    @Published var modes: [Mode] = Mode.builtinModes
    @Published var styles: [OutputStyle] = OutputStyle.builtinStyles
    @Published var aiEnabled: Bool = true
    @Published var currentStyleName: String = "Default"
    @Published var hasFullAccess: Bool = false
    @Published var isConfigured: Bool = false

    // IPC
    private let ipc = BackgroundRecordingIPC.shared
    private var pollTimer: Timer?
    private var serviceCheckTimer: Timer?

    weak var inputViewController: UIInputViewController?

    enum ViewState: Equatable {
        case idle, recording, processing, error(String)
        case noFullAccess, noAPIKey, noMicAccess, bgServiceNotRunning
    }

    init(inputViewController: UIInputViewController) {
        self.inputViewController = inputViewController
        reloadConfiguration()
        startServiceCheckTimer()
    }

    deinit {
        serviceCheckTimer?.invalidate()
    }

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

        // Check API config
        let sttConfig = APIConfig.stt
        isConfigured = sttConfig.provider.hasSTTSupport && (sttConfig.key != nil || !sttConfig.requiresAPIKey)

        if !isConfigured {
            viewState = .noAPIKey
            return
        }

        // Check if background service is running — sets flag but doesn't block the orb
        needsActivation = !ipc.isServiceAlive

        viewState = .idle
    }

    func updateProxy(_ proxy: UITextDocumentProxy) {
        // Keep reference for text insertion via inputViewController
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
        // Write requested mode to IPC so main app picks it up
        ipc.requestedModeId = mode.id.uuidString
    }

    func toggleAI() {
        aiEnabled.toggle()
        ipc.requestedAIEnabled = aiEnabled
    }

    // MARK: - Recording via IPC

    func startRecording() {
        // Check if background service is alive — auto-jump to activate if not
        if !ipc.isServiceAlive {
            #if DEBUG
            print("[Vowrite KB] startRecording: bg service not alive, auto-jumping to container app for activation")
            #endif
            openContainerApp(path: "activate")
            return
        }

        #if DEBUG
        print("[Vowrite KB] startRecording: service alive, sending .start command")
        print("[Vowrite KB]   mode=\(currentMode.name), aiEnabled=\(aiEnabled)")
        #endif

        // Write config for main app
        ipc.requestedAIEnabled = aiEnabled
        ipc.requestedModeId = currentMode.id.uuidString

        // Send start command
        ipc.sendCommand(.start)
        viewState = .recording
        audioLevel = 0
        recordingDuration = 0

        // Start polling IPC state
        startPolling()
    }

    func stopRecording() {
        ipc.sendCommand(.stop)
        // Polling will pick up state change
    }

    func cancelRecording() {
        ipc.sendCommand(.cancel)
        stopPolling()
        viewState = .idle
    }

    // MARK: - Service Alive Check

    /// Periodically re-check if the background service is alive,
    /// so the UI updates when the user activates it via deep link and returns.
    private func startServiceCheckTimer() {
        serviceCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let alive = self.ipc.isServiceAlive
                if self.needsActivation && alive {
                    #if DEBUG
                    print("[Vowrite KB] Background service detected alive, clearing needsActivation")
                    #endif
                    self.needsActivation = false
                } else if !self.needsActivation && !alive && self.viewState == .idle {
                    #if DEBUG
                    print("[Vowrite KB] Background service heartbeat lost")
                    #endif
                    self.needsActivation = true
                }
            }
        }
    }

    // MARK: - IPC Polling

    private func startPolling() {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollIPCState()
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func pollIPCState() {
        let ipcState = ipc.state

        switch ipcState {
        case .idle:
            // If we were recording/processing and now idle, it was cancelled
            if viewState == .recording || viewState == .processing {
                viewState = .idle
                stopPolling()
            }

        case .recording:
            viewState = .recording
            audioLevel = ipc.audioLevel
            recordingDuration = ipc.recordingDuration

        case .processing:
            viewState = .processing

        case .done:
            if let result = ipc.result, !result.isEmpty {
                inputViewController?.textDocumentProxy.insertText(result)
            }
            ipc.clearResult()
            stopPolling()
            viewState = .idle

        case .error:
            let message = ipc.errorMessage ?? "Unknown error"
            viewState = .error(message)
            ipc.clearResult()
            stopPolling()
        }
    }

    // MARK: - Keyboard actions

    func advanceToNextKeyboard() {
        inputViewController?.advanceToNextInputMode()
    }

    /// Returns the UIInputViewController for UIKit globe button integration
    var viewController: UIInputViewController? {
        inputViewController
    }

    func insertSpace() {
        inputViewController?.textDocumentProxy.insertText(" ")
    }

    func insertReturn() {
        inputViewController?.textDocumentProxy.insertText("\n")
    }

    func deleteBackward() {
        inputViewController?.textDocumentProxy.deleteBackward()
    }

    func insertText(_ text: String) {
        inputViewController?.textDocumentProxy.insertText(text)
    }

    func dismissKeyboard() {
        inputViewController?.dismissKeyboard()
    }

    // MARK: - Container App Deep Link

    /// Open the container app via URL scheme.
    /// Used for auto-activation when service is not alive.
    func openContainerApp(path: String = "activate") {
        guard let url = URL(string: "vowrite://\(path)") else { return }
        let selectorModern = NSSelectorFromString("open:options:completionHandler:")
        let selectorLegacy = NSSelectorFromString("openURL:")
        var responder: UIResponder? = inputViewController
        while let r = responder {
            if r.responds(to: selectorModern) {
                r.perform(selectorModern, with: url, with: NSDictionary())
                return
            }
            if r.responds(to: selectorLegacy) {
                r.perform(selectorLegacy, with: url)
                return
            }
            responder = r.next
        }
    }
}
