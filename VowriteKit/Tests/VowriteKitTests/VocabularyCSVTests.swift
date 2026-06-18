import XCTest
@testable import VowriteKit

/// Tests for `VocabularyManager.parseCSVWords(_:)` — the pure parse behind
/// F-074 vocabulary CSV import. Covers the Excel/Windows edge cases the importer
/// must survive: UTF-8 BOM, CRLF line endings, `#` comments, blank lines, and
/// surrounding whitespace. Dedup against existing words is `importCSV`'s job and
/// is intentionally NOT done here.
final class VocabularyCSVTests: XCTestCase {

    func testStripsLeadingBOM() {
        XCTAssertEqual(VocabularyManager.parseCSVWords("\u{FEFF}hello\nworld"), ["hello", "world"])
    }

    func testHandlesCRLFLineEndings() {
        XCTAssertEqual(VocabularyManager.parseCSVWords("alpha\r\nbeta"), ["alpha", "beta"])
    }

    func testSkipsCommentLines() {
        XCTAssertEqual(VocabularyManager.parseCSVWords("# Vowrite vocabulary export\nReactNative"), ["ReactNative"])
    }

    func testSkipsBlankLines() {
        XCTAssertEqual(VocabularyManager.parseCSVWords("a\n\n\n  \nb"), ["a", "b"])
    }

    func testTrimsSurroundingWhitespace() {
        XCTAssertEqual(VocabularyManager.parseCSVWords("  hello  \n\tworld\t"), ["hello", "world"])
    }

    func testPreservesOrderAndInFileDuplicates() {
        // parseCSVWords does not dedup; that is importCSV's responsibility.
        XCTAssertEqual(VocabularyManager.parseCSVWords("a\na\nb"), ["a", "a", "b"])
    }

    func testEmptyAndCommentOnlyInputReturnEmpty() {
        XCTAssertEqual(VocabularyManager.parseCSVWords(""), [])
        XCTAssertEqual(VocabularyManager.parseCSVWords("\u{FEFF}# only a comment\n"), [])
    }
}
