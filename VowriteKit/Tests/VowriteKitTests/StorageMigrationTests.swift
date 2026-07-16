import XCTest
@testable import VowriteKit

/// Characterization tests for `StorageMigration.keysToMigrate`.
///
/// `AuthManager` actually stores Google account info under "googleUserEmail" /
/// "googleUserName" (see `AuthManager.googleEmailKey` / `.googleNameKey`).
/// The migration list used to reference "googleEmail" / "googleName" instead —
/// keys that were never written anywhere — so a returning iOS user's signed-in
/// Google session silently vanished after the standard -> App Group move.
final class StorageMigrationTests: XCTestCase {

    func testKeysToMigrateContainsRealGoogleAuthKeys() {
        XCTAssertTrue(
            StorageMigration.keysToMigrate.contains("googleUserEmail"),
            "keysToMigrate must contain the real AuthManager key \"googleUserEmail\""
        )
        XCTAssertTrue(
            StorageMigration.keysToMigrate.contains("googleUserName"),
            "keysToMigrate must contain the real AuthManager key \"googleUserName\""
        )
    }

    func testKeysToMigrateDoesNotContainStaleNonExistentGoogleKeys() {
        XCTAssertFalse(
            StorageMigration.keysToMigrate.contains("googleEmail"),
            "\"googleEmail\" is never written by AuthManager — it must not appear in the migration list"
        )
        XCTAssertFalse(
            StorageMigration.keysToMigrate.contains("googleName"),
            "\"googleName\" is never written by AuthManager — it must not appear in the migration list"
        )
    }

    func testKeysToMigrateContainsAuditedMissingPreferenceKeys() {
        // IndicatorTheme.current now routes through VowriteStorage.defaults
        // (previously bypassed it via UserDefaults.standard directly) and
        // SoundFeedback's toggle predates this migration list — both are
        // user preferences that must survive the standard -> App Group move.
        for key in ["indicatorPreset", "soundFeedbackDisabled"] {
            XCTAssertTrue(
                StorageMigration.keysToMigrate.contains(key),
                "keysToMigrate must contain user-preference key \"\(key)\""
            )
        }
    }

    func testKeysToMigrateContainsActiveOAuthMethodPreferences() {
        // Kimi Code and OpenAI Codex are the two providers with functional
        // OAuth sign-in; losing "auth.method.*" on migration would silently
        // revert a signed-in user back to API-key mode.
        for key in ["auth.method.kimi", "auth.method.openai"] {
            XCTAssertTrue(
                StorageMigration.keysToMigrate.contains(key),
                "keysToMigrate must contain active OAuth preference key \"\(key)\""
            )
        }
    }

    func testKeysToMigrateHasNoDuplicates() {
        let keys = StorageMigration.keysToMigrate
        XCTAssertEqual(keys.count, Set(keys).count, "keysToMigrate must not contain duplicate entries")
    }

    // MARK: - StorageKeys subset guard

    /// Locks in the invariant that every key StorageMigration copies is a key
    /// StorageKeys actually declares. Without this, a future addition to one
    /// list but not the other could silently reintroduce the exact class of
    /// drift bug this file's fix addresses (a migrated key that doesn't match
    /// any real stored key, or a real key that's missing from migration).
    func testKeysToMigrateIsSubsetOfStorageKeys() {
        let migrated = Set(StorageMigration.keysToMigrate)
        let missing = migrated.subtracting(StorageKeys.all)
        XCTAssertTrue(
            missing.isEmpty,
            "StorageMigration.keysToMigrate contains keys not declared in StorageKeys.all: \(missing)"
        )
    }
}
