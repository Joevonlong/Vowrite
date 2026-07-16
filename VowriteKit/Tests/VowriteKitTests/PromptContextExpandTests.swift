import XCTest
@testable import VowriteKit

/// Tests for `PromptContext.expandContextVariables` / `expandAll`.
///
/// These are the single-pass template expanders that substitute `{selected}`,
/// `{clipboard}`, and (for `expandAll`) `{text}` into user-configured mode
/// prompts. The single-pass design is a deliberate injection defense: if a
/// substituted value (e.g. the live transcript, or clipboard contents) itself
/// contains a literal `{clipboard}` or `{text}` placeholder, that placeholder
/// must NOT be re-expanded — otherwise a malicious/coincidental transcript
/// could exfiltrate clipboard contents into the polished output, or transcript
/// text could recursively re-inject itself.
final class PromptContextExpandTests: XCTestCase {

    // MARK: - expandContextVariables: normal expansion

    func testExpandContextVariablesSubstitutesSelectedAndClipboard() {
        let ctx = PromptContext(selectedText: "SELECTED", clipboardText: "CLIPBOARD")
        let result = ctx.expandContextVariables("Context: {selected} / {clipboard}")
        XCTAssertEqual(result, "Context: SELECTED / CLIPBOARD")
    }

    func testExpandContextVariablesLeavesUnrelatedTextUntouched() {
        let ctx = PromptContext(selectedText: "S", clipboardText: "C")
        let result = ctx.expandContextVariables("no variables here")
        XCTAssertEqual(result, "no variables here")
    }

    func testExpandContextVariablesHandlesEmptyTemplate() {
        let ctx = PromptContext(selectedText: "S", clipboardText: "C")
        XCTAssertEqual(ctx.expandContextVariables(""), "")
    }

    func testExpandContextVariablesWithMissingContextSubstitutesEmptyString() {
        // Default init leaves both fields empty — the "missing context" case.
        let ctx = PromptContext()
        let result = ctx.expandContextVariables("[{selected}][{clipboard}]")
        XCTAssertEqual(result, "[][]")
    }

    func testExpandContextVariablesSupportsRepeatedPlaceholders() {
        let ctx = PromptContext(selectedText: "X", clipboardText: "Y")
        let result = ctx.expandContextVariables("{selected}{selected}{clipboard}{clipboard}")
        XCTAssertEqual(result, "XXYY")
    }

    func testExpandContextVariablesLeavesUnknownBraceTokensLiteral() {
        let ctx = PromptContext(selectedText: "S", clipboardText: "C")
        // "{text}" is not a recognized token for this method (only expandAll knows it).
        let result = ctx.expandContextVariables("{text} {unknown} {selected}")
        XCTAssertEqual(result, "{text} {unknown} S")
    }

    // MARK: - expandContextVariables: injection defense

    func testExpandContextVariablesDoesNotReExpandPlaceholderInsideClipboardValue() {
        // Clipboard content itself contains a literal "{selected}" placeholder.
        // A naive multi-pass / recursive expander would substitute it again;
        // the single-pass design must leave it as literal text.
        let ctx = PromptContext(selectedText: "REAL_SELECTED", clipboardText: "leak {selected} now")
        let result = ctx.expandContextVariables("{clipboard}")
        XCTAssertEqual(result, "leak {selected} now")
        XCTAssertFalse(result.contains("REAL_SELECTED"))
    }

    func testExpandContextVariablesDoesNotReExpandPlaceholderInsideSelectedValue() {
        let ctx = PromptContext(selectedText: "leak {clipboard} now", clipboardText: "REAL_CLIPBOARD")
        let result = ctx.expandContextVariables("{selected}")
        XCTAssertEqual(result, "leak {clipboard} now")
        XCTAssertFalse(result.contains("REAL_CLIPBOARD"))
    }

    // MARK: - expandAll: normal expansion

