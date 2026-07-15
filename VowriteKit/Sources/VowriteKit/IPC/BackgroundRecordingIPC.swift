import Foundation

public enum RecordingCommand: String, CaseIterable {
    case start = "com.vowrite.command.startRecording"
    case stop = "com.vowrite.command.stopRecording"
    case cancel = "com.vowrite.command.cancelRecording"
}

public enum BackgroundRecordingState: String, Codable {
    case idle, recording, processing, done, error
}

/// IPC layer for keyboard extension <-> main app communication.
/// Uses Darwin Notification Center for commands and App Group UserDefaults for state.
public final class BackgroundRecordingIPC {
    public static let shared = BackgroundRecordingIPC()

    private let defaults: UserDefaults
    private var commandHandler: ((RecordingCommand) -> Void)?

    // Keys for App Group UserDefaults
    private enum Key {
        static let state = "bg_recording_state"
        static let ipcPayload = "bg_ipc_payload"
        static let errorMessage = "bg_recording_error"
        static let audioLevel = "bg_audio_level"
        static let recordingDuration = "bg_recording_duration"
        static let requestedModeId = "bg_recording_mode_id"
        static let requestedAIEnabled = "bg_recording_ai_enabled"
        static let requestedStyleName = "bg_recording_style_name"
        static let sessionModeOverrideId = "bg_recording_session_mode_override_id"
        static let serviceActive = "bg_service_active"
        static let serviceHeartbeat = "bg_service_heartbeat"
        static let requestedSessionId = "bg_recording_requested_session_id"
        static let activeSessionId = "bg_recording_active_session_id"
        static let keyboardSessionId = "bg_keyboard_session_id"
    }

    private init() {
        self.defaults = UserDefaults(suiteName: VowriteStorage.appGroupID) ?? .standard
    }

    // MARK: - Send commands (keyboard -> main app)

    public func sendCommand(_ command: RecordingCommand) {
        // Flush any pending writes before sending
        defaults.synchronize()
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let name = CFNotificationName(command.rawValue as CFString)
        CFNotificationCenterPostNotification(center, name, nil, nil, true)
        #if DEBUG
        print("[Vowrite IPC] Sent command: \(command.rawValue)")
        #endif
    }

    // MARK: - Observe commands (main app listens)

    /// Register a handler for all recording commands.
    /// The handler is called on the posting thread — dispatch to main if needed.
    public func observeCommands(handler: @escaping (RecordingCommand) -> Void) {
        // Remove any previous observers first
        stopObserving()

        commandHandler = handler
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observerPtr = Unmanaged.passUnretained(self).toOpaque()

        let callback: CFNotificationCallback = { _, observer, name, _, _ in
            guard let observer = observer,
                  let name = name?.rawValue as String? else { return }
            let ipc = Unmanaged<BackgroundRecordingIPC>.fromOpaque(observer).takeUnretainedValue()
            guard let cmd = RecordingCommand(rawValue: name) else { return }
            #if DEBUG
            print("[Vowrite IPC] Received Darwin notification: \(cmd.rawValue)")
            #endif
            ipc.commandHandler?(cmd)
        }

        for command in RecordingCommand.allCases {
            CFNotificationCenterAddObserver(
                center,
                observerPtr,
                callback,
                command.rawValue as CFString,
                nil,
                .deliverImmediately
            )
            #if DEBUG
            print("[Vowrite IPC] Registered observer for: \(command.rawValue)")
            #endif
        }
    }

