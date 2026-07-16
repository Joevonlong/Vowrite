import XCTest
@testable import VowriteKit

final class ModeTemplateTests: XCTestCase {
    func testExactlyFifteenBuiltinTemplates() {
        XCTAssertEqual(ModeTemplate.builtins.count, 15)
    }

    func testIdsAreUnique() {
        let ids = ModeTemplate.builtins.map { $0.id }
        XCTAssertEqual(Set(ids).count, ids.count, "Builtin templates have duplicate ids")
    }

    func testNamesAreUnique() {
        let names = ModeTemplate.builtins.map { $0.name }
        XCTAssertEqual(Set(names).count, names.count, "Builtin templates have duplicate names")
    }

    func testPromptsAreNonEmpty() {
        for template in ModeTemplate.builtins {
            XCTAssertFalse(
                template.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                "\(template.name) has an empty systemPrompt"
            )
        }
    }

    func testIconsAreNonEmpty() {
        for template in ModeTemplate.builtins {
            XCTAssertFalse(template.icon.isEmpty, "\(template.name) has an empty icon")
        }
    }

    func testSummariesAreNonEmpty() {
        for template in ModeTemplate.builtins {
            XCTAssertFalse(template.summary.isEmpty, "\(template.name) has an empty summary")
        }
    }

    func testSelectionTemplatesReferenceSelectedPlaceholder() {
        for template in ModeTemplate.builtins where template.requiresSelection {
            XCTAssertTrue(
                template.systemPrompt.contains("{selected}"),
                "\(template.name) declares requiresSelection but its prompt has no {selected}"
            )
        }
    }

    /// F-077: every builtin template today operates on selected text — this
    /// documents that assumption so a future non-selection template addition
    /// is a deliberate, visible change rather than a silent default.
    func testAllCurrentBuiltinsRequireSelection() {
        XCTAssertTrue(ModeTemplate.builtins.allSatisfy { $0.requiresSelection })
    }

    func testExpectedTemplateNamesPresent() {
        let expected: Set<String> = [
            "Improve Writing", "Fix Grammar", "Make Professional", "Make Casual",
            "Make Confident", "Make Friendly", "Make Longer", "Make Shorter",
            "Simplify", "Paraphrase", "TL;DR", "Summarize in 3 Bullets",
            "Find Action Items", "Pros & Cons", "Explain Like I'm 5"
        ]
        let actual = Set(ModeTemplate.builtins.map { $0.name })
        XCTAssertEqual(actual, expected)
    }
}
