import XCTest
@testable import VowriteKit

/// Tests for `ClipboardRestoreDecision.shouldRestore`, the pure decision helper
/// extracted from `MacTextInjector`'s post-paste clipboard restore (P-3 fix).
///
/// The restore must only fire when the pasteboard's change count is exactly
/// the value recorded right after we wrote the injection text — any other
/// value means the user (or another app) copied something new in the
/// meantime, and restoring would silently clobber it.
final class ClipboardRestoreDecisionTests: XCTestCase {
    func testEqualChangeCountsAllowsRestore() {
        XCTAssertTrue(ClipboardRestoreDecision.shouldRestore(currentChangeCount: 42, recordedChangeCount: 42))
    }

    func testAdvancedChangeCountBlocksRestore() {
        // The common real-world case: the user copied something else before
        // the restore timer fired.
        XCTAssertFalse(ClipboardRestoreDecision.shouldRestore(currentChangeCount: 43, recordedChangeCount: 42))
    }

    func testChangeCountFarAheadBlocksRestore() {
        XCTAssertFalse(ClipboardRestoreDecision.shouldRestore(currentChangeCount: 100, recordedChangeCount: 42))
    }

    func testLowerCurrentChangeCountBlocksRestore() {
        // NSPasteboard.changeCount never decreases in practice, but the
        // decision helper is a pure equality check — any mismatch, in either
        // direction, must block the restore rather than assume it's safe.
        XCTAssertFalse(ClipboardRestoreDecision.shouldRestore(currentChangeCount: 10, recordedChangeCount: 42))
    }

    func testZeroChangeCountsAllowsRestore() {
        XCTAssertTrue(ClipboardRestoreDecision.shouldRestore(currentChangeCount: 0, recordedChangeCount: 0))
    }
}
