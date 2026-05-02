import XCTest
@testable import VowriteKit

final class OutputStyleCodableTests: XCTestCase {
    func testRoundtripPreservesAllFields() throws {
        let original = OutputStyle(
            id: UUID(),
            name: "My Style",
            icon: "star.fill",
            description: "An example",
            templatePrompt: "Format like X.",
            isBuiltin: false
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OutputStyle.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testRoundtripArrayPreservesOrder() throws {
        let styles = [
            OutputStyle(id: UUID(), name: "A", icon: "a", description: "", templatePrompt: "", isBuiltin: false),
            OutputStyle(id: UUID(), name: "B", icon: "b", description: "", templatePrompt: "", isBuiltin: true),
            OutputStyle(id: UUID(), name: "C", icon: "c", description: "", templatePrompt: "", isBuiltin: false)
        ]
        let data = try JSONEncoder().encode(styles)
        let decoded = try JSONDecoder().decode([OutputStyle].self, from: data)
        XCTAssertEqual(decoded.map(\.name), ["A", "B", "C"])
    }
}
