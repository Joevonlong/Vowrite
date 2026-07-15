import XCTest
@testable import VowriteKit

/// Tests for `KimiBaseURLRepairMigration`, the one-shot repair for APIConfig
/// entries corrupted by the old `stt`/`polish` setters persisting the
/// OAuth-resolved base URL instead of the plain configured one (see the setter
/// comments in APIConfig.swift). UserDefaults keys are cleared before/after each
/// test to avoid polluting real app state.
final class KimiBaseURLRepairMigrationTests: XCTestCase {

    private let flagKey = "kimi_baseurl_repair.v1.complete"
    private let sttProviderKey = "splitAPI.stt.provider"
    private let sttModelKey = "splitAPI.stt.model"
    private let sttBaseURLKey = "splitAPI.stt.baseURL"
    private let polishProviderKey = "splitAPI.polish.provider"
    private let polishModelKey = "splitAPI.polish.model"
    private let polishBaseURLKey = "splitAPI.polish.baseURL"

    private let kimiCodingURL = "https://api.kimi.com/coding/v1"

    override func setUp() {
        super.setUp()
        clearKeys()
    }

    override func tearDown() {
        clearKeys()
        super.tearDown()
    }

    private func clearKeys() {
        for key in [flagKey, sttProviderKey, sttModelKey, sttBaseURLKey,
                    polishProviderKey, polishModelKey, polishBaseURLKey] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    // MARK: - Pure decision

    func testStoredEqualToCodingURLIsRepairedToProviderDefault() {
        XCTAssertEqual(
            KimiBaseURLRepairMigration.repairedBaseURL(stored: kimiCodingURL, providerDefault: "https://api.groq.com/openai/v1"),
            "https://api.groq.com/openai/v1"
        )
    }

    func testStoredDifferentFromCodingURLIsUntouched() {
        XCTAssertNil(
            KimiBaseURLRepairMigration.repairedBaseURL(stored: "https://api.groq.com/openai/v1", providerDefault: "https://api.groq.com/openai/v1")
        )
    }

    func testEmptyStoredIsUntouched() {
        XCTAssertNil(KimiBaseURLRepairMigration.repairedBaseURL(stored: "", providerDefault: "https://api.groq.com/openai/v1"))
    }

    func testStoredCoincidingWithProviderDefaultUntouched() {
        // If a provider's own default ever legitimately equals the coding URL,
        // repairing would be a no-op anyway (repaired value == stored value),
        // but the function still reports "needs repair" — assert that shape
        // rather than assuming it's a no-repair case.
        XCTAssertEqual(
            KimiBaseURLRepairMigration.repairedBaseURL(stored: kimiCodingURL, providerDefault: kimiCodingURL),
            kimiCodingURL
        )
    }

    func testNearMissURLIsNotRepaired() {
        // Exact-match only — the stored value is already normalized by the time
        // it reaches this check, so no fuzzy matching is needed or wanted.
        XCTAssertNil(
            KimiBaseURLRepairMigration.repairedBaseURL(stored: "https://api.kimi.com/coding/v1/", providerDefault: "x")
        )
    }

    // MARK: - runIfNeeded integration

    func testRunIfNeededResetsCorruptedSTTBaseURL() {
        UserDefaults.standard.set(APIProvider.groq.rawValue, forKey: sttProviderKey)
        UserDefaults.standard.set(kimiCodingURL, forKey: sttBaseURLKey)

        KimiBaseURLRepairMigration.runIfNeeded()

        XCTAssertEqual(APIConfig.sttBaseURL, APIProvider.groq.defaultBaseURL)
    }

    func testRunIfNeededResetsCorruptedPolishBaseURL() {
        UserDefaults.standard.set(APIProvider.deepseek.rawValue, forKey: polishProviderKey)
        UserDefaults.standard.set(kimiCodingURL, forKey: polishBaseURLKey)

        KimiBaseURLRepairMigration.runIfNeeded()

        XCTAssertEqual(APIConfig.polishBaseURL, APIProvider.deepseek.defaultBaseURL)
    }

    func testRunIfNeededLeavesNonCorruptedBaseURLAlone() {
        UserDefaults.standard.set(APIProvider.groq.rawValue, forKey: sttProviderKey)
        UserDefaults.standard.set("https://custom.example.com/v1", forKey: sttBaseURLKey)

        KimiBaseURLRepairMigration.runIfNeeded()

        XCTAssertEqual(APIConfig.sttBaseURL, "https://custom.example.com/v1")
    }

    func testRunIfNeededOnlyRunsOnce() {
        UserDefaults.standard.set(APIProvider.groq.rawValue, forKey: sttProviderKey)
        UserDefaults.standard.set(kimiCodingURL, forKey: sttBaseURLKey)

        KimiBaseURLRepairMigration.runIfNeeded()
        // Simulate the corrupted value reappearing after the flag was already
        // set (shouldn't happen post-fix) — proves the guard short-circuits.
        UserDefaults.standard.set(kimiCodingURL, forKey: sttBaseURLKey)
        KimiBaseURLRepairMigration.runIfNeeded()

        XCTAssertEqual(APIConfig.sttBaseURL, kimiCodingURL)
    }
}
