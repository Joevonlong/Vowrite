import XCTest
@testable import VowriteKit

/// F-078: a new builtin "Markdown" OutputStyle. Verifies it's present in the
/// catalog, its instruction covers the required GFM syntax mappings, the
/// pre-existing 7 builtins are untouched, and the user-style merge logic
/// (which backfills newly-added builtins into a saved user array) still works
/// now that there are 8 builtins instead of 7.
final class MarkdownOutputStyleTests: XCTestCase {
    private let stylesKey = "vowriteOutputStyles"

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: stylesKey)
        super.tearDown()
    }

    // MARK: - Catalog

    func testBuiltinCatalogContainsMarkdown() {
        guard let style = OutputStyle.builtinStyles.first(where: { $0.name == "Markdown" }) else {
            XCTFail("expected a builtin OutputStyle named 'Markdown'")
            return
        }
        XCTAssertTrue(style.isBuiltin)
        XCTAssertFalse(style.templatePrompt.isEmpty)
        XCTAssertFalse(style.description.isEmpty)
        XCTAssertFalse(style.icon.isEmpty)
    }

    func testMarkdownInstructionMentionsHeadingsAndCodeFences() {
        guard let style = OutputStyle.builtinStyles.first(where: { $0.name == "Markdown" }) else {
            XCTFail("expected a builtin OutputStyle named 'Markdown'")
            return
        }
        let instruction = style.templatePrompt.lowercased()
        XCTAssertTrue(instruction.contains("heading"), "instruction should mention headings")
        XCTAssertTrue(instruction.contains("fenced"), "instruction should mention fenced code blocks")
    }

    func testMarkdownInstructionMentionsListsEmphasisAndInlineCode() {
        guard let style = OutputStyle.builtinStyles.first(where: { $0.name == "Markdown" }) else {
            XCTFail("expected a builtin OutputStyle named 'Markdown'")
            return
        }
        let instruction = style.templatePrompt.lowercased()
        XCTAssertTrue(instruction.contains("list"), "instruction should mention lists")
        XCTAssertTrue(instruction.contains("bold"), "instruction should mention bold/emphasis")
        XCTAssertTrue(instruction.contains("`code`") || instruction.contains("inline"),
                      "instruction should mention inline code")
    }

    // MARK: - Existing builtins unaffected

    func testExistingSevenBuiltinsUnchanged() {
        let expected: [(id: String, name: String)] = [
            ("00000000-0000-0000-0001-000000000001", "None"),
            ("00000000-0000-0000-0001-000000000002", "Bullet List"),
            ("00000000-0000-0000-0001-000000000003", "Numbered List"),
            ("00000000-0000-0000-0001-000000000004", "Email"),
            ("00000000-0000-0000-0001-000000000005", "Meeting Notes"),
            ("00000000-0000-0000-0001-000000000006", "Social Post"),
            ("00000000-0000-0000-0001-000000000007", "Technical Doc")
        ]
        for (idString, name) in expected {
            let id = UUID(uuidString: idString)!
            guard let style = OutputStyle.builtinStyles.first(where: { $0.id == id }) else {
                XCTFail("expected pre-existing builtin id \(idString) to still exist")
                continue
            }
            XCTAssertEqual(style.name, name, "builtin \(idString) name changed unexpectedly")
        }
    }

    func testBuiltinCatalogGrewByExactlyOne() {
        // 7 pre-existing builtins + the new Markdown style.
        XCTAssertEqual(OutputStyle.builtinStyles.count, 8)
    }

    func testBuiltinStyleIDsRemainUnique() {
        let ids = OutputStyle.builtinStyles.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "builtin OutputStyle IDs must be unique")
    }

    // MARK: - User-style merge logic

    /// A user who saved their style list before this feature shipped would have
    /// only the original 7 builtins (plus maybe their own custom styles)
    /// persisted. `OutputStyleManager`'s merge-on-load logic must backfill the
    /// new Markdown builtin without disturbing anything the user already saved.
    @MainActor
    func testUserStyleMergeBackfillsNewMarkdownBuiltin() async throws {
        let legacyBuiltins = OutputStyle.builtinStyles.filter { $0.name != "Markdown" }
        let customStyle = OutputStyle(
            id: UUID(),
            name: "My Custom Style",
            icon: "star.fill",
            description: "A user-created style",
            templatePrompt: "Do something custom.",
            isBuiltin: false
        )
        let saved = legacyBuiltins + [customStyle]
        let data = try JSONEncoder().encode(saved)
        UserDefaults.standard.set(data, forKey: stylesKey)

        OutputStyleManager.shared.reload()

        let merged = OutputStyleManager.shared.styles
        XCTAssertTrue(merged.contains { $0.name == "Markdown" }, "reload() should backfill the new Markdown builtin")
        XCTAssertTrue(merged.contains { $0.id == customStyle.id }, "reload() must not drop the user's custom style")
        let markdownCount = merged.filter { $0.name == "Markdown" }.count
        XCTAssertEqual(markdownCount, 1, "Markdown builtin should be merged exactly once")
    }
}
