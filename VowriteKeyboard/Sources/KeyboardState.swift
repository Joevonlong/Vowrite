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
    /// True when background service is not active and user needs to activate it.
    /// The orb is still shown but with a different label ("点击激活").
    @Published var needsActivation: Bool = false

    /// F-064: Set to true while a translate-mode recording is active. Drives
    /// the "Translating to {language}" banner in the recording view. Cleared
    /// when the recording lifecycle ends (done / error / cancel).
    @Published var isInTranslateSession: Bool = false
    /// F-064: Language code of the active translation target
    /// (SupportedLanguage rawValue, e.g. "en", "zh"). Set at the moment the
    /// user commits to the translate arc; reset when the session ends. The
    /// banner localises this on render through `Locale.current` — the speaker
    /// must read the prompt in their own language, not in the target language
    /// they can't read.
    @Published var translationTargetCode: String = ""
    /// F-064: True while the long-press 口述/翻译 selection arcs are visible.
    /// Owned by RecordArea, mirrored here so KeyboardView can hide the TopBar
    /// during the selection gesture (matching the design mockup).
    @Published var isModeSelectionExpanded: Bool = false

    // F-071: Input mode toggle
    @Published var inputMode: InputMode = .voice
    @Published var keyboardLayout: KeyboardLayout = .letters
    @Published var keyboardShift: ShiftMode = .off

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
    /// Timestamp when the last .start command was sent, used to ignore stale .idle
    /// IPC reads during the cross-process notification delivery window.
    private var startCommandSentAt: Date?
    /// The id this keyboard minted for the session it believes is currently
    /// in flight (nil when idle). Mirrored to `ipc.keyboardSessionId` so a
    /// recycled `KeyboardState` instance can recover it in
    /// `reloadConfiguration()`. Compared against `ipc.activeSessionId` (the
    /// service's echo) to detect stale/foreign reads — see `IPCReconciler`.
    private var currentSessionId: String?

    weak var inputViewController: UIInputViewController?

    /// SwiftUI openURL action, injected from KeyboardView.
    /// Used as the primary URL-opening strategy (works on iOS 18+).
    var openURLAction: OpenURLAction?

    enum ViewState: Equatable {
        case idle, recording, processing, error(String)
        case noFullAccess, noAPIKey, noMicAccess, bgServiceNotRunning
    }

    enum InputMode: Equatable { case voice, keyboard }
    enum KeyboardLayout: Equatable { case letters, numbers, symbols }
    enum ShiftMode: Equatable { case off, shift, capsLock }

    init(inputViewController: UIInputViewController) {
        self.inputViewController = inputViewController
        reloadConfiguration()
        startServiceCheckTimer()
    }

    deinit {
        serviceCheckTimer?.invalidate()
        pollTimer?.invalidate()
    }

    func reloadConfiguration() {
        // F-071: Always reset input mode on each keyboard activation
        inputMode = .voice
        keyboardLayout = .letters
        keyboardShift = .off

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
        ReplacementManager.shared.reload()

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
        let serviceAlive = ipc.isServiceAlive
        needsActivation = !serviceAlive

        // Reconcile against whatever ipc.state actually is instead of
        // defaulting straight to idle — a previous instance of this keyboard
        // (or this same instance, reappearing after the user switched apps)
        // may have a recording genuinely still in flight, or may have left a
        // stale .done/.error sitting in App Group storage from a session
        // that already ended while the keyboard was gone. See IPCReconciler.
        currentSessionId = ipc.keyboardSessionId
        let sessionMatches = currentSessionId != nil && ipc.activeSessionId == currentSessionId

        switch IPCReconciler.action(state: ipc.state, sessionMatches: sessionMatches, serviceAlive: serviceAlive) {
        case .adopt(.recording):
            viewState = .recording
            audioLevel = ipc.audioLevel
            recordingDuration = ipc.recordingDuration
            startCommandSentAt = nil
            startPolling()

        case .adopt(.processing):
            viewState = .processing
            startCommandSentAt = nil
            startPolling()

        case .adopt:
            // .adopt only ever carries .recording/.processing (see
            // IPCReconciler.action); unreachable in practice.
            viewState = .idle

        case .none:
            viewState = .idle

        case .insertResultAndGoIdle, .surfaceErrorAndGoIdle, .discardAndGoIdle, .serviceDied:
            // Reload never inserts text or surfaces an error, even for a
            // matching .done/.error — the keyboard just appeared fresh, and
            // the host app context it would insert into may no longer be the
            // one the user intended. Discard silently and land idle.
            ipc.clearResult()
            clearSessionTracking()
            viewState = .idle
        }
    }

    /// Clear both the in-memory and persisted keyboard-owned session id.
    /// Called whenever the keyboard determines there is no session it should
    /// keep tracking (normal completion, error, cancel, or a stale/foreign
    /// read discarded at reload or during polling).
    private func clearSessionTracking() {
        currentSessionId = nil
        ipc.keyboardSessionId = nil
    }

    func updateProxy(_ proxy: UITextDocumentProxy) {
        // Keep reference for text insertion via inputViewController
    }

    func switchMode(to mode: Mode) {
        ModeManager.shared.select(mode)
        currentMode = mode
        aiEnabled = mode.polishEnabled
        if let styleId = mode.outputStyleId {
            currentStyleName = styles.first { $0.id == styleId }?.name ?? "None"
        } else {
            currentStyleName = "None"
        }
        // Write requested mode to IPC so main app picks it up
        ipc.requestedModeId = mode.id.uuidString
        // Reset style override when switching mode (use mode's default style)
        ipc.requestedStyleName = nil
    }

    func selectStyle(_ style: OutputStyle) {
        currentStyleName = style.name
        ipc.requestedStyleName = style.name
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

        // Memory pressure check — auto-downgrade AI if keyboard is running low
        var effectiveAI = aiEnabled
        if MemoryMonitor.isUnderPressure {
            effectiveAI = false
            #if DEBUG
            print("[Vowrite KB] Memory pressure (\(String(format: "%.1f", MemoryMonitor.residentSizeMB))MB), disabling AI polish for this recording")
            #endif
        }

        #if DEBUG
        print("[Vowrite KB] startRecording: service alive, sending .start command")
        print("[Vowrite KB]   mode=\(currentMode.name), aiEnabled=\(effectiveAI), style=\(currentStyleName)")
        #endif

        // Write config for main app
        ipc.requestedAIEnabled = effectiveAI
        ipc.requestedModeId = currentMode.id.uuidString
        ipc.requestedStyleName = currentStyleName

        // Mint this session's identity before sending .start so the service
        // can echo it back on every subsequent state/result write.
        beginNewSession()

        // Send start command
        ipc.sendCommand(.start)
        startCommandSentAt = Date()
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
        startCommandSentAt = nil
        viewState = .idle
        clearTranslateSession()
        clearSessionTracking()
    }

    /// Mint a fresh session id for the recording about to start, remember it
    /// as this keyboard's own current session (in-memory + persisted so a
    /// recycled keyboard instance can recover it), and hand it to the
    /// service via `ipc.requestedSessionId`. See `IPCReconciler`.
    private func beginNewSession() {
        let sessionId = UUID().uuidString
        currentSessionId = sessionId
        ipc.keyboardSessionId = sessionId
        ipc.requestedSessionId = sessionId
    }

    /// Called by `KeyboardViewController.viewWillDisappear` when the keyboard
    /// UI is about to go away (user dismissed the keyboard, switched apps,
    /// tapped into another field's keyboard, etc). There is no legitimate
    /// "keep recording while the keyboard UI is gone" flow — the controlling
    /// UI just disappeared — so an in-flight recording is cancelled here
    /// rather than left to keep the mic hot indefinitely.
    func viewWillDisappear() {
        guard viewState == .recording else { return }
        cancelRecording()
    }

    // MARK: - F-064 Translate Recording

    /// Start a one-shot translate-mode recording without changing the user's
    /// persisted Mode. Mirrors `startRecording()` but writes
    /// `ipc.sessionModeOverrideId` so the BG service swaps in the builtin
    /// Translate mode for this session only.
    func startTranslateRecording() {
        if !ipc.isServiceAlive {
            #if DEBUG
            print("[Vowrite KB] startTranslateRecording: bg service not alive, jumping to activate")
            #endif
            openContainerApp(path: "activate")
            return
        }

        guard let translateMode = modes.first(where: { $0.isTranslation }) else {
            #if DEBUG
            print("[Vowrite KB] startTranslateRecording: no translation Mode found")
            #endif
            viewState = .error("Translate mode not configured")
            return
        }

        let targetCode = translateMode.targetLanguage ?? "en"

        // Translation always needs LLM polish — force-enable for this session
        // even if the keyboard's currentMode has AI off, since memory pressure
        // affects the keyboard process only and polish runs in the main app.
        ipc.requestedAIEnabled = true
        ipc.requestedModeId = translateMode.id.uuidString
        ipc.requestedStyleName = nil
        ipc.sessionModeOverrideId = translateMode.id.uuidString

        translationTargetCode = targetCode
        isInTranslateSession = true

        // Mint this session's identity before sending .start so the service
        // can echo it back on every subsequent state/result write.
        beginNewSession()

        ipc.sendCommand(.start)
        startCommandSentAt = Date()
        viewState = .recording
        audioLevel = 0
        recordingDuration = 0

        startPolling()

        #if DEBUG
        print("[Vowrite KB] startTranslateRecording: target=\(targetCode), mode=\(translateMode.name)")
        #endif
    }

    private func clearTranslateSession() {
        if isInTranslateSession {
            isInTranslateSession = false
            translationTargetCode = ""
        }
    }

    // MARK: - Service Alive Check

    /// Periodically re-check if the background service is alive,
    /// so the UI updates when the user activates it via deep link and returns.
    private func startServiceCheckTimer() {
        serviceCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
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
            Task { @MainActor [weak self] in
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

        if ipcState == .idle {
            // After sending .start, ignore .idle for up to 1s — the Darwin notification
            // needs time to reach the main app (especially on first cross-process delivery).
            if let sentAt = startCommandSentAt,
               Date().timeIntervalSince(sentAt) < 1.0,
               viewState == .recording {
                return
            }
            // If we were recording/processing and now idle, it was cancelled
            if viewState == .recording || viewState == .processing {
                viewState = .idle
                stopPolling()
                startCommandSentAt = nil
                clearTranslateSession()
                clearSessionTracking()
            }
            return
        }

        // Any non-idle read is only ours if the service echoed back the
        // session id this keyboard minted at .start — otherwise it's a
        // stale/foreign session (e.g. a .done left over from a session that
        // finished while the keyboard was dismissed) and must be discarded,
        // never inserted. See IPCReconciler.
        let sessionMatches = currentSessionId != nil && ipc.activeSessionId == currentSessionId
        let action = IPCReconciler.action(
            state: ipcState,
            sessionMatches: sessionMatches,
            serviceAlive: ipc.isServiceAlive
        )

        switch action {
        case .adopt(.recording):
            startCommandSentAt = nil
            viewState = .recording
            audioLevel = ipc.audioLevel
            recordingDuration = ipc.recordingDuration

        case .adopt(.processing):
            viewState = .processing

        case .adopt:
            // .adopt only ever carries .recording/.processing (see
            // IPCReconciler.action); unreachable in practice.
            break

        case .insertResultAndGoIdle:
            if let result = ipc.result, !result.isEmpty {
                inputViewController?.textDocumentProxy.insertText(result)
            }
            ipc.clearResult()
            stopPolling()
            viewState = .idle
            clearTranslateSession()
            clearSessionTracking()

        case .surfaceErrorAndGoIdle:
            let message = ipc.errorMessage ?? "Unknown error"
            viewState = .error(message)
            ipc.clearResult()
            stopPolling()
            clearTranslateSession()
            clearSessionTracking()

        case .serviceDied:
            // Watchdog: if the main app process died mid-recording, the IPC
            // state sticks on .recording/.processing forever (it was written
            // by a process that no longer exists to move it forward).
            // Detect via the same heartbeat liveness check used elsewhere
            // instead of hanging indefinitely.
            stopPolling()
            startCommandSentAt = nil
            ipc.clearResult()
            viewState = .error("Vowrite stopped in background")
            clearTranslateSession()
            clearSessionTracking()

        case .discardAndGoIdle:
            // Stale/foreign state (mismatched session) — discard silently,
            // never insert, and stop tracking a session that was never ours.
            ipc.clearResult()
            stopPolling()
            startCommandSentAt = nil
            viewState = .idle
            clearTranslateSession()
            clearSessionTracking()

        case .none:
            // ipcState != .idle here, so unreachable in practice.
            break
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

    // MARK: - F-067 Bulk Delete

    /// Tier of the long-press delete popup. Selected based on how long the
    /// finger has rested on the popup before the user lifts.
    enum BulkDeleteTier: Equatable {
        case word, line, paragraph, all

        static func from(elapsed: TimeInterval) -> BulkDeleteTier {
            switch elapsed {
            case ..<0.5:  return .word
            case ..<1.3:  return .line
            case ..<2.5:  return .paragraph
            default:      return .all
            }
        }

        var label: String {
            switch self {
            case .word:      return "删除单词"
            case .line:      return "删除整行"
            case .paragraph: return "删除整段"
            case .all:       return "删除全部"
            }
        }
    }

    /// Delete the chunk of text that corresponds to `tier`, computed by
    /// rewinding through `documentContextBeforeInput`. Each step calls
    /// `deleteBackward()`, which removes one user-perceived character
    /// (grapheme cluster) per call.
    func bulkDelete(tier: BulkDeleteTier) {
        guard let proxy = inputViewController?.textDocumentProxy,
              let context = proxy.documentContextBeforeInput,
              !context.isEmpty
        else { return }

        let count: Int
        switch tier {
        case .word:      count = Self.charsToDeleteForWord(in: context)
        case .line:      count = Self.charsToDeleteForLine(in: context)
        case .paragraph: count = Self.charsToDeleteForParagraph(in: context)
        case .all:       count = context.count
        }

        guard count > 0 else { return }
        for _ in 0..<count {
            proxy.deleteBackward()
        }
    }

    /// Word: skip trailing whitespace from the cursor, then walk back until
    /// the next whitespace or punctuation. CJK text (no spaces) collapses to
    /// "delete back to the previous punctuation" — typically a sentence,
    /// which is still a sensible smallest tier.
    static func charsToDeleteForWord(in text: String) -> Int {
        var idx = text.endIndex
        // Skip trailing whitespace.
        while idx > text.startIndex {
            let prev = text.index(before: idx)
            if text[prev].isWhitespace { idx = prev } else { break }
        }
        // Walk back the word body.
        while idx > text.startIndex {
            let prev = text.index(before: idx)
            let c = text[prev]
            if c.isWhitespace || c.isPunctuation { break }
            idx = prev
        }
        let count = text.distance(from: idx, to: text.endIndex)
        return max(count, 1)
    }

    /// Line: rewind to the position just after the previous `\n`, or the
    /// start of context if none.
    static func charsToDeleteForLine(in text: String) -> Int {
        if let nl = text.lastIndex(of: "\n") {
            return text.distance(from: text.index(after: nl), to: text.endIndex)
        }
        return text.count
    }

    /// Paragraph: rewind to just after the previous `\n\n`, or the start of
    /// context if none.
    static func charsToDeleteForParagraph(in text: String) -> Int {
        if let range = text.range(of: "\n\n", options: .backwards) {
            return text.distance(from: range.upperBound, to: text.endIndex)
        }
        return text.count
    }

    func insertText(_ text: String) {
        inputViewController?.textDocumentProxy.insertText(text)
    }

    // MARK: - F-071 Input Mode

    private var lastShiftTapDate: Date?

    func toggleInputMode() {
        guard viewState != .recording && viewState != .processing else { return }
        if inputMode == .voice {
            inputMode = .keyboard
        } else {
            keyboardLayout = .letters
            keyboardShift = .off
            inputMode = .voice
        }
    }

    func handleShiftTap() {
        let now = Date()
        switch keyboardShift {
        case .capsLock:
            keyboardShift = .off
        case .shift:
            if let last = lastShiftTapDate, now.timeIntervalSince(last) < 0.4 {
                keyboardShift = .capsLock
            } else {
                keyboardShift = .off
            }
        case .off:
            keyboardShift = .shift
        }
        lastShiftTapDate = now
    }

    func typeLetter(_ char: String) {
        let output = keyboardShift == .off ? char.lowercased() : char.uppercased()
        insertText(output)
        if keyboardShift == .shift { keyboardShift = .off }
    }

    func dismissKeyboard() {
        inputViewController?.dismissKeyboard()
    }

    // MARK: - Container App Deep Link

    /// Open the container app via URL scheme.
    /// Used as a fallback when the `Link`-based approach isn't available
    /// (e.g., StatusBanner action buttons, edge cases in startRecording).
    func openContainerApp(path: String = "activate") {
        guard let url = URL(string: "vowrite://\(path)") else { return }

        // Primary: SwiftUI openURL action (works on iOS 18+)
        if let openURL = openURLAction {
            openURL(url)
            return
        }

        // Fallback: responder chain (works on iOS ≤17)
        let selector = NSSelectorFromString("openURL:")
        var responder: UIResponder? = inputViewController
        while let r = responder {
            if r.responds(to: selector) {
                r.perform(selector, with: url)
                return
            }
            responder = r.next
        }
    }
}
