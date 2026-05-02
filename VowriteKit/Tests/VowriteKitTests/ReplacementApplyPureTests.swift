import XCTest
@testable import VowriteKit

/// Tests for the pure-function path of ReplacementManager.apply(to:).
/// Specifically: when no rules are stored in UserDefaults, apply must return
/// the input unchanged (early return at the empty-rules guard).
final class ReplacementApplyPureTests: XCTestCase {
    private let storageKey = "vowriteReplacements"

    override func setUp() {
        super.setUp()
        // Ensure no rules are stored — isolates this test from other tests / app state.
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        super.tearDown()
    }

    func testEmptyRulesReturnsInputUnchanged() {
        let input = "Hello, 世界! Mixed CJK + ASCII text. 12345 — punctuation."
        let result = ReplacementManager.apply(to: input)
        XCTAssertEqual(result, input)
    }

    func testEmptyStringReturnsEmptyString() {
        XCTAssertEqual(ReplacementManager.apply(to: ""), "")
    }
}
