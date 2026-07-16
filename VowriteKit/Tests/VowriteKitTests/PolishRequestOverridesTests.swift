import XCTest
@testable import VowriteKit

/// F-073/F-082 — `applyPolishOverrides` merge semantics, including the F-082
/// `null` = "remove this key" rule used to omit parameters that newer models
/// reject outright (Claude Sonnet 5 / Opus 4.7+ 400 on non-default temperature).
final class PolishRequestOverridesTests: XCTestCase {

    private func basePayload() -> [String: Any] {
        [
            "model": "test-model",
            "temperature": 0.3,
            "max_tokens": 4096
        ]
    }

    func testNilOverridesIsNoOp() {
        var payload = basePayload()
        applyPolishOverrides(to: &payload, overrides: nil)
        XCTAssertEqual(payload.count, 3)
        XCTAssertEqual(payload["temperature"] as? Double, 0.3)
    }

    func testEmptyOverridesIsNoOp() {
        var payload = basePayload()
        applyPolishOverrides(to: &payload, overrides: [:])
        XCTAssertEqual(payload.count, 3)
    }

    func testScalarOverrideAddsKey() {
        var payload = basePayload()
        applyPolishOverrides(to: &payload, overrides: ["reasoning_effort": .string("minimal")])
        XCTAssertEqual(payload["reasoning_effort"] as? String, "minimal")
    }

    func testObjectOverrideAddsNestedDict() {
        var payload = basePayload()
        applyPolishOverrides(
            to: &payload,
            overrides: ["thinking": .object(["type": .string("disabled")])]
        )
        let thinking = payload["thinking"] as? [String: Any]
        XCTAssertEqual(thinking?["type"] as? String, "disabled")
    }

    func testOverrideWinsOverExistingKey() {
        var payload = basePayload()
        applyPolishOverrides(to: &payload, overrides: ["max_tokens": .int(1024)])
        XCTAssertEqual(payload["max_tokens"] as? Int, 1024)
    }

    func testNullOverrideRemovesExistingKey() {
        var payload = basePayload()
        applyPolishOverrides(to: &payload, overrides: ["temperature": .null])
        XCTAssertNil(payload["temperature"], "null override must remove the key entirely")
        XCTAssertFalse(payload.keys.contains("temperature"))
    }

    func testNullOverrideOnAbsentKeyIsHarmless() {
        var payload = basePayload()
        applyPolishOverrides(to: &payload, overrides: ["top_p": .null])
        XCTAssertFalse(payload.keys.contains("top_p"))
        XCTAssertEqual(payload.count, 3)
    }

    func testMixedNullAndValueOverrides() {
        var payload = basePayload()
        applyPolishOverrides(to: &payload, overrides: [
            "temperature": .null,
            "thinking": .object(["type": .string("disabled")])
        ])
        XCTAssertFalse(payload.keys.contains("temperature"))
        XCTAssertNotNil(payload["thinking"])
    }
}
