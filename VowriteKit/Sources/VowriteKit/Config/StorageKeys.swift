import Foundation

/// Centralized namespace for the string constants VowriteKit uses as
/// `UserDefaults` keys (read/written via `VowriteStorage.defaults`).
///
/// Why this exists: before this file, each Config/Auth type declared its own
/// private key constant, and `StorageMigration.keysToMigrate` independently
/// hand-copied the literal string into a second list. Those two copies could
/// (and did — see the "googleEmail"/"googleUserEmail" drift) silently
/// diverge. Centralizing the literal in one place means both sides reference
/// the same constant, so a rename or typo is a compile error instead of a
/// silent runtime data-loss bug.
///
/// This is constant extraction, not renaming: every value below is
/// byte-identical to the string literal it replaces.
public enum StorageKeys {

    // MARK: - Split API configuration (APIConfig)

    public static let splitAPISTTProvider = "splitAPI.stt.provider"
    public static let splitAPISTTModel = "splitAPI.stt.model"
    public static let splitAPISTTBaseURL = "splitAPI.stt.baseURL"
    public static let splitAPIPolishProvider = "splitAPI.polish.provider"
    public static let splitAPIPolishModel = "splitAPI.polish.model"
    public static let splitAPIPolishBaseURL = "splitAPI.polish.baseURL"
    public static let splitAPISelectedPresetID = "splitAPI.selectedPresetID"

    /// APIPreset — user-defined provider presets.
    public static let splitAPIUserPresets = "splitAPI.userPresets"

    /// APIConfigMigration — one-shot v0.1.x -> split-API migration flag.
    public static let splitAPIMigrationV1Complete = "splitAPI.migration.v1.complete"

    // MARK: - Modes (ModeManager)

    public static let vowriteModes = "vowriteModes"
    public static let vowriteCurrentModeId = "vowriteCurrentModeId"

    // MARK: - Output styles (OutputStyleManager)

    public static let vowriteOutputStyles = "vowriteOutputStyles"

    // MARK: - Prompt (PromptConfig)

    public static let promptUserPrompt = "promptUserPrompt"
    public static let promptUserPromptLocked = "promptUserPromptLocked"

    // MARK: - Vocabulary (VocabularyManager)

    public static let personalVocabulary = "personalVocabulary"

    // MARK: - Replacements (ReplacementManager, F-051)

    public static let vowriteReplacements = "vowriteReplacements"

    // MARK: - Language (LanguageConfig)

    public static let globalLanguage = "globalLanguage"

    // MARK: - Dictation stats (Engine/DictationEngine)
    // Declared here for StorageMigration coverage; DictationEngine's own call
    // sites are out of scope for this refactor (owned by Engine/, not Config/).

    public static let totalDictationTime = "totalDictationTime"
    public static let totalWords = "totalWords"
    public static let totalDictations = "totalDictations"

    // MARK: - Auth (AuthManager)

    public static let authMode = "authMode"
    public static let googleUserEmail = "googleUserEmail"
    public static let googleUserName = "googleUserName"

    // MARK: - Google Auth (GoogleAuthService)
    // Declared here for StorageMigration coverage; GoogleAuthService's own
    // call site is out of scope for this refactor (Auth/, not AuthManager).

    public static let googleOAuthClientID = "googleOAuthClientID"

    // MARK: - OAuth auth-method preference (KeyVault, MiniMax migration/purge)

    /// Prefix composed with a provider ID: "auth.method.\(providerID)".
    public static let authMethodPrefix = "auth.method."
    public static let authMethodKimi = authMethodPrefix + "kimi"
    public static let authMethodOpenAI = authMethodPrefix + "openai"

    // MARK: - Onboarding (platform AppStorage, e.g. VowriteIOS/App)

    public static let hasCompletedOnboarding = "hasCompletedOnboarding"

    // MARK: - Indicator preset (Animation/IndicatorTheme)

    public static let indicatorPreset = "indicatorPreset"

    // MARK: - Sound feedback (Audio/SoundFeedback)

    public static let soundFeedbackDisabled = "soundFeedbackDisabled"

    // MARK: - StorageMigration itself

    public static let storageMigrationV2Complete = "v2_storage_migrated"

    // MARK: - All declared keys

    /// Every key declared above. Used by `StorageMigrationTests` to assert
    /// `StorageMigration.keysToMigrate` stays a subset of this list, so a
    /// future key addition to one side can't silently drift from the other.
    public static let all: Set<String> = [
        splitAPISTTProvider, splitAPISTTModel, splitAPISTTBaseURL,
        splitAPIPolishProvider, splitAPIPolishModel, splitAPIPolishBaseURL,
        splitAPISelectedPresetID, splitAPIUserPresets, splitAPIMigrationV1Complete,
        vowriteModes, vowriteCurrentModeId,
        vowriteOutputStyles,
        promptUserPrompt, promptUserPromptLocked,
        personalVocabulary,
        vowriteReplacements,
        globalLanguage,
        totalDictationTime, totalWords, totalDictations,
        authMode, googleUserEmail, googleUserName,
        googleOAuthClientID,
        authMethodKimi, authMethodOpenAI,
        hasCompletedOnboarding,
        indicatorPreset,
        soundFeedbackDisabled,
        storageMigrationV2Complete,
    ]
}
