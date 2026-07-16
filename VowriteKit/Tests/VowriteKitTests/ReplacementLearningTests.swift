import XCTest
@testable import VowriteKit

/// Tests for F-080 (Personalization visibility + learning controls):
/// - `ReplacementRule.source`/`createdAt` backward-compat decode.
/// - The pure `learnedCount(in:)` / `recentLearned(in:limit:)` /
///   `removingLearned(from:)` helpers that back the instance API
///   (`learnedCount`, `recentLearned(limit:)`, `clearLearned()`).
/// - `ReplacementManager.learningEnabled` default + persistence.
///
/// These pure helpers are tested directly on plain `[ReplacementRule]` arrays
/// rather than through the `@MainActor` `ReplacementManager.shared` singleton,
/// matching the existing ReplacementApplyPureTests philosophy: no
/// actor-isolation ceremony, no shared-singleton state bleeding between tests.
final class ReplacementLearningTests: XCTestCase {

    // MARK: - Backward-compat decode (source, createdAt)

    func testLegacyJSONWithoutSourceOrCreatedAtDecodesAsManualWithNilDate() throws {
        // Pre-F-080 persisted shape: only id/trigger/replacement.
        let legacyJSON = """
        {"id":"11111111-1111-1111-1111-111111111111","trigger":"伏莱特","replacement":"Vowrite"}
        """
        let data = Data(legacyJSON.utf8)
        let decoded = try JSONDecoder().decode(ReplacementRule.self, from: data)

        XCTAssertEqual(decoded.trigger, "伏莱特")
        XCTAssertEqual(decoded.replacement, "Vowrite")
        XCTAssertEqual(decoded.source, .manual, "legacy rules with no `source` key must decode as .manual")
        XCTAssertNil(decoded.createdAt, "legacy rules with no `createdAt` key must decode as nil")
    }

    func testLegacyArrayOfRulesAllDecodeAsManual() throws {
        let legacyJSON = """
        [
          {"id":"11111111-1111-1111-1111-111111111111","trigger":"a","replacement":"A"},
          {"id":"22222222-2222-2222-2222-222222222222","trigger":"b","replacement":"B"}
        ]
        """
        let data = Data(legacyJSON.utf8)
        let decoded = try JSONDecoder().decode([ReplacementRule].self, from: data)
        XCTAssertEqual(decoded.count, 2)
        XCTAssertTrue(decoded.allSatisfy { $0.source == .manual })
    }

