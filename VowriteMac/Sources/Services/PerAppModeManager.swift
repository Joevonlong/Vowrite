import AppKit
import VowriteKit

/// F-081: Per-app auto Mode. Mac-only — resolving "which app is frontmost"
/// requires `NSWorkspace`, unavailable to the iOS keyboard extension (no
/// host-app introspection API exists there). Manual-first, conservative:
/// OFF by default, and the user's explicit Mode choice always wins over a
/// mapping until they switch apps again (see `PerAppModeDecision.PinState`).
///
/// All branching logic lives in `PerAppModeDecision` (VowriteKit, unit
/// tested via `swift test`); this class only supplies the live inputs
/// (frontmost bundle id, stored mapping, `ModeManager.shared.modes`) and
/// owns persistence + the in-memory pin.
@MainActor
final class PerAppModeManager: ObservableObject {
    static let shared = PerAppModeManager()

    private static let enabledKey = StorageKeys.perAppModeEnabled
    private static let mappingKey = StorageKeys.perAppModeMapping

    @Published var enabled: Bool {
        didSet { UserDefaults.standard.set(enabled, forKey: Self.enabledKey) }
    }

    /// bundleID -> Mode.id. Order is not meaningful; the Settings UI sorts
    /// for display.
    @Published private(set) var mapping: [String: UUID] {
        didSet { save() }
    }

    /// In-memory only, deliberately not persisted — the pin protects a
    /// manual Mode switch for the remainder of the current app session; a
    /// relaunch starting unpinned (`.none`) is the correct/expected reset.
    private var pinState: PerAppModeDecision.PinState = .none

    private init() {
        self.enabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        self.mapping = PerAppModeMapping.decode(UserDefaults.standard.data(forKey: Self.mappingKey))
    }

    // MARK: - Mapping CRUD (Settings UI)

    func setMapping(bundleID: String, modeId: UUID) {
        let trimmed = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        mapping[trimmed] = modeId
    }

    func removeMapping(bundleID: String) {
        mapping.removeValue(forKey: bundleID)
    }

    // MARK: - Manual-switch hook (pin)

    /// Call whenever the user explicitly switches Mode — i.e. at every call
    /// site of `ModeManager.shared.select(_:)` reachable from UI (currently:
    /// the Personalization "Scenes" card tap, and the ⌃1-9 hotkey handler in
    /// `AppState`). Marks the pin `.pending`; the next recording binds it to
    /// whichever app is frontmost at that point.
    func noteManualModeSwitch() {
        pinState = .pending
    }

    // MARK: - Session resolution (normal hotkey path only)

    /// Resolve whether a per-app mapping should override the recording
    /// about to start. Returns the Mode id to apply via
    /// `DictationEngine.setSessionModeOverride(_:)`, or `nil` to leave the
    /// engine's own current-Mode selection untouched.
    ///
    /// - Parameter isTranslateSession: always `false` from the normal
    ///   hotkey path today (the translate hotkey calls
    ///   `engine.startTranslateRecording()` directly and never reaches
    ///   here) — kept as a parameter so the mac-only/translate-exclusion
    ///   rule stays explicit and testable at this call boundary rather than
    ///   assumed.
    func resolveSessionOverride(isTranslateSession: Bool) -> UUID? {
        let bundleID = frontmostExternalBundleID()

        let lookup: PerAppModeDecision.MappingLookup
        if let bundleID {
            let availableModeIds = Set(ModeManager.shared.modes.map(\.id))
            lookup = PerAppModeDecision.lookupMapping(bundleID: bundleID, mapping: mapping, availableModeIds: availableModeIds)
        } else {
            lookup = .noMapping
        }

        let (action, newPin) = PerAppModeDecision.resolve(
            enabled: enabled,
            isTranslateSession: isTranslateSession,
            bundleID: bundleID,
            lookup: lookup,
            pin: pinState
        )
        pinState = newPin

        switch action {
        case .noOverride:
            return nil
        case .applyOverride(let modeId):
            return modeId
        }
    }

    /// Frontmost app's bundle id, excluding Vowrite's own — same exclusion
    /// `MacTextInjector.prepareForOutput()` applies, since Vowrite itself
    /// being frontmost (e.g. "Start Recording" clicked from the Settings
    /// window) isn't a mappable "target app."
    private func frontmostExternalBundleID() -> String? {
        let myBundleID = Bundle.main.bundleIdentifier ?? "com.vowrite.app"
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleID = app.bundleIdentifier,
              bundleID != myBundleID else { return nil }
        return bundleID
    }

    // MARK: - Persistence

    private func save() {
        if let data = PerAppModeMapping.encode(mapping) {
            UserDefaults.standard.set(data, forKey: Self.mappingKey)
        }
    }
}
