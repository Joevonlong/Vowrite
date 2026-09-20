import XCTest
@testable import BuiltinVoiceEffects

final class BuiltinVoiceEffectsTests: XCTestCase {
    func testCatalogContainsOnlyOriginalEightyEffects() {
        XCTAssertEqual(BuiltinVoiceEffectCatalog.all.map(\.id), Array(1...80))
        XCTAssertEqual(BuiltinVoiceEffectCatalog.all.last?.english, "FOLD")
        XCTAssertEqual(
            Dictionary(grouping: BuiltinVoiceEffectCatalog.all, by: \.category).mapValues(\.count),
            ["无框线条": 15, "粒子点阵": 15, "环形轨道": 15, "光带流体": 15, "几何机械": 13, "特殊结构": 7]
        )
    }

    func testSelectionPersistsAndRejectsOutOfRangeValues() throws {
        let suite = "BuiltinVoiceEffectTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let selection = BuiltinVoiceEffectSelection(defaults: defaults)
        XCTAssertNil(selection.selectedID)
        selection.select(80)
        XCTAssertEqual(BuiltinVoiceEffectSelection(defaults: defaults).selectedID, 80)
        selection.select(81)
        XCTAssertNil(selection.selectedID)
        XCTAssertNil(defaults.object(forKey: BuiltinVoiceEffectSelection.key))
    }

    func testTrustedResourcesHaveNoDynamicOrNetworkCode() throws {
        let sourceURL = try XCTUnwrap(BuiltinVoiceEffectResources.url(forResource: "voice-effects", withExtension: "js"))
        let hostURL = try XCTUnwrap(BuiltinVoiceEffectResources.url(forResource: "host", withExtension: "html"))
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let host = try String(contentsOf: hostURL, encoding: .utf8)
        XCTAssertTrue(source.contains("case 80:"))
        XCTAssertFalse(source.contains("case 81:"))
        XCTAssertFalse(source.contains("eval("))
        XCTAssertFalse(source.contains("fetch("))
        XCTAssertTrue(host.contains("connect-src 'none'"))
        XCTAssertFalse(host.contains("http://"))
        XCTAssertFalse(host.contains("https://"))
    }
}
