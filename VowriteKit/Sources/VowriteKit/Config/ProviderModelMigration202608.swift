import Foundation

/// F-084's provider-safe, cross-process model compatibility migration.
///
/// Only values carrying explicit provider identity are persistently changed.
/// Provider-less Mode overrides are decoded as a corruption preflight and then
/// preserved byte-for-byte; request-time safety handles those values instead.
public enum ProviderModelMigration202608 {
    public enum RunResult: Equatable, Sendable {
        case committed
        case alreadyComplete
        case deferred
        case interrupted
        case blockedCorruptData
        case blockedUnexpectedState
        case blockedJournal
        case lockUnavailable
    }

    public enum RollbackResult: Equatable, Sendable {
        case rolledBack
        case nothingToRollback
        case blockedJournal
        case lockUnavailable
    }

    private static let journalFilename = ".provider-model-compat-2026-08-v1.journal.json"

    /// Production entry point. On iOS the lock and journal live at the App
    /// Group root shared by the container and keyboard extension.
    @discardableResult
    public static func runIfNeeded() -> RunResult {
        guard let directory = ProviderModelConfigurationLock.productionDirectory() else {
            log(.lockUnavailable)
            return .lockUnavailable
        }
        let result = runIfNeeded(defaults: VowriteStorage.defaults, lockDirectory: directory)
        log(result)
        return result
    }

    @discardableResult
    static func runIfNeeded(
        defaults: UserDefaults,
        lockDirectory: URL,
        interruptAfterAppliedEntries: Int? = nil,
        afterPreparedJournalBeforeResume: (() -> Void)? = nil
    ) -> RunResult {
        ProviderModelConfigurationLock.withExclusiveLock(
            lockDirectory: lockDirectory,
            unavailable: .lockUnavailable
        ) {
            // Refresh a suite potentially changed by the other iOS process before
            // inspecting its marker or journaled values.
            defaults.synchronize()
            return runLocked(
                defaults: defaults,
                lockDirectory: lockDirectory,
                interruptAfterAppliedEntries: interruptAfterAppliedEntries,
                afterPreparedJournalBeforeResume: afterPreparedJournalBeforeResume
            )
        }
    }

    /// Rollback-build entry point. The committed journal is the sole backup;
    /// values are restored only while their old model is allowed by the
    /// rollback build's current compatibility rules.
    @discardableResult
    public static func rollbackIfAllowed() -> RollbackResult {
        guard let directory = ProviderModelConfigurationLock.productionDirectory() else {
            return .lockUnavailable
        }
        return rollbackIfAllowed(defaults: VowriteStorage.defaults, lockDirectory: directory)
    }

    @discardableResult
    static func rollbackIfAllowed(
        defaults: UserDefaults,
        lockDirectory: URL,
        isModelAllowed: @escaping (String, ProviderModelCapability, String) -> Bool = {
            providerID, capability, model in
            ProviderModelSafetyRules.safeModel(
                providerID: providerID,
                capability: capability,
                storedModel: model
            ) == model
        }
    ) -> RollbackResult {
        ProviderModelConfigurationLock.withExclusiveLock(
            lockDirectory: lockDirectory,
            unavailable: .lockUnavailable
        ) {
            defaults.synchronize()
            return rollbackLocked(
                defaults: defaults,
                lockDirectory: lockDirectory,
                isModelAllowed: isModelAllowed
            )
        }
    }

    static func journalURL(in directory: URL) -> URL {
        directory.appendingPathComponent(journalFilename)
    }
}
