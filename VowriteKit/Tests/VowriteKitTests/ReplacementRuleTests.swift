import XCTest
@testable import VowriteKit

final class ReplacementRuleTests: XCTestCase {
    func testRoundtripPreservesAllFields() throws {
        let original = ReplacementRule(trigger: "伏莱特", replacement: "Vowrite")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ReplacementRule.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.trigger, original.trigger)
        XCTAssertEqual(decoded.replacement, original.replacement)
    }

    func testTwoRulesWithSameContentHaveDistinctIDs() {
        let a = ReplacementRule(trigger: "x", replacement: "y")
        let b = ReplacementRule(trigger: "x", replacement: "y")
        XCTAssertNotEqual(a.id, b.id)
    }
}
