import Foundation

/// F-081: Pure decision logic for per-app auto Mode. The feature itself is
/// mac-only (see `StorageKeys.perAppModeEnabled`/`.perAppModeMapping` for
/// why), but every branch of "should this recording apply a mapped Mode"
/// is app-agnostic — no NSWorkspace, no ModeManager singleton, no
/// UserDefaults — so it lives in VowriteKit where `swift test` covers it.
/// `PerAppModeManager` (VowriteMac/Sources/Services/) is the only caller:
/// it supplies the live inputs (frontmost bundle ID, stored mapping,
/// `ModeManager.shared.modes`) and applies the resulting `Action` via
/// `DictationEngine.setSessionModeOverride(_:)` — the same oneshot seam
/// F-063's translate hotkey uses, so a mapping hit never mutates the
/// user's globally-selected Mode.
public enum PerAppModeDecision {

    // MARK: - Mapping lookup

    /// Result of looking up a bundle ID in the stored mapping, cross-checked
    /// against the Modes that currently exist. Deleting a mapped Mode
    /// elsewhere (Personalization → Scenes) must not crash or silently do
    /// nothing without saying why — `.missingMode` distinguishes "no mapping
    /// configured for this app" from "a mapping exists but its target Mode
    /// is gone," even though both currently resolve to the same `.noOverride`
    /// action in `resolve(...)` below. Kept as a separate case (rather than
    /// collapsing to `.noMapping`) so the Settings UI can show "missing
    /// mode" instead of silently looking like the app was never mapped.
    public enum MappingLookup: Equatable {
        case noMapping
        case mapped(modeId: UUID)
        case missingMode
    }

    /// - Parameters:
    ///   - bundleID: the frontmost app's bundle identifier.
    ///   - mapping: the full stored bundleID -> Mode.id mapping.
    ///   - availableModeIds: ids of Modes that currently exist
    ///     (`ModeManager.shared.modes.map(\.id)`), so a mapping pointing at a
    ///     deleted Mode is detected instead of silently resolving to garbage.
    public static func lookupMapping(
        bundleID: String,
        mapping: [String: UUID],
        availableModeIds: Set<UUID>
    ) -> MappingLookup {
        guard let modeId = mapping[bundleID] else { return .noMapping }
        guard availableModeIds.contains(modeId) else { return .missingMode }
        return .mapped(modeId: modeId)
    }

    // MARK: - Pin state ("user's manual Mode choice always wins")
    //
    // The pin protects a manual Mode switch from being immediately
    // overwritten by the next mapping hit in the SAME app. Semantics
    // (deliberately the simplest acceptable version, not full per-app
    // "sticky" memory):
    //   1. Any manual Mode switch (Personalization card tap, or ⌃1-9) marks
    //      the pin `.pending` — it isn't tied to an app yet, because the
    //      switch may have happened from Settings (frontmost = Vowrite
    //      itself, not a meaningful "app" to pin against).
    //   2. The FIRST recording after that binds the pin to whatever app is
    //      frontmost at that moment (`.bound`) and skips the mapping for
    //      that one recording — this is what stops the user's just-made
    //      choice from being clobbered one recording later.
    //   3. While `.bound` to app A, mapping hits for A keep skipping
    //      (pin carries forward unchanged). A mapping hit for a DIFFERENT
    //      app clears the pin (back to `.none`) and applies that app's
    //      mapping — "mapping skipped until the frontmost app changes to a
    //      different mapped app," per spec.
    //   4. Recording in an unmapped app leaves the pin untouched either way
    //      (nothing to decide either way).
    public enum PinState: Equatable {
        case none
        case pending
        case bound(bundleID: String)
    }

    // MARK: - Action

    public enum Action: Equatable {
        /// No mapping applies this session — the engine keeps using
        /// whatever Mode the user currently has selected.
        case noOverride
        /// Apply this Mode id as the session's oneshot override.
        case applyOverride(modeId: UUID)
    }

    /// The single entry point `PerAppModeManager` calls at the start of a
    /// normal (non-translate) recording.
    ///
    /// - Parameters:
    ///   - enabled: the feature's master toggle. `false` -> always `.noOverride`.
    ///   - isTranslateSession: `true` for a recording started by the F-063
    ///     translate hotkey. Per spec, per-app mapping never applies to
    ///     those — they already run under their own oneshot override.
    ///   - bundleID: the frontmost app's bundle id at recording start, or
    ///     `nil` when it couldn't be determined (or is Vowrite's own bundle
    ///     id — the caller is expected to have already excluded that, same
    ///     as `MacTextInjector.prepareForOutput()` does).
    ///   - lookup: result of `lookupMapping(bundleID:mapping:availableModeIds:)`
    ///     for `bundleID`. Ignored (treated as no mapping) if `bundleID == nil`.
    ///   - pin: the pin state carried over from the previous recording.
    /// - Returns: the action to take, and the pin state to store for next time.
    public static func resolve(
        enabled: Bool,
        isTranslateSession: Bool,
        bundleID: String?,
        lookup: MappingLookup,
        pin: PinState
    ) -> (action: Action, newPin: PinState) {
        guard enabled, !isTranslateSession, let bundleID else {
            return (.noOverride, pin)
        }

        guard case .mapped(let modeId) = lookup else {
            // .noMapping or .missingMode: nothing to apply. The pin carries
            // forward untouched — an unmapped app in between two mapped-app
            // recordings must not silently clear a pending/bound pin.
            return (.noOverride, pin)
        }

        switch pin {
        case .none:
            return (.applyOverride(modeId: modeId), .none)

        case .pending:
            // First recording after a manual switch: bind to this app and
            // skip the mapping this one time.
            return (.noOverride, .bound(bundleID: bundleID))

        case .bound(let pinnedBundleID):
            if pinnedBundleID == bundleID {
                return (.noOverride, pin)
            }
            return (.applyOverride(modeId: modeId), .none)
        }
    }
}

/// F-081: Encode/decode helpers for the persisted bundleID -> Mode.id
/// mapping. Pulled out of `PerAppModeManager` (which has no test target —
/// it lives in VowriteMac) so the round-trip and corrupt-data behavior are
/// covered by `swift test`.
public enum PerAppModeMapping {
    public static func encode(_ mapping: [String: UUID]) -> Data? {
        try? JSONEncoder().encode(mapping)
    }

    /// Never throws: missing or corrupt data decodes to an empty mapping
    /// rather than crashing the caller or losing unrelated settings.
    public static func decode(_ data: Data?) -> [String: UUID] {
        guard let data, let decoded = try? JSONDecoder().decode([String: UUID].self, from: data) else {
            return [:]
        }
        return decoded
    }
}
