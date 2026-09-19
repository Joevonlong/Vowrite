import Foundation
import XCTest
@testable import VowriteKit

final class VowriteResourceBundleTests: XCTestCase {
    func testEmbeddedBundleIsSelectedBeforeFallback() throws {
        let app = try makeAppBundle()
        defer { try? FileManager.default.removeItem(at: app.root) }

        var fallbackCalled = false
        let resolved = VowriteResources.resolve(mainBundle: app.mainBundle) {
            fallbackCalled = true
            XCTFail("Bundle.module fallback must not be evaluated for an embedded app bundle")
            return Bundle(for: Probe.self)
        }

        XCTAssertFalse(fallbackCalled)
        let providers = try String(contentsOf: try XCTUnwrap(resolved.url(forResource: "providers", withExtension: "json")), encoding: .utf8)
        XCTAssertFalse(providers.isEmpty)
        XCTAssertNotNil(resolved.url(forResource: "polish.system", withExtension: "md", subdirectory: "Prompts"))
        XCTAssertNotNil(resolved.url(forResource: "translate.system", withExtension: "md", subdirectory: "Prompts"))
    }

    func testFallbackIsUsedWhenAppHasNoEmbeddedBundle() throws {
        let appRoot = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: appRoot) }
        let fallbackRoot = appRoot.appendingPathComponent("Fallback.bundle")
        try FileManager.default.createDirectory(at: fallbackRoot, withIntermediateDirectories: true)
        let fallback = try XCTUnwrap(Bundle(url: fallbackRoot))

        var fallbackCalled = false
        let resolved = VowriteResources.resolve(mainBundle: try XCTUnwrap(Bundle(url: appRoot))) {
            fallbackCalled = true
            return fallback
        }

        XCTAssertTrue(fallbackCalled)
        XCTAssertEqual(resolved.bundleURL, fallback.bundleURL)
    }

    private func makeAppBundle() throws -> (root: URL, mainBundle: Bundle) {
        let root = try temporaryDirectory()
        let resources = root.appendingPathComponent("Contents/Resources/VowriteKit_VowriteKit.bundle")
        try FileManager.default.createDirectory(at: resources.appendingPathComponent("Prompts"), withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: resources.appendingPathComponent("providers.json"))
        try Data("polish".utf8).write(to: resources.appendingPathComponent("Prompts/polish.system.md"))
        try Data("translate".utf8).write(to: resources.appendingPathComponent("Prompts/translate.system.md"))
        return (root, try XCTUnwrap(Bundle(url: root)))
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("vowrite-resource-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private final class Probe {}
}
