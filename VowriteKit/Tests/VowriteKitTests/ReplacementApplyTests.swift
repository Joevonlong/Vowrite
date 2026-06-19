import XCTest
@testable import VowriteKit

/// Tests for `ReplacementManager.apply(to:)` *with rules present* — the real
/// find/replace engine (length-sorted rules, CJK/ASCII flex-whitespace patterns,
/// ASCII word boundaries, case-insensitive). The existing ReplacementApplyPureTests
/// only cover the empty-rules early return.
final class ReplacementApplyTests: XCTestCase {
    private let storageKey = "vowriteReplacements"

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        super.tearDown()
    }

    private func setRules(_ rules: [ReplacementRule]) {
        guard let data = try? JSONEncoder().encode(rules) else {
            XCTFail("failed to encode replacement rules")
            return
        }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    func testBasicCJKReplacement() {
        setRules([ReplacementRule(trigger: "伏莱特", replacement: "Vowrite")])
        XCTAssertEqual(ReplacementManager.apply(to: "我用伏莱特写作"), "我用Vowrite写作")
    }

    func testCaseInsensitiveMatch() {
        setRules([ReplacementRule(trigger: "vowrite", replacement: "Vowrite")])
        XCTAssertEqual(ReplacementManager.apply(to: "I use VOWRITE daily"), "I use Vowrite daily")
    }

    func testASCIIWordBoundaryPreventsSubstringMatch() {
        setRules([ReplacementRule(trigger: "AI", replacement: "A.I.")])
        // "AI" must NOT match inside "FAIR".
        XCTAssertEqual(ReplacementManager.apply(to: "FAIR play"), "FAIR play")
    }

    func testASCIIWordBoundaryMatchesWholeWord() {
        setRules([ReplacementRule(trigger: "AI", replacement: "A.I.")])
        XCTAssertEqual(ReplacementManager.apply(to: "an AI model"), "an A.I. model")
    }

    func testLongerTriggerWinsOverShorter() {
        setRules([
            ReplacementRule(trigger: "ab", replacement: "Y"),
            ReplacementRule(trigger: "abc", replacement: "X")
        ])
        // The longer trigger must win, yielding "X" — not "Yc" (short rule first).
        XCTAssertEqual(ReplacementManager.apply(to: "abc"), "X")
    }

    func testFlexWhitespaceBetweenCJKAndASCII() {
        setRules([ReplacementRule(trigger: "我的Gmail", replacement: "my gmail")])
        // Trigger written without a space should still match "我的 Gmail".
        XCTAssertEqual(ReplacementManager.apply(to: "我的 Gmail 用户"), "my gmail 用户")
    }
}
