import XCTest
@testable import VowriteKit

/// Tests for `SpeculativePolish.displayPartial(forAccumulated:)` — the transform
/// applied to each streamed partial before it reaches `onPartial` (and the UI).
///
/// V-024: the streaming polish path surfaced the *raw* accumulated buffer, so a
/// reasoning model's `<think>` chain-of-thought flashed in the live partial while
/// only the final result was cleaned. Partials must be think-stripped too.
final class StreamingPartialTests: XCTestCase {

    func testInProgressOpenThinkTagYieldsEmptyPartial() {
        // Mid-stream: opening <think> seen, not yet closed → reasoning suppressed.
        XCTAssertEqual(
            SpeculativePolish.displayPartial(forAccumulated: "<think>let me reason about this"),
            ""
        )
    }

    func testClosedThinkBlockShowsOnlyTheAnswer() {
        XCTAssertEqual(
            SpeculativePolish.displayPartial(forAccumulated: "<think>reasoning</think>Hello"),
            "Hello"
        )
    }

    func testCleanPartialPassesThrough() {
        XCTAssertEqual(
            SpeculativePolish.displayPartial(forAccumulated: "Hello wor"),
            "Hello wor"
        )
    }

    /// Simulate tokens arriving one at a time (tags as whole tokens, the common
    /// real-world case): no emitted partial should ever contain the reasoning,
    /// and the last partial is the clean answer.
    func testTokenSequenceNeverLeaksReasoning() {
        let tokens = ["<think>", "the user said hi", "</think>", "Hello", " world"]
        var accumulated = ""
        var partials: [String] = []
        for token in tokens {
            accumulated += token
            partials.append(SpeculativePolish.displayPartial(forAccumulated: accumulated))
        }
        XCTAssertFalse(
            partials.contains { $0.contains("the user said hi") },
            "reasoning content must never appear in any streamed partial"
        )
        XCTAssertEqual(partials.last, "Hello world")
    }
}
