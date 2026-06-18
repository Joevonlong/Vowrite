import XCTest
@testable import VowriteKit

/// Tests for `HallucinationFilter.isHallucination(_:)` — the pure filter that
/// drops Whisper's silence/noise hallucinations ("Thank you for watching",
/// "[BLANK_AUDIO]", repeated phrases) before they reach the user's text.
final class HallucinationFilterTests: XCTestCase {

    // MARK: - Known blocklist phrases (characterization / regression guards)

    func testFiltersClassicWatchingHallucination() {
        XCTAssertTrue(HallucinationFilter.isHallucination("Thank you for watching"))
        XCTAssertTrue(HallucinationFilter.isHallucination("Thanks for watching."))
    }

    func testFiltersBlankAudioMarker() {
        XCTAssertTrue(HallucinationFilter.isHallucination("[BLANK_AUDIO]"))
        XCTAssertTrue(HallucinationFilter.isHallucination("[silence]"))
    }

    func testFiltersCJKAndMusicMarkers() {
        XCTAssertTrue(HallucinationFilter.isHallucination("谢谢"))
        XCTAssertTrue(HallucinationFilter.isHallucination("감사합니다"))
        XCTAssertTrue(HallucinationFilter.isHallucination("♪"))
    }

    func testMatchingIsCaseInsensitiveAndTrimmed() {
        XCTAssertTrue(HallucinationFilter.isHallucination("  THANK YOU  "))
        XCTAssertTrue(HallucinationFilter.isHallucination("Okay."))
    }

    // MARK: - Repeated-phrase detection

    func testFiltersRepeatedSentencePhrase() {
        XCTAssertTrue(HallucinationFilter.isHallucination("Thank you. Thank you. Thank you."))
    }

    func testFiltersRepeatedSingleWord() {
        XCTAssertTrue(HallucinationFilter.isHallucination("you you you you"))
    }

    // MARK: - Genuine speech must pass through (no over-filtering)

    func testRealSentenceIsNotFiltered() {
        XCTAssertFalse(HallucinationFilter.isHallucination("Let's ship the release on Friday afternoon."))
    }

    func testRealMixedLanguageSentenceIsNotFiltered() {
        XCTAssertFalse(HallucinationFilter.isHallucination("帮我把这个 PR 合并到 main 分支"))
    }

    // MARK: - NEW: punctuation/symbol-only transcripts are never real speech

    func testFiltersExclamationOnly() {
        XCTAssertTrue(HallucinationFilter.isHallucination("!!!"))
    }

    func testFiltersMixedPunctuationOnly() {
        XCTAssertTrue(HallucinationFilter.isHallucination("?!"))
    }

    func testFiltersCJKPunctuationOnly() {
        XCTAssertTrue(HallucinationFilter.isHallucination("。。"))
    }

    func testTextContainingDigitsIsNotPunctuationOnly() {
        // Has alphanumeric content → not flagged by the punctuation-only rule.
        XCTAssertFalse(HallucinationFilter.isHallucination("12 34"))
    }

    func testEmptyStringIsNotFlagged() {
        // Empty input is handled upstream; the filter leaves it as not-a-hallucination.
        XCTAssertFalse(HallucinationFilter.isHallucination(""))
        XCTAssertFalse(HallucinationFilter.isHallucination("   "))
    }
}
