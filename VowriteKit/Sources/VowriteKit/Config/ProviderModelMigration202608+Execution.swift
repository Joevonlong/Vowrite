import Foundation
import os

extension ProviderModelMigration202608 {
    static func runLocked(
        defaults: UserDefaults,
        lockDirectory: URL,
        interruptAfterAppliedEntries: Int?,
        afterPreparedJournalBeforeResume: (() -> Void)?
    ) -> RunResult {
        let url = journalURL(in: lockDirectory)

        if FileManager.default.fileExists(atPath: url.path) {
            guard var journal = loadJournal(at: url),
                  journal.formatVersion == 1,
                  journal.migrationID == ProviderModelSafetyRules.migrationID,
                  journal.rulesetHash == ProviderModelSafetyRules.rulesetHash,
                  validateJournal(journal) else {
                return .blockedJournal
            }

            switch journal.state {
            case .committed where markersMatch(defaults):
                return .alreadyComplete
            case .rolledBack:
                do {
                    try FileManager.default.removeItem(at: url)
                } catch {
                    return .blockedJournal
                }
                return runLocked(
                    defaults: defaults,
                    lockDirectory: lockDirectory,
                    interruptAfterAppliedEntries: interruptAfterAppliedEntries,
                    afterPreparedJournalBeforeResume: afterPreparedJournalBeforeResume
                )
            case .committed, .rollingBack:
                return .blockedJournal
            case .prepared:
                break
            }
            return resume(
                journal: &journal,
                defaults: defaults,
                journalURL: url,
                interruptAfterAppliedEntries: interruptAfterAppliedEntries
            )
        }

        if markersMatch(defaults) {
            return .alreadyComplete
        }

        // A keyboard extension can launch before the container has imported
        // legacy standard defaults into the App Group. Completing an empty
        // suite would prevent the later imported values from ever migrating.
        guard hasMigrationSource(in: defaults) else { return .deferred }

        let snapshot: Snapshot
        do {
            snapshot = try preflight(defaults: defaults)
        } catch {
            return .blockedCorruptData
        }

        guard let entries = makeEntries(from: snapshot) else {
            return .blockedCorruptData
        }
        guard let validations = makeValidations(
            rawValues: snapshot.rawValues,
            entries: entries
        ) else {
            return .blockedCorruptData
        }

        var journal = Journal(
            formatVersion: 1,
            migrationID: ProviderModelSafetyRules.migrationID,
            rulesetHash: ProviderModelSafetyRules.rulesetHash,
            state: .prepared,
            progress: 0,
            entries: entries,
            validations: validations
        )
        guard validateJournal(journal) else { return .blockedJournal }
        guard writeJournal(journal, to: url) else { return .blockedJournal }
        afterPreparedJournalBeforeResume?()

        return resume(
            journal: &journal,
            defaults: defaults,
            journalURL: url,
            interruptAfterAppliedEntries: interruptAfterAppliedEntries
        )
    }

    static func rollbackLocked(
        defaults: UserDefaults,
        lockDirectory: URL,
        isModelAllowed: (String, ProviderModelCapability, String) -> Bool
    ) -> RollbackResult {
        let url = journalURL(in: lockDirectory)
        guard var journal = loadJournal(at: url),
              journal.formatVersion == 1,
              journal.migrationID == ProviderModelSafetyRules.migrationID,
              journal.rulesetHash == ProviderModelSafetyRules.rulesetHash,
              validateJournal(journal),
              journal.state == .committed || journal.state == .rollingBack else {
            return .blockedJournal
        }

        if journal.state == .committed {
            let hasAllowedTarget = journal.entries.contains { entry in
                guard let current = storedValue(defaults, key: entry.key),
                      hash(current) == entry.afterHash else { return false }
                return rollbackTargetAllowed(
                    entry,
                    journal: journal,
                    defaults: defaults,
                    isModelAllowed: isModelAllowed
                )
            }
            guard hasAllowedTarget else { return .nothingToRollback }
            journal.state = .rollingBack
            journal.progress = 0
            guard writeJournal(journal, to: url) else { return .blockedJournal }
        }

        for (index, entry) in journal.entries.enumerated() {
            guard let current = storedValue(defaults, key: entry.key),
                  let currentHash = hash(current) else {
                journal.progress = max(journal.progress, index + 1)
                guard writeJournal(journal, to: url) else { return .blockedJournal }
                continue
            }

            if currentHash == entry.afterHash,
               rollbackTargetAllowed(
                   entry,
                   journal: journal,
                   defaults: defaults,
                   isModelAllowed: isModelAllowed
               ) {
                write(entry.before, defaults: defaults, key: entry.key)
                defaults.synchronize()
            }
            // A before-hash is an idempotent replay. Any third hash is a user
            // edit and is deliberately preserved for this key.
            journal.progress = max(journal.progress, index + 1)
            guard writeJournal(journal, to: url) else { return .blockedJournal }
        }

        defaults.removeObject(forKey: StorageKeys.providerModelCompatibilityMigrationID)
        defaults.removeObject(forKey: StorageKeys.providerModelCompatibilityRulesetHash)
        defaults.synchronize()
        journal.state = .rolledBack
        guard writeJournal(journal, to: url) else { return .blockedJournal }
        return .rolledBack
    }

    static func log(_ result: RunResult) {
        switch result {
        case .committed, .alreadyComplete, .deferred:
            break
        case .interrupted:
            logger.notice("Provider model migration interrupted before completion")
        case .blockedCorruptData:
            logger.error("Provider model migration blocked by corrupt persisted data")
        case .blockedUnexpectedState:
            logger.error("Provider model migration blocked by unexpected persisted state")
        case .blockedJournal:
            logger.error("Provider model migration blocked by an invalid journal")
        case .lockUnavailable:
            logger.error("Provider model migration lock is unavailable")
        }
    }