    func testLearnedRuleRoundtripsThroughJSONPreservingSourceAndCreatedAt() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let original = ReplacementRule(trigger: "语音识别", replacement: "Vowrite", source: .learned, createdAt: date)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ReplacementRule.self, from: data)

        XCTAssertEqual(decoded.source, .learned)
        XCTAssertEqual(decoded.createdAt, date)
        XCTAssertEqual(decoded, original)
    }

    func testDefaultInitIsManualWithNilCreatedAt() {
        let rule = ReplacementRule(trigger: "x", replacement: "y")
        XCTAssertEqual(rule.source, .manual)
        XCTAssertNil(rule.createdAt)
    }

    // MARK: - learnedCount(in:)

    func testLearnedCountCountsOnlyLearnedRules() {
        let rules = [
            ReplacementRule(trigger: "a", replacement: "A", source: .manual),
            ReplacementRule(trigger: "b", replacement: "B", source: .learned),
            ReplacementRule(trigger: "c", replacement: "C", source: .learned),
        ]
        XCTAssertEqual(ReplacementManager.learnedCount(in: rules), 2)
    }

    func testLearnedCountIsZeroForEmptyOrAllManual() {
        XCTAssertEqual(ReplacementManager.learnedCount(in: []), 0)
        let allManual = [ReplacementRule(trigger: "a", replacement: "A", source: .manual)]
        XCTAssertEqual(ReplacementManager.learnedCount(in: allManual), 0)
    }

    // MARK: - recentLearned(in:limit:)

    func testRecentLearnedExcludesManualAndNilTimestampRules() {
        let now = Date()
        let rules = [
            ReplacementRule(trigger: "manual", replacement: "M", source: .manual, createdAt: now),
            ReplacementRule(trigger: "no-date", replacement: "N", source: .learned, createdAt: nil),
            ReplacementRule(trigger: "dated", replacement: "D", source: .learned, createdAt: now),
        ]
        let recent = ReplacementManager.recentLearned(in: rules, limit: 3)
        XCTAssertEqual(recent.map(\.trigger), ["dated"])
    }

    func testRecentLearnedSortsNewestFirstAndRespectsLimit() {
        let base = Date(timeIntervalSince1970: 1_000_000)
        let rules = [
            ReplacementRule(trigger: "oldest", replacement: "1", source: .learned, createdAt: base),
            ReplacementRule(trigger: "newest", replacement: "3", source: .learned, createdAt: base.addingTimeInterval(200)),
            ReplacementRule(trigger: "middle", replacement: "2", source: .learned, createdAt: base.addingTimeInterval(100)),
        ]
        let recent = ReplacementManager.recentLearned(in: rules, limit: 2)
        XCTAssertEqual(recent.map(\.trigger), ["newest", "middle"], "must be sorted newest-first and capped at `limit`")
    }

    func testRecentLearnedDefaultLimitIsThree() {
        let base = Date(timeIntervalSince1970: 1_000_000)
        let rules = (0..<5).map { i in
            ReplacementRule(trigger: "t\(i)", replacement: "r\(i)", source: .learned, createdAt: base.addingTimeInterval(Double(i)))
        }
        XCTAssertEqual(ReplacementManager.recentLearned(in: rules).count, 3)
    }

    // MARK: - removingLearned(from:) — backs clearLearned()

    func testRemovingLearnedKeepsOnlyManualRules() {
        let rules = [
            ReplacementRule(trigger: "a", replacement: "A", source: .manual),
            ReplacementRule(trigger: "b", replacement: "B", source: .learned),
            ReplacementRule(trigger: "c", replacement: "C", source: .manual),
            ReplacementRule(trigger: "d", replacement: "D", source: .learned),
        ]
        let remaining = ReplacementManager.removingLearned(from: rules)
        XCTAssertEqual(remaining.map(\.trigger), ["a", "c"])
        XCTAssertTrue(remaining.allSatisfy { $0.source == .manual })
    }

    func testRemovingLearnedFromAllLearnedYieldsEmpty() {
        let rules = [ReplacementRule(trigger: "a", replacement: "A", source: .learned)]
        XCTAssertTrue(ReplacementManager.removingLearned(from: rules).isEmpty)
    }

    func testRemovingLearnedFromAllManualIsUnchanged() {
        let rules = [
            ReplacementRule(trigger: "a", replacement: "A", source: .manual),
            ReplacementRule(trigger: "b", replacement: "B", source: .manual),
        ]
        XCTAssertEqual(ReplacementManager.removingLearned(from: rules), rules)
    }

    // MARK: - learningEnabled (default-ON + persistence)

    private let learningKey = "autoLearnCorrections"

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: learningKey)
        super.tearDown()
    }

    func testLearningEnabledDefaultsToTrueWhenKeyAbsent() {
        UserDefaults.standard.removeObject(forKey: learningKey)
        XCTAssertTrue(ReplacementManager.learningEnabled, "master toggle must default ON per spec")
    }

    func testLearningEnabledPersistsFalseAfterSet() {
        ReplacementManager.learningEnabled = false
        XCTAssertFalse(ReplacementManager.learningEnabled)
        XCTAssertEqual(UserDefaults.standard.bool(forKey: learningKey), false)
    }

    func testLearningEnabledPersistsTrueAfterExplicitSet() {
        ReplacementManager.learningEnabled = false
        ReplacementManager.learningEnabled = true
        XCTAssertTrue(ReplacementManager.learningEnabled)
    }

    func testLearningEnabledSharesKeyWithLegacyAutoLearnCorrectionsToggle() {
        // Simulates the pre-existing Mac GeneralPage `@AppStorage("autoLearnCorrections")`
        // toggle writing `false` directly to UserDefaults.standard — the new
        // master toggle must observe that same value (see ReplacementManager.learningEnabled).
        UserDefaults.standard.set(false, forKey: learningKey)
        XCTAssertFalse(ReplacementManager.learningEnabled)
    }
}
