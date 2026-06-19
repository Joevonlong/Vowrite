import XCTest
@testable import VowriteKit

/// Data-integrity tests for the hand-edited `providers.json` (19+ providers),
/// loaded by `ProviderRegistry`. These guard against typos that would silently
/// break a provider: a malformed base URL, a trailing slash (which the request
/// builder would turn into a double slash), a duplicate id, or an empty id.
final class ProviderRegistryDataTests: XCTestCase {

    func testRegistryLoadsAtLeastOneProvider() {
        XCTAssertFalse(
            ProviderRegistry.shared.providers.isEmpty,
            "providers.json failed to load — registry is empty"
        )
    }

    func testProviderIDsAreUnique() {
        let ids = ProviderRegistry.shared.providers.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "provider ids in providers.json must be unique")
    }

    func testProviderIDsAreNonEmpty() {
        for p in ProviderRegistry.shared.providers {
            XCTAssertFalse(p.id.isEmpty, "every provider must have a non-empty id")
        }
    }

    func testNonEmptyBaseURLsAreValidURLs() {
        for p in ProviderRegistry.shared.providers where !p.baseURL.isEmpty {
            XCTAssertNotNil(
                URL(string: p.baseURL),
                "provider '\(p.id)' has an invalid baseURL: '\(p.baseURL)'"
            )
        }
    }

    func testNonEmptyBaseURLsHaveNoTrailingSlash() {
        for p in ProviderRegistry.shared.providers where !p.baseURL.isEmpty {
            XCTAssertFalse(
                p.baseURL.hasSuffix("/"),
                "provider '\(p.id)' baseURL should not end with '/': '\(p.baseURL)'"
            )
        }
    }
}
