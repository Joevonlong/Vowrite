import Foundation

/// Migrates v0.1.x UserDefaults.standard data to App Group UserDefaults.
/// iOS only. On macOS, VowriteStorage.defaults is .standard so this is a no-op.
public enum StorageMigration {
    private static let migrationKey = StorageKeys.storageMigrationV2Complete

    /// All keys to migrate (confirmed from code).
    /// Internal (not private) so tests can assert this list stays in sync
    /// with the real keys the Kit writes (see StorageMigrationTests).
    static let keysToMigrate: [String] = [
        // APIConfig
        StorageKeys.splitAPISTTProvider,
        StorageKeys.splitAPISTTModel,
        StorageKeys.splitAPISTTBaseURL,
        StorageKeys.splitAPIPolishProvider,
        StorageKeys.splitAPIPolishModel,
        StorageKeys.splitAPIPolishBaseURL,
        StorageKeys.splitAPISelectedPresetID,

        // ModeManager
        StorageKeys.vowriteModes,          // Data (JSON)
        StorageKeys.vowriteCurrentModeId,  // String (UUID)

        // OutputStyleManager
        StorageKeys.vowriteOutputStyles,   // Data (JSON)

        // PromptConfig
        StorageKeys.promptUserPrompt,
        StorageKeys.promptUserPromptLocked,  // Bool

        // VocabularyManager
        StorageKeys.personalVocabulary,    // [String]

        // ReplacementManager (F-051)
        StorageKeys.vowriteReplacements,   // Data (JSON)

        // LanguageConfig
        StorageKeys.globalLanguage,

        // DictationEngine stats
        StorageKeys.totalDictationTime,    // Double
        StorageKeys.totalWords,            // Int
        StorageKeys.totalDictations,       // Int

        // APIPreset
        StorageKeys.splitAPIUserPresets,  // Data (JSON)

        // APIConfigMigration
        StorageKeys.splitAPIMigrationV1Complete,  // Bool

        // AuthManager
        StorageKeys.authMode,
        StorageKeys.googleUserEmail,  // AuthManager.googleEmailKey — was incorrectly "googleEmail"
        StorageKeys.googleUserName,   // AuthManager.googleNameKey — was incorrectly "googleName"

        // GoogleAuthService
        StorageKeys.googleOAuthClientID,

        // Onboarding
        StorageKeys.hasCompletedOnboarding,  // Bool (AppStorage)

        // IndicatorTheme (Animation) — now routed through VowriteStorage.defaults
        // instead of bypassing it via UserDefaults.standard directly.
        StorageKeys.indicatorPreset,

        // SoundFeedback (Audio) — user preference, missing from the original list.
        StorageKeys.soundFeedbackDisabled,  // Bool (inverted: stored value means "disabled")

        // KeyVault — preferred auth method ("oauth" | "apiKey") per provider.
        // Only Kimi Code and OpenAI Codex have functional OAuth today; MiniMax's
        // OAuth state is deliberately excluded — it was never functional and is
        // one-shot purged by MiniMaxOAuthPurge, which would just remove it again.
        StorageKeys.authMethodKimi,
        StorageKeys.authMethodOpenAI,
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
