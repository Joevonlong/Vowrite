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

    // MARK: - Convenience

    public func clearResult() {
        result = nil
        errorMessage = nil
        state = .idle
    }

    /// F-064: Clear the one-shot mode override. Called by the BG service at
    /// the end of every recording lifecycle (success / cancel / error) so the
    /// next session falls back to the user's persisted Mode.
    public func clearSessionModeOverride() {
        sessionModeOverrideId = nil
    }
}