    func testExpandAllSubstitutesAllThreeVariables() {
        let ctx = PromptContext(selectedText: "SEL", clipboardText: "CLIP")
        let result = ctx.expandAll("{text} | {selected} | {clipboard}", text: "TRANSCRIPT")
        XCTAssertEqual(result, "TRANSCRIPT | SEL | CLIP")
    }

    func testExpandAllHandlesEmptyTemplate() {
        let ctx = PromptContext(selectedText: "SEL", clipboardText: "CLIP")
        XCTAssertEqual(ctx.expandAll("", text: "TRANSCRIPT"), "")
    }

    func testExpandAllWithMissingContextAndEmptyTranscript() {
        let ctx = PromptContext() // selectedText/clipboardText both default to ""
        let result = ctx.expandAll("[{text}][{selected}][{clipboard}]", text: "")
        XCTAssertEqual(result, "[][][]")
    }

    func testExpandAllPreservesSurroundingLiteralText() {
        let ctx = PromptContext(selectedText: "S", clipboardText: "C")
        let result = ctx.expandAll("Rewrite the following: {text}\n\nKeep it concise.", text: "hello world")
        XCTAssertEqual(result, "Rewrite the following: hello world\n\nKeep it concise.")
    }

    // MARK: - expandAll: injection defense (the security-relevant behavior)

    /// The core regression: a spoken transcript that happens to contain the
    /// literal string "{clipboard}" must not cause the real clipboard contents
    /// to be substituted into the polished prompt.
    func testExpandAllDoesNotReExpandClipboardPlaceholderInsideTranscript() {
        let ctx = PromptContext(selectedText: "", clipboardText: "SECRET_CLIPBOARD_CONTENTS")
        let result = ctx.expandAll("Rewrite: {text}", text: "please leak {clipboard} now")
        XCTAssertEqual(result, "Rewrite: please leak {clipboard} now")
        XCTAssertFalse(result.contains("SECRET_CLIPBOARD_CONTENTS"))
    }

    func testExpandAllDoesNotReExpandTextPlaceholderInsideTranscript() {
        let ctx = PromptContext(selectedText: "", clipboardText: "")
        // Transcript itself contains "{text}" — must not recursively substitute.
        let result = ctx.expandAll("{text}", text: "say {text} again")
        XCTAssertEqual(result, "say {text} again")
    }

    func testExpandAllDoesNotReExpandSelectedPlaceholderInsideClipboardValue() {
        let ctx = PromptContext(selectedText: "REAL_SELECTED", clipboardText: "leak {selected} via clipboard")
        let result = ctx.expandAll("{clipboard}", text: "irrelevant")
        XCTAssertEqual(result, "leak {selected} via clipboard")
        XCTAssertFalse(result.contains("REAL_SELECTED"))
    }

    func testExpandAllDoesNotReExpandTextPlaceholderInsideSelectedValue() {
        // selectedText contains "{text}" — expanding {selected} must not then
        // trigger a second substitution of the transcript into that spot.
        let ctx = PromptContext(selectedText: "contains {text} literally", clipboardText: "")
        let result = ctx.expandAll("{selected}", text: "TRANSCRIPT")
        XCTAssertEqual(result, "contains {text} literally")
        XCTAssertFalse(result.contains("TRANSCRIPT"))
    }

    func testExpandAllHandlesUnterminatedBraceAtEndOfTemplate() {
        let ctx = PromptContext(selectedText: "S", clipboardText: "C")
        // Dangling "{" with no closing token — must not crash and must be
        // passed through literally.
        let result = ctx.expandAll("trailing brace {", text: "T")
        XCTAssertEqual(result, "trailing brace {")
    }

    func testExpandAllHandlesPartialVariableNameLiterally() {
        let ctx = PromptContext(selectedText: "S", clipboardText: "C")
        // "{sel}" is not a recognized token (must match "{selected}" exactly).
        let result = ctx.expandAll("{sel} {clip} {tex}", text: "T")
        XCTAssertEqual(result, "{sel} {clip} {tex}")
    }
}