    private static let logger = Logger(
        subsystem: "com.vowrite.kit",
        category: "provider-model-migration"
    )

    private static func rollbackTargetAllowed(
        _ entry: JournalEntry,
        journal: Journal,
        defaults: UserDefaults,
        isModelAllowed: (String, ProviderModelCapability, String) -> Bool
    ) -> Bool {
        switch entry.key {
        case StorageKeys.splitAPISTTModel:
            return globalRollbackTargetAllowed(
                entry.before,
                providerKey: StorageKeys.splitAPISTTProvider,
                fallbackProvider: .groq,
                capability: .stt,
                journal: journal,
                defaults: defaults,
                isModelAllowed: isModelAllowed
            )
        case StorageKeys.splitAPIPolishModel:
            return globalRollbackTargetAllowed(
                entry.before,
                providerKey: StorageKeys.splitAPIPolishProvider,
                fallbackProvider: .deepseek,
                capability: .polish,
                journal: journal,
                defaults: defaults,
                isModelAllowed: isModelAllowed
            )
        case StorageKeys.splitAPIUserPresets:
            guard case .data(let data) = entry.before,
                  let presets = try? JSONDecoder().decode([UserAPIPreset].self, from: data) else {
                return false
            }
            return presets.allSatisfy { preset in
                let stt = preset.configuration.stt
                let polish = preset.configuration.polish
                return isModelAllowed(stt.provider.providerID, .stt, stt.model)
                    && isModelAllowed(polish.provider.providerID, .polish, polish.model)
            }
        default:
            return false
        }
    }

    private static func globalRollbackTargetAllowed(
        _ before: StoredValue,
        providerKey: String,
        fallbackProvider: APIProvider,
        capability: ProviderModelCapability,
        journal: Journal,
        defaults: UserDefaults,
        isModelAllowed: (String, ProviderModelCapability, String) -> Bool
    ) -> Bool {
        guard case .string(let model) = before,
              let providerValue = storedValue(defaults, key: providerKey),
              let providerHash = hash(providerValue),
              journal.validations.first(where: { $0.key == providerKey })?
                .allowedHashes.contains(providerHash) == true else {
            return false
        }

        let provider: APIProvider
        switch providerValue {
        case .missing:
            provider = fallbackProvider
        case .string(let raw):
            guard let decoded = APIProvider(rawValue: raw) else { return false }
            provider = decoded
        case .data:
            return false
        }
        return isModelAllowed(provider.providerID, capability, model)
    }

    private static func resume(
        journal: inout Journal,
        defaults: UserDefaults,
        journalURL: URL,
        interruptAfterAppliedEntries: Int?
    ) -> RunResult {
        // Recovery must repeat raw decoding: a prepared journal can outlive a
        // process, and validation-only Mode bytes may have become corrupt in
        // the meantime. Hash checks also stop valid-but-unexpected user edits.
        do {
            _ = try preflight(defaults: defaults)
        } catch {
            return .blockedCorruptData
        }
        for validation in journal.validations {
            guard let current = storedValue(defaults, key: validation.key),
                  let currentHash = hash(current),
                  validation.allowedHashes.contains(currentHash) else {
                return .blockedUnexpectedState
            }
        }

        if interruptAfterAppliedEntries == 0 && journal.progress == 0 {
            return .interrupted
        }

        for (index, entry) in journal.entries.enumerated() {
            guard let current = storedValue(defaults, key: entry.key),
                  let currentHash = hash(current) else {
                return .blockedUnexpectedState
            }

            if currentHash == entry.beforeHash {
                write(entry.after, defaults: defaults, key: entry.key)
                defaults.synchronize()
            } else if currentHash != entry.afterHash {
                return .blockedUnexpectedState
            }

            journal.progress = max(journal.progress, index + 1)
            guard writeJournal(journal, to: journalURL) else { return .blockedJournal }

            if interruptAfterAppliedEntries == index + 1 {
                return .interrupted
            }
        }

        for entry in journal.entries {
            guard let current = storedValue(defaults, key: entry.key),
                  hash(current) == entry.afterHash else {
                return .blockedUnexpectedState
            }
        }

        defaults.set(
            ProviderModelSafetyRules.migrationID,
            forKey: StorageKeys.providerModelCompatibilityMigrationID
        )
        defaults.set(
            ProviderModelSafetyRules.rulesetHash,
            forKey: StorageKeys.providerModelCompatibilityRulesetHash
        )
        defaults.synchronize()

        journal.state = .committed
        guard writeJournal(journal, to: journalURL) else { return .blockedJournal }
        return .committed
    }

    private static func markersMatch(_ defaults: UserDefaults) -> Bool {
        defaults.string(forKey: StorageKeys.providerModelCompatibilityMigrationID)
            == ProviderModelSafetyRules.migrationID
            && defaults.string(forKey: StorageKeys.providerModelCompatibilityRulesetHash)
            == ProviderModelSafetyRules.rulesetHash
    }

    private static func hasMigrationSource(in defaults: UserDefaults) -> Bool {
        let sourceKeys = [
            StorageKeys.splitAPISTTProvider,
            StorageKeys.splitAPISTTModel,
            StorageKeys.splitAPISTTBaseURL,
            StorageKeys.splitAPIPolishProvider,
            StorageKeys.splitAPIPolishModel,
            StorageKeys.splitAPIPolishBaseURL,
            StorageKeys.vowriteModes,
            StorageKeys.splitAPIUserPresets,
        ]
        return sourceKeys.contains { defaults.object(forKey: $0) != nil }
    }
}
