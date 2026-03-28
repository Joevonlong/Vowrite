import Foundation

/// Migrates v0.1.x UserDefaults.standard data to App Group UserDefaults.
/// iOS only. On macOS, VowriteStorage.defaults is .standard so this is a no-op.
public enum StorageMigration {
    private static let migrationKey = "v2_storage_migrated"

    /// All keys to migrate (confirmed from code)
    private static let keysToMigrate: [String] = [
        // APIConfig
        "splitAPI.stt.provider",
        "splitAPI.stt.model",
        "splitAPI.stt.baseURL",
        "splitAPI.polish.provider",
        "splitAPI.polish.model",
        "splitAPI.polish.baseURL",
        "splitAPI.selectedPresetID",

        // ModeManager
        "vowriteModes",          // Data (JSON)
        "vowriteCurrentModeId",  // String (UUID)

        // OutputStyleManager
        "vowriteOutputStyles",   // Data (JSON)

        // PromptConfig
        "promptUserPrompt",
        "promptUserPromptLocked",  // Bool

        // VocabularyManager
        "personalVocabulary",    // [String]

        // ReplacementManager (F-051)
        "vowriteReplacements",   // Data (JSON)

        // LanguageConfig
        "globalLanguage",

        // DictationEngine stats
        "totalDictationTime",    // Double
        "totalWords",            // Int
        "totalDictations",       // Int

        // APIPreset
        "splitAPI.userPresets",  // Data (JSON)

        // APIConfigMigration
        "splitAPI.migration.v1.complete",  // Bool

        // AuthManager
        "authMode",
        "googleEmail",
        "googleName",

        // GoogleAuthService
        "googleOAuthClientID",

        // Onboarding
        "hasCompletedOnboarding",  // Bool (AppStorage)
    ]

    public static func runIfNeeded() {
        let target = VowriteStorage.defaults

        // If target is .standard (macOS), skip
        guard target !== UserDefaults.standard else { return }

        // Already migrated, skip
        guard !target.bool(forKey: migrationKey) else { return }

        let source = UserDefaults.standard

        for key in keysToMigrate {
            guard let value = source.object(forKey: key) else { continue }
            // Only write if target doesn't already have this key
            if target.object(forKey: key) == nil {
                target.set(value, forKey: key)
            }
        }

        target.set(true, forKey: migrationKey)
        target.synchronize()
    }
}
