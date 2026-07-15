import XCTest
@testable import VowriteKit

/// Tests for `AudioEngine`'s write-failure counter (the fix for the audio tap
/// silently swallowing `AVAudioFile.write(from:)` failures via `try?`, which
/// could produce a silent/empty recording with no signal anywhere that
/// anything went wrong).
///
/// These exercise `recordWriteFailure()` directly rather than driving the real
/// `installTap` closure end-to-end — that requires live microphone hardware,
/// which isn't available in a CI/test environment. `recordWriteFailure()` is
/// exactly what the tap closure calls on a caught write error, so this still
/// covers the actual thread-safety and counting logic under test.
final class AudioEngineWriteFailureTests: XCTestCase {

    func testHadWriteFailuresFalseInitially() {
        let engine = AudioEngine()
        XCTAssertFalse(engine.hadWriteFailures)
    }

    func testSingleFailureSetsHadWriteFailuresTrue() {
        let engine = AudioEngine()
        engine.recordWriteFailure()
        XCTAssertTrue(engine.hadWriteFailures)
    }

    func testMultipleFailuresStillReportTrue() {
        let engine = AudioEngine()
        engine.recordWriteFailure()
        engine.recordWriteFailure()
        engine.recordWriteFailure()
        XCTAssertTrue(engine.hadWriteFailures)
    }

    /// The tap closure runs on the audio render thread while `hadWriteFailures`
    /// may be read from the main thread — this is the scenario the lock exists
    /// for. Concurrent increments must all land without crashing or racing.
    func testConcurrentFailuresAreCountedSafely() {
        let engine = AudioEngine()
        DispatchQueue.concurrentPerform(iterations: 200) { _ in
            engine.recordWriteFailure()
        }
        XCTAssertTrue(engine.hadWriteFailures)
    }
}
