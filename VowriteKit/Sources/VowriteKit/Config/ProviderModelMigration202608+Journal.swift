import CryptoKit
import Foundation

extension ProviderModelMigration202608 {
    enum JournalState: String, Codable {
        case prepared
        case committed
        case rollingBack
        case rolledBack
    }

    enum StoredValue: Codable, Equatable {
        case missing
        case string(String)
        case data(Data)

        private enum CodingKeys: String, CodingKey {
            case type
            case value
        }

        private enum ValueType: String, Codable {
            case missing
            case string
            case data
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            switch try container.decode(ValueType.self, forKey: .type) {
            case .missing:
                self = .missing
            case .string:
                self = .string(try container.decode(String.self, forKey: .value))
            case .data:
                self = .data(try container.decode(Data.self, forKey: .value))
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .missing:
                try container.encode(ValueType.missing, forKey: .type)
            case .string(let value):
                try container.encode(ValueType.string, forKey: .type)
                try container.encode(value, forKey: .value)
            case .data(let value):
                try container.encode(ValueType.data, forKey: .type)
                try container.encode(value, forKey: .value)
            }
        }
    }

    struct JournalEntry: Codable {
        let key: String
        let before: StoredValue
        let after: StoredValue
        let beforeHash: String
        let afterHash: String
    }

    struct JournalValidation: Codable {
        let key: String
        let before: StoredValue
        let beforeHash: String
        let allowedHashes: [String]
    }

    struct Journal: Codable {
        let formatVersion: Int
        let migrationID: String
        let rulesetHash: String
        var state: JournalState
        var progress: Int
        let entries: [JournalEntry]
        let validations: [JournalValidation]
    }

    struct Snapshot {
        let sttProvider: APIProvider
        let sttModel: String?
        let polishProvider: APIProvider
        let polishModel: String?
        let userPresetsData: Data?
        let userPresets: [UserAPIPreset]
        let rawValues: [String: StoredValue]
    }

    static let validationKeys: Set<String> = [
        StorageKeys.splitAPISTTProvider,
        StorageKeys.splitAPISTTModel,
        StorageKeys.splitAPISTTBaseURL,
        StorageKeys.splitAPIPolishProvider,
        StorageKeys.splitAPIPolishModel,
        StorageKeys.splitAPIPolishBaseURL,
        StorageKeys.vowriteModes,
        StorageKeys.splitAPIUserPresets,
    ]

    static func preflight(defaults: UserDefaults) throws -> Snapshot {
        // Validate every raw split configuration field directly. This avoids
        // APIConfig fallbacks hiding a removed provider or wrong value type.
        let sttProviderRaw = try optionalString(defaults, key: StorageKeys.splitAPISTTProvider)
        let sttModel = try optionalString(defaults, key: StorageKeys.splitAPISTTModel)
        _ = try optionalString(defaults, key: StorageKeys.splitAPISTTBaseURL)
        let polishProviderRaw = try optionalString(defaults, key: StorageKeys.splitAPIPolishProvider)
        let polishModel = try optionalString(defaults, key: StorageKeys.splitAPIPolishModel)
        _ = try optionalString(defaults, key: StorageKeys.splitAPIPolishBaseURL)

        var rawValues: [String: StoredValue] = [:]
        for key in validationKeys {
            guard let value = storedValue(defaults, key: key) else {
                throw PreflightError.corrupt
            }
            rawValues[key] = value
        }

        let sttProvider: APIProvider
        if let sttProviderRaw {
            guard let decoded = APIProvider(rawValue: sttProviderRaw) else {
                throw PreflightError.corrupt
            }
            sttProvider = decoded
        } else {
            sttProvider = .groq
        }

        let polishProvider: APIProvider
        if let polishProviderRaw {
            guard let decoded = APIProvider(rawValue: polishProviderRaw) else {
                throw PreflightError.corrupt
            }
            polishProvider = decoded
        } else {
            polishProvider = .deepseek
        }

        if let rawModes = defaults.object(forKey: StorageKeys.vowriteModes) {
            guard let modeData = rawModes as? Data,
                  (try? JSONDecoder().decode([Mode].self, from: modeData)) != nil else {
                throw PreflightError.corrupt
            }
        }

        let userPresetsData: Data?
        let userPresets: [UserAPIPreset]
        if let rawPresets = defaults.object(forKey: StorageKeys.splitAPIUserPresets) {
            guard let presetData = rawPresets as? Data,
                  let decoded = try? JSONDecoder().decode([UserAPIPreset].self, from: presetData) else {
                throw PreflightError.corrupt
            }
            userPresetsData = presetData
            userPresets = decoded
        } else {
            userPresetsData = nil
            userPresets = []
        }

        return Snapshot(
            sttProvider: sttProvider,
            sttModel: sttModel,
            polishProvider: polishProvider,
            polishModel: polishModel,
            userPresetsData: userPresetsData,
            userPresets: userPresets,
            rawValues: rawValues
        )
    }

