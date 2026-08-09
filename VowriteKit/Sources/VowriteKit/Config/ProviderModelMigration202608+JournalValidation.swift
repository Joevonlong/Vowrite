import Foundation

extension ProviderModelMigration202608 {
    /// Treat the journal as untrusted input. A syntactically valid JSON file
    /// cannot select arbitrary defaults keys, forge hashes, duplicate work, or
    /// smuggle undecodable provider/preset payloads into resume or rollback.
    static func validateJournal(_ journal: Journal) -> Bool {
        guard journal.formatVersion == 1,
              journal.migrationID == ProviderModelSafetyRules.migrationID,
              journal.rulesetHash == ProviderModelSafetyRules.rulesetHash,
              (0...journal.entries.count).contains(journal.progress) else {
            return false
        }
        if journal.state == .committed || journal.state == .rolledBack,
           journal.progress != journal.entries.count {
            return false
        }

        let validationKeyList = journal.validations.map(\.key)
        guard validationKeyList.count == Set(validationKeyList).count,
              Set(validationKeyList) == validationKeys else { return false }
        let validations = Dictionary(
            uniqueKeysWithValues: journal.validations.map { ($0.key, $0) }
        )

        let entryKeyList = journal.entries.map(\.key)
        guard entryKeyList.count == Set(entryKeyList).count,
              Set(entryKeyList).isSubset(of: entryKeys) else { return false }

        for validation in journal.validations {
            guard hash(validation.before) == validation.beforeHash,
                  isSHA256Hex(validation.beforeHash),
                  !validation.allowedHashes.isEmpty,
                  validation.allowedHashes.count == Set(validation.allowedHashes).count,
                  validation.allowedHashes.allSatisfy(isSHA256Hex),
                  validateInitialValue(validation.before, forKey: validation.key) else {
                return false
            }
            if let entry = journal.entries.first(where: { $0.key == validation.key }) {
                guard validation.before == entry.before,
                      Set(validation.allowedHashes) == Set([entry.beforeHash, entry.afterHash]) else {
                    return false
                }
            } else if validation.allowedHashes != [validation.beforeHash] {
                return false
            }
        }

        for entry in journal.entries {
            guard entry.before != entry.after,
                  hash(entry.before) == entry.beforeHash,
                  hash(entry.after) == entry.afterHash,
                  isSHA256Hex(entry.beforeHash),
                  isSHA256Hex(entry.afterHash),
                  validateEntryTransform(entry, validations: validations) else {
                return false
            }
        }
        return true
    }

    private static let entryKeys: Set<String> = [
        StorageKeys.splitAPISTTModel,
        StorageKeys.splitAPIPolishModel,
        StorageKeys.splitAPIUserPresets,
    ]

    private static func validateInitialValue(_ value: StoredValue, forKey key: String) -> Bool {
        switch key {
        case StorageKeys.splitAPISTTProvider, StorageKeys.splitAPIPolishProvider:
            switch value {
            case .missing:
                return true
            case .string(let raw):
                return APIProvider(rawValue: raw) != nil
            case .data:
                return false
            }
        case StorageKeys.splitAPISTTModel,
             StorageKeys.splitAPISTTBaseURL,
             StorageKeys.splitAPIPolishModel,
             StorageKeys.splitAPIPolishBaseURL:
            if case .data = value { return false }
            return true
        case StorageKeys.vowriteModes:
            switch value {
            case .missing:
                return true
            case .data(let data):
                return (try? JSONDecoder().decode([Mode].self, from: data)) != nil
            case .string:
                return false
            }
        case StorageKeys.splitAPIUserPresets:
            switch value {
            case .missing:
                return true
            case .data(let data):
                return (try? JSONDecoder().decode([UserAPIPreset].self, from: data)) != nil
            case .string:
                return false
            }
        default:
            return false
        }
    }

    private static func validateEntryTransform(
        _ entry: JournalEntry,
        validations: [String: JournalValidation]
    ) -> Bool {
        switch entry.key {
        case StorageKeys.splitAPISTTModel:
            return validateGlobalModelTransform(
                entry,
                providerValue: validations[StorageKeys.splitAPISTTProvider]?.before,
                fallbackProvider: .groq,
                capability: .stt
            )
        case StorageKeys.splitAPIPolishModel:
            return validateGlobalModelTransform(
                entry,
                providerValue: validations[StorageKeys.splitAPIPolishProvider]?.before,
                fallbackProvider: .deepseek,
                capability: .polish
            )
        case StorageKeys.splitAPIUserPresets:
            guard case .data(let beforeData) = entry.before,
                  case .data(let afterData) = entry.after,
                  let before = try? JSONDecoder().decode([UserAPIPreset].self, from: beforeData),
                  let after = try? JSONDecoder().decode([UserAPIPreset].self, from: afterData) else {
                return false
            }
            return migratedPresets(before) == after
        default:
            return false
        }
    }

    private static func validateGlobalModelTransform(
        _ entry: JournalEntry,
        providerValue: StoredValue?,
        fallbackProvider: APIProvider,
        capability: ProviderModelCapability
    ) -> Bool {
        guard case .string(let before) = entry.before,
              case .string(let after) = entry.after,
              let providerValue else { return false }
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
        return ProviderModelSafetyRules.safeModel(
            providerID: provider.providerID,
            capability: capability,
            storedModel: before
        ) == after
    }

    private static func migratedPresets(_ input: [UserAPIPreset]) -> [UserAPIPreset] {
        var presets = input
        for index in presets.indices {
            let stt = presets[index].configuration.stt
            presets[index].configuration.stt.model = ProviderModelSafetyRules.safeModel(
                providerID: stt.provider.providerID,
                capability: .stt,
                storedModel: stt.model
            )
            let polish = presets[index].configuration.polish
            presets[index].configuration.polish.model = ProviderModelSafetyRules.safeModel(
                providerID: polish.provider.providerID,
                capability: .polish,
                storedModel: polish.model
            )
        }
        return presets
    }

    private static func isSHA256Hex(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }
}
