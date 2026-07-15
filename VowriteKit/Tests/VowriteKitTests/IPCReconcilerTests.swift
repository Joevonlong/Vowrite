import XCTest
@testable import VowriteKit

/// Guards the keyboard-side session-identity decision logic that fixes the
/// P0 IPC defect: a keyboard dismissed while a session ends can leave a
/// stale `.done` + result sitting in App Group storage; without session
/// identity, the next recording's first poll tick would read that stale
/// `.done` and insert the *previous* session's text into the *current* host
/// app, while orphaning the just-started recording. `IPCReconciler.action`
/// is the single place both the poll loop and the reload-time reconciliation
/// consult to tell a genuinely-ours read apart from a stale/foreign one.
final class IPCReconcilerTests: XCTestCase {

    // MARK: - The defect sequence itself

    func testStaleDoneWithMismatchedSessionIsDiscardedNotInserted() {
        // A previous session's .done + result is still sitting in defaults;
        // the keyboard's current session id doesn't match it (echoed
        // activeSessionId belongs to the old session). Must never insert.
        let action = IPCReconciler.action(state: .done, sessionMatches: false, serviceAlive: true)
        XCTAssertEqual(action, .discardAndGoIdle)
    }

    func testStaleErrorWithMismatchedSessionIsDiscardedNotSurfaced() {
        let action = IPCReconciler.action(state: .error, sessionMatches: false, serviceAlive: true)
        XCTAssertEqual(action, .discardAndGoIdle)
    }

    func testMismatchedRecordingIsDiscardedEvenWhenServiceIsAlive() {
        // A live .recording belonging to a foreign/older session must be
        // treated as stale even though the service itself is perfectly
        // healthy — session mismatch takes priority over liveness.
        let action = IPCReconciler.action(state: .recording, sessionMatches: false, serviceAlive: true)
        XCTAssertEqual(action, .discardAndGoIdle)
    }

    func testMismatchedProcessingIsDiscardedEvenWhenServiceIsAlive() {
        let action = IPCReconciler.action(state: .processing, sessionMatches: false, serviceAlive: true)
        XCTAssertEqual(action, .discardAndGoIdle)
    }

    // MARK: - Adoption (matching session, service alive)

    func testMatchingRecordingWithLiveServiceIsAdopted() {
        let action = IPCReconciler.action(state: .recording, sessionMatches: true, serviceAlive: true)
        XCTAssertEqual(action, .adopt(.recording))
    }

    func testMatchingProcessingWithLiveServiceIsAdopted() {
        let action = IPCReconciler.action(state: .processing, sessionMatches: true, serviceAlive: true)
        XCTAssertEqual(action, .adopt(.processing))
    }

    // MARK: - Dead service (matching session, but the main app process died)

    func testMatchingRecordingWithDeadServiceReportsServiceDied() {
        let action = IPCReconciler.action(state: .recording, sessionMatches: true, serviceAlive: false)
        XCTAssertEqual(action, .serviceDied)
    }

    func testMatchingProcessingWithDeadServiceReportsServiceDied() {
        let action = IPCReconciler.action(state: .processing, sessionMatches: true, serviceAlive: false)
        XCTAssertEqual(action, .serviceDied)
    }

    // MARK: - Matching .done / .error — the legitimate happy paths

    func testMatchingDoneInsertsResult() {
        let action = IPCReconciler.action(state: .done, sessionMatches: true, serviceAlive: true)
        XCTAssertEqual(action, .insertResultAndGoIdle)
    }

    func testMatchingDoneInsertsResultRegardlessOfServiceLiveness() {
        // By the time .done is written the service has already finished its
        // work for this session — a heartbeat that happens to have lapsed a
        // beat later shouldn't retroactively invalidate a completed result.
        let action = IPCReconciler.action(state: .done, sessionMatches: true, serviceAlive: false)
        XCTAssertEqual(action, .insertResultAndGoIdle)
    }

    func testMatchingErrorSurfacesTheError() {
        let action = IPCReconciler.action(state: .error, sessionMatches: true, serviceAlive: true)
        XCTAssertEqual(action, .surfaceErrorAndGoIdle)
    }

    // MARK: - Idle

    func testIdleIsAlwaysNoneRegardlessOfFlags() {
        XCTAssertEqual(IPCReconciler.action(state: .idle, sessionMatches: true, serviceAlive: true), .none)
        XCTAssertEqual(IPCReconciler.action(state: .idle, sessionMatches: false, serviceAlive: false), .none)
    }
}