    static func makeValidations(
        rawValues: [String: StoredValue],
        entries: [JournalEntry]
    ) -> [JournalValidation]? {
        var validations: [JournalValidation] = []
        for key in rawValues.keys.sorted() {
            guard let value = rawValues[key], let initialHash = hash(value) else { return nil }
            var allowedHashes = [initialHash]
            if let entry = entries.first(where: { $0.key == key }),
               entry.afterHash != initialHash {
                allowedHashes.append(entry.afterHash)
            }
            validations.append(
                JournalValidation(
                    key: key,
                    before: value,
                    beforeHash: initialHash,
                    allowedHashes: allowedHashes.sorted()
                )
            )
        }
        return validations
    }

    static func makeEntries(from snapshot: Snapshot) -> [JournalEntry]? {
        var entries: [JournalEntry] = []

        if let oldModel = snapshot.sttModel {
            let newModel = ProviderModelSafetyRules.safeModel(
                providerID: snapshot.sttProvider.providerID,
                capability: .stt,
                storedModel: oldModel
            )
            if newModel != oldModel {
                guard let entry = makeEntry(
                    key: StorageKeys.splitAPISTTModel,
                    before: .string(oldModel),
                    after: .string(newModel)
                ) else { return nil }
                entries.append(entry)
            }
        }

        if let oldModel = snapshot.polishModel {
            let newModel = ProviderModelSafetyRules.safeModel(
                providerID: snapshot.polishProvider.providerID,
                capability: .polish,
                storedModel: oldModel
            )
            if newModel != oldModel {
                guard let entry = makeEntry(
                    key: StorageKeys.splitAPIPolishModel,
                    before: .string(oldModel),
                    after: .string(newModel)
                ) else { return nil }
                entries.append(entry)
            }
        }

        if let oldData = snapshot.userPresetsData {
            var presets = snapshot.userPresets
            var changed = false
            for index in presets.indices {
                let stt = presets[index].configuration.stt
                let safeSTT = ProviderModelSafetyRules.safeModel(
                    providerID: stt.provider.providerID,
                    capability: .stt,
                    storedModel: stt.model
                )
                if safeSTT != stt.model {
                    presets[index].configuration.stt.model = safeSTT
                    changed = true
                }

                let polish = presets[index].configuration.polish
                let safePolish = ProviderModelSafetyRules.safeModel(
                    providerID: polish.provider.providerID,
                    capability: .polish,
                    storedModel: polish.model
                )
                if safePolish != polish.model {
                    presets[index].configuration.polish.model = safePolish
                    changed = true
                }
            }

            if changed {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]
                guard let newData = try? encoder.encode(presets),
                      let entry = makeEntry(
                        key: StorageKeys.splitAPIUserPresets,
                        before: .data(oldData),
                        after: .data(newData)
                      ) else { return nil }
                entries.append(entry)
            }
        }

        return entries
    }

    static func storedValue(_ defaults: UserDefaults, key: String) -> StoredValue? {
        guard let raw = defaults.object(forKey: key) else { return .missing }
        if let value = raw as? String { return .string(value) }
        if let value = raw as? Data { return .data(value) }
        return nil
    }

    static func write(_ value: StoredValue, defaults: UserDefaults, key: String) {
        switch value {
        case .missing:
            defaults.removeObject(forKey: key)
        case .string(let string):
            defaults.set(string, forKey: key)
        case .data(let data):
            defaults.set(data, forKey: key)
        }
    }

    static func hash(_ value: StoredValue) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(value) else { return nil }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func loadJournal(at url: URL) -> Journal? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Journal.self, from: data)
    }

    static func writeJournal(_ journal: Journal, to url: URL) -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(journal) else { return false }
        do {
            // Foundation's `.atomic` writes a same-directory temporary file and
            // replaces the destination with rename(2), so a crash cannot leave
            // a partially encoded journal.
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    private enum PreflightError: Error {
        case corrupt
    }

    private static func optionalString(_ defaults: UserDefaults, key: String) throws -> String? {
        guard let raw = defaults.object(forKey: key) else { return nil }
        guard let value = raw as? String else { throw PreflightError.corrupt }
        return value
    }

    private static func makeEntry(
        key: String,
        before: StoredValue,
        after: StoredValue
    ) -> JournalEntry? {
        guard let beforeHash = hash(before), let afterHash = hash(after) else { return nil }
        return JournalEntry(
            key: key,
            before: before,
            after: after,
            beforeHash: beforeHash,
            afterHash: afterHash
        )
    }
}
