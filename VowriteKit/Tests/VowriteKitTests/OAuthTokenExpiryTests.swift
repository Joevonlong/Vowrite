import XCTest
@testable import VowriteKit

/// Boundary tests for `OAuthToken.isExpired(now:)` / `expiresWithin(minutes:now:)`.
///
/// Both take an injectable `now: Date` (defaulted to the live clock for
/// existing call sites, so this is a non-breaking addition) to make the
/// expiry boundary deterministic instead of racing the wall clock.
final class OAuthTokenExpiryTests: XCTestCase {

    private func makeToken(expiresAt: Date?) -> OAuthToken {
        OAuthToken(accessToken: "token", refreshToken: nil, expiresAt: expiresAt, email: nil)
    }

    // MARK: - isExpired

    func testIsExpiredFalseWhenNoExpiryDateSet() {
        let token = makeToken(expiresAt: nil)
        XCTAssertFalse(token.isExpired(now: Date()))
        XCTAssertFalse(token.isExpired) // live-clock property still works (non-breaking)
    }

    func testIsExpiredFalseBeforeExpiry() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let token = makeToken(expiresAt: now.addingTimeInterval(60))
        XCTAssertFalse(token.isExpired(now: now))
    }

    func testIsExpiredTrueAfterExpiry() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let token = makeToken(expiresAt: now.addingTimeInterval(-60))
        XCTAssertTrue(token.isExpired(now: now))
    }

    /// Exact boundary: `now == expiresAt` counts as expired (`>=` in the implementation).
    func testIsExpiredTrueExactlyAtExpiryInstant() {
        let expiry = Date(timeIntervalSince1970: 1_000_000)
        let token = makeToken(expiresAt: expiry)
        XCTAssertTrue(token.isExpired(now: expiry))
    }

    func testIsExpiredFalseOneSecondBeforeExpiryInstant() {
        let expiry = Date(timeIntervalSince1970: 1_000_000)
        let token = makeToken(expiresAt: expiry)
        XCTAssertFalse(token.isExpired(now: expiry.addingTimeInterval(-1)))
    }

    // MARK: - expiresWithin

    func testExpiresWithinFalseWhenNoExpiryDateSet() {
        let token = makeToken(expiresAt: nil)
        XCTAssertFalse(token.expiresWithin(minutes: 5, now: Date()))
    }

    func testExpiresWithinTrueWhenExpiryFallsInsideWindow() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        // Expires in 3 minutes; asking "within 5 minutes?" → true.
        let token = makeToken(expiresAt: now.addingTimeInterval(3 * 60))
        XCTAssertTrue(token.expiresWithin(minutes: 5, now: now))
    }

    func testExpiresWithinFalseWhenExpiryFallsOutsideWindow() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        // Expires in 10 minutes; asking "within 5 minutes?" → false.
        let token = makeToken(expiresAt: now.addingTimeInterval(10 * 60))
        XCTAssertFalse(token.expiresWithin(minutes: 5, now: now))
    }

    /// Exact boundary: window edge counts as "within" (`>=` in the implementation).
    func testExpiresWithinTrueExactlyAtWindowBoundary() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let token = makeToken(expiresAt: now.addingTimeInterval(5 * 60))
        XCTAssertTrue(token.expiresWithin(minutes: 5, now: now))
    }

    func testExpiresWithinTrueForAlreadyExpiredToken() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let token = makeToken(expiresAt: now.addingTimeInterval(-60))
        XCTAssertTrue(token.expiresWithin(minutes: 5, now: now))
    }

    func testExpiresWithinDefaultsToLiveClockWhenNowOmitted() {
        // Ensures the defaulted parameter keeps the existing call-site signature working.
        let token = makeToken(expiresAt: Date().addingTimeInterval(3600))
        XCTAssertFalse(token.expiresWithin(minutes: 5))
    }
}
