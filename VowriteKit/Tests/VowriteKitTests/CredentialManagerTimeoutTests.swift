import XCTest
@testable import VowriteKit

/// Regression test for the CredentialManager timeout bug: the previous
/// `withThrowingTaskGroup`-based race still blocked at scope exit on an
/// uncancellable refresh, so `prepareCredentials` could stall recording for
/// up to ~60s (URLSession's default timeout) instead of bounding the wait to
/// the advertised 3s. `refreshWithTimeout` takes an injectable `operation` so
/// this can be verified without a real network call.
final class CredentialManagerTimeoutTests: XCTestCase {

    /// An operation that never completes — simulates the real-world failure
    /// mode where OAuthRefreshManager's internal unstructured Task hangs.
    /// `static` (not a capturing instance method) so it satisfies the
    /// `@Sendable` operation parameter without capturing the test case instance.
    /// The runtime's "continuation leaked" warning this deliberately triggers
    /// is expected — that's the condition under test.
    private static func neverCompletingOperation(_ providerID: String) async {
        await withCheckedContinuation { (_: CheckedContinuation<Void, Never>) in
            // Deliberately never resume.
        }
    }

    func testNeverCompletingOperationStillReturnsWithinBound() async {
        let start = Date()

        await CredentialManager.refreshWithTimeout(
            providerID: "test-provider",
            operation: Self.neverCompletingOperation
        )

        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 4.0, "refreshWithTimeout must return within ~4s of its 3s deadline even if the operation never completes")
    }

    func testFastCompletingOperationReturnsImmediately() async {
        let start = Date()

        await CredentialManager.refreshWithTimeout(
            providerID: "test-provider",
            timeoutNanoseconds: 3_000_000_000,
            operation: { _ in /* completes instantly */ }
        )

        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 1.0, "a fast operation should not wait for the full timeout")
    }

    func testCustomTimeoutIsHonoredForNeverCompletingOperation() async {
        let start = Date()

        await CredentialManager.refreshWithTimeout(
            providerID: "test-provider",
            timeoutNanoseconds: 200_000_000, // 0.2s
            operation: Self.neverCompletingOperation
        )

        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 1.0, "a short custom timeout should be honored, not the 3s default")
    }
}
