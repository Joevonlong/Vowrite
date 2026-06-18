import XCTest
@testable import VowriteKit

/// Tests for `String.strippingThinkTags()` — the pure function that removes
/// reasoning-model chain-of-thought (`<think>…</think>`) from LLM polish output
/// before it reaches the user's text.
///
/// Real-world formats covered (see open-webui #9823, #9193 and DeepSeek API docs):
/// reasoning models emit `<think>…</think>` in the `content` stream, but the
/// DeepSeek-R1 chat-template regression drops the *opening* tag, leaving an
/// orphan `</think>` with the reasoning in front of it. Both must be stripped,
/// case-insensitively, without ever touching legitimate cleaned text.
final class ThinkTagStrippingTests: XCTestCase {

    // MARK: - New behavior (drives implementation)

    /// DeepSeek-R1 broken-open-tag case: reasoning arrives with no `<think>`,
    /// terminated by an orphan `</think>`. Everything up to and including the
    /// close tag is chain-of-thought and must be removed.
    func testStripsOrphanLeadingCloseTag() {
        let input = "Let me reconsider the phrasing here.</think>Final polished answer."
        XCTAssertEqual(input.strippingThinkTags(), "Final polished answer.")
    }

    /// Same orphan case but with the newline padding DeepSeek emits around tags.
    func testStripsOrphanLeadingCloseTagWithNewlines() {
        let input = "Okay, the user wants this cleaned up.\n\n</think>\n\nHello world"
        XCTAssertEqual(input.strippingThinkTags(), "Hello world")
    }

    /// Tag casing varies across providers/proxies; matching must be case-insensitive.
    func testCaseInsensitiveClosedTags() {
        let input = "<THINK>internal reasoning</THINK>Answer"
        XCTAssertEqual(input.strippingThinkTags(), "Answer")
    }

    // MARK: - Existing behavior (regression guards)

    /// Well-formed closed pair — the canonical DeepSeek/QwQ format.
    func testStripsClosedThinkTags() {
        let input = "<think>step by step reasoning</think>Cleaned text"
        XCTAssertEqual(input.strippingThinkTags(), "Cleaned text")
    }

    /// Closed pair with surrounding whitespace/newlines (typical streamed shape).
    func testStripsClosedThinkTagsWithNewlines() {
        let input = "<think>\nLet me reason about this.\n</think>\n\nHello there"
        XCTAssertEqual(input.strippingThinkTags(), "Hello there")
    }

    /// Truncated/streaming cutoff: an unclosed `<think>` to end of string.
    func testStripsTruncatedOpenTag() {
        let input = "<think>reasoning that never gets a closing tag"
        XCTAssertEqual(input.strippingThinkTags(), "")
    }

    /// Multiple think blocks are all removed; intervening real text is kept.
    func testStripsMultipleThinkBlocks() {
        let input = "<think>a</think>Keep one<think>b</think> keep two"
        XCTAssertEqual(input.strippingThinkTags(), "Keep one keep two")
    }

    // MARK: - Must NOT over-strip

    /// Plain output with no tags must pass through unchanged (after trim).
    func testPassesThroughPlainText() {
        let input = "This is a normal cleaned sentence."
        XCTAssertEqual(input.strippingThinkTags(), "This is a normal cleaned sentence.")
    }

    /// The word "think" in prose is not a tag and must be preserved.
    func testPreservesProseContainingWordThink() {
        let input = "I think we should ship this on Friday."
        XCTAssertEqual(input.strippingThinkTags(), "I think we should ship this on Friday.")
    }

    /// Empty input stays empty.
    func testEmptyStringReturnsEmpty() {
        XCTAssertEqual("".strippingThinkTags(), "")
    }
}
