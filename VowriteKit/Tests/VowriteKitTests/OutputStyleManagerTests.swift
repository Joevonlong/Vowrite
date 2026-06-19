import XCTest
@testable import VowriteKit

/// Tests for `OutputStyleManager`'s thread-safe resolution helpers, used by the
/// polish prompt builder and the iOS keyboard IPC layer. UserDefaults is cleared
/// so resolution falls back to the built-in styles (deterministic).
final class OutputStyleManagerTests: XCTestCase {
    private let stylesKey = "vowriteOutputStyles"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: stylesKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: stylesKey)
        super.tearDown()
    }

    func testNilStyleIdReturnsNil() {
        XCTAssertNil(OutputStyleManager.templatePrompt(for: nil))
    }

    func testNoneStyleReturnsNilTemplate() {
        // The "None" style intentionally has no template prompt.
        XCTAssertNil(OutputStyleManager.templatePrompt(for: OutputStyle.noneId))
    }

    func testUnknownStyleIdReturnsNil() {
        XCTAssertNil(OutputStyleManager.templatePrompt(for: UUID()))
    }

    func testBuiltinStyleResolvesToItsTemplate() {
        guard let style = OutputStyle.builtinStyles.first(
            where: { $0.id != OutputStyle.noneId && !$0.templatePrompt.isEmpty }
        ) else {
            XCTFail("expected at least one builtin style with a non-empty template")
            return
        }
        XCTAssertEqual(OutputStyleManager.templatePrompt(for: style.id), style.templatePrompt)
    }

    func testStyleIdForBuiltinNameResolves() {
        guard let style = OutputStyle.builtinStyles.first(where: { $0.id != OutputStyle.noneId }) else {
            XCTFail("expected a builtin style")
            return
        }
        XCTAssertEqual(OutputStyleManager.styleId(forName: style.name), style.id)
    }

    func testStyleIdForUnknownNameReturnsNil() {
        XCTAssertNil(OutputStyleManager.styleId(forName: "no-such-style-name-xyz"))
    }
}
