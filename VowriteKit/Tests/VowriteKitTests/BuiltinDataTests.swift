import XCTest
@testable import VowriteKit

final class BuiltinDataTests: XCTestCase {
    func testBuiltinModesNonEmpty() {
        XCTAssertFalse(Mode.builtinModes.isEmpty)
    }

    /// Clean mode UUID is referenced as the default selection in ModeManager.
    /// Any change to its UUID would silently break the default fallback.
    func testCleanModeUUIDIsStable() {
        let cleanID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        XCTAssertNotNil(Mode.builtinModes.first(where: { $0.id == cleanID }))
    }

    func testBuiltinModesAreAllMarkedBuiltin() {
        for mode in Mode.builtinModes {
            XCTAssertTrue(mode.isBuiltin, "Mode \(mode.name) is in builtinModes but isBuiltin is false")
        }
    }

    func testBuiltinModesShortcutIndexesAreUniqueWhenSet() {
        let indexes = Mode.builtinModes.compactMap { $0.shortcutIndex }
        XCTAssertEqual(Set(indexes).count, indexes.count, "Builtin modes have duplicate shortcut indexes")
    }

    func testBuiltinStylesNonEmpty() {
        XCTAssertFalse(OutputStyle.builtinStyles.isEmpty)
    }

    func testNoneStyleIDExists() {
        XCTAssertNotNil(OutputStyle.builtinStyles.first(where: { $0.id == OutputStyle.noneId }))
    }

    func testBuiltinStylesAreAllMarkedBuiltin() {
        for style in OutputStyle.builtinStyles {
            XCTAssertTrue(style.isBuiltin, "Style \(style.name) is in builtinStyles but isBuiltin is false")
        }
    }
}