    /// Remove all command observers.
    public func stopObserving() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observerPtr = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterRemoveEveryObserver(center, observerPtr)
        commandHandler = nil
    }

    // MARK: - State (main app writes, keyboard reads)
    //
    // INVARIANT — write ordering: the service must write `result` (and, when
    // starting a session, `activeSessionId`) BEFORE it flips `state` to
    // `.done`/`.error`. UserDefaults has no atomic multi-key commit, so a
    // reader that observes the *new* `state` must already be able to observe
    // the correspondingly-updated `result`/`activeSessionId` — never the
    // other way around, or the keyboard could read `.done` alongside a
    // leftover `result`/`activeSessionId` from a previous session. See
    // `BackgroundRecordingService.processAudio()` (`ipc.result = finalText`
    // then `ipc.state = .done`) and `startRecording()` (`ipc.activeSessionId`
    // set before the first possible `ipc.state = .error`). The keyboard's
    // `IPCReconciler` depends on this ordering to distinguish a genuinely
    // finished session (matching `activeSessionId`) from a stale one.

    public var state: BackgroundRecordingState {
        get {
            defaults.synchronize()
            guard let raw = defaults.string(forKey: Key.state),
                  let s = BackgroundRecordingState(rawValue: raw) else { return .idle }
            return s
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.state)
            defaults.synchronize()
            #if DEBUG
            print("[Vowrite IPC] State -> \(newValue.rawValue)")
            #endif
        }
    }

    public var result: String? {
        get {
            defaults.synchronize()
            return defaults.string(forKey: Key.ipcPayload)
        }
        set {
            defaults.set(newValue, forKey: Key.ipcPayload)
            defaults.synchronize()
        }
    }

    /// The session id the SERVICE currently attributes `state`/`result`
    /// writes to. Set once, at the top of `BackgroundRecordingService
    /// .startRecording()`, by copying `requestedSessionId`; held constant
    /// for the rest of that session's lifecycle (including `.recording` →
    /// `.processing` → `.done`/`.error`); cleared by `clearResult()` when
    /// the lifecycle returns to `.idle`. The keyboard compares this against
    /// its own remembered session id (see `keyboardSessionId`,
    /// `IPCReconciler`) before trusting a `.done`/`.error`/`.recording`/
    /// `.processing` read — this is what makes a stale cross-session read
    /// (e.g. a `.done` left over from a session the keyboard never started)
    /// detectable instead of silently inserted into the wrong app.
    public var activeSessionId: String? {
        get {
            defaults.synchronize()
            return defaults.string(forKey: Key.activeSessionId)
        }
        set {
            defaults.set(newValue, forKey: Key.activeSessionId)
            defaults.synchronize()
        }
    }

    public var errorMessage: String? {
        get { defaults.string(forKey: Key.errorMessage) }
        set { defaults.set(newValue, forKey: Key.errorMessage) }
    }

    public var audioLevel: Float {
        get { defaults.float(forKey: Key.audioLevel) }
        set { defaults.set(newValue, forKey: Key.audioLevel) }
    }

    public var recordingDuration: Double {
        get { defaults.double(forKey: Key.recordingDuration) }
        set { defaults.set(newValue, forKey: Key.recordingDuration) }
    }

    // MARK: - Config (keyboard writes, main app reads)

    public var requestedModeId: String? {
        get { defaults.string(forKey: Key.requestedModeId) }
        set { defaults.set(newValue, forKey: Key.requestedModeId) }
    }

    public var requestedAIEnabled: Bool {
        get { defaults.bool(forKey: Key.requestedAIEnabled) }
        set { defaults.set(newValue, forKey: Key.requestedAIEnabled) }
    }

    public var requestedStyleName: String? {
        get { defaults.string(forKey: Key.requestedStyleName) }
        set { defaults.set(newValue, forKey: Key.requestedStyleName) }
    }

    /// F-064: One-shot mode override for the next recording. When set, the
    /// background service uses this Mode (looked up by UUID) instead of the
    /// persisted current Mode and clears the value at the end of the session.
    /// The keyboard sets this just before sending `.start` to trigger
    /// translation without mutating the user's selected Mode.
    public var sessionModeOverrideId: String? {
        get {
            defaults.synchronize()
            return defaults.string(forKey: Key.sessionModeOverrideId)
        }
        set {
            defaults.set(newValue, forKey: Key.sessionModeOverrideId)
            defaults.synchronize()
        }
    }

    /// A fresh id the keyboard mints for the recording it's about to start,
    /// written just before `sendCommand(.start)`. The service reads this
    /// once, at the top of `startRecording()`, and copies it into
    /// `activeSessionId` — establishing which session every subsequent
    /// state/result write in that lifecycle belongs to. Not read again after
    /// that point (unlike `sessionModeOverrideId`, this is a one-shot
    /// hand-off, not something the service re-reads mid-session).
    public var requestedSessionId: String? {
        get {
            defaults.synchronize()
            return defaults.string(forKey: Key.requestedSessionId)
        }
        set {
            defaults.set(newValue, forKey: Key.requestedSessionId)
            defaults.synchronize()
        }
    }

    // MARK: - Service liveness

    public var serviceActive: Bool {
        get {
            defaults.synchronize()
            return defaults.bool(forKey: Key.serviceActive)
        }
        set {
            defaults.set(newValue, forKey: Key.serviceActive)
            defaults.synchronize()
        }
    }

    public var serviceHeartbeat: Date {
        get {
            defaults.synchronize()
            return defaults.object(forKey: Key.serviceHeartbeat) as? Date ?? .distantPast
        }
        set {
            defaults.set(newValue, forKey: Key.serviceHeartbeat)
            defaults.synchronize()
        }
    }

    /// Returns true if the background service was recently active (within last 5 seconds).
    public var isServiceAlive: Bool {
        defaults.synchronize()
        let alive = serviceActive && Date().timeIntervalSince(serviceHeartbeat) < 5
        #if DEBUG
        if !alive {
            print("[Vowrite IPC] isServiceAlive=false (active=\(serviceActive), heartbeat age=\(Date().timeIntervalSince(serviceHeartbeat))s)")
        }
        #endif
        return alive
    }

    // MARK: - Keyboard-owned session tracking

    /// The keyboard's own record of "the session I'm currently tracking,"
    /// persisted in App Group storage (never read by the service — this is
    /// bookkeeping for the keyboard side only, the mirror image of
    /// `activeSessionId` on the service side). A brand-new `KeyboardState`
    /// instance — e.g. the extension process was recycled by iOS while the
    /// user was in a different app — reads this on `reloadConfiguration()`
    /// to recognize an in-flight recording it (a previous instance of this
    /// same keyboard) started, distinguishing "my session, still running"
    /// from a stale session left by a completely different keyboard
    /// lifetime. Cleared whenever the keyboard lands back at `.idle`.
    public var keyboardSessionId: String? {
        get {
            defaults.synchronize()
            return defaults.string(forKey: Key.keyboardSessionId)
        }
        set {
            defaults.set(newValue, forKey: Key.keyboardSessionId)
            defaults.synchronize()
        }
    }

    // MARK: - Convenience

    public func clearResult() {
        result = nil
        errorMessage = nil
        state = .idle
        activeSessionId = nil
    }

    /// F-064: Clear the one-shot mode override. Called by the BG service at
    /// the end of every recording lifecycle (success / cancel / error) so the
    /// next session falls back to the user's persisted Mode.
    public func clearSessionModeOverride() {
        sessionModeOverrideId = nil
    }
}
