import XCTest
@testable import VowriteKit

/// Guards the pure failure-kind → user-facing-message mapping behind
/// BUG-017 (silent polish/translate failure): `DictationEngine` (macOS /
/// in-app iOS) and `BackgroundRecordingService` (iOS keyboard background
/// recording) both call into `PolishFailureMessage` so the wording for a
/// given failure kind can never drift between the two call sites, while
/// still using the platform-appropriate verb (macOS pastes = "output", the
/// iOS keyboard inserts directly = "input").
final class PolishFailureMessageTests: XCTestCase {

    // MARK: - macOS / in-app iOS wording ("output")

    func testMacTranslationFailureMessage() {
        XCTAssertEqual(PolishFailureMessage.macMessage(isTranslation: true), "翻译失败，已输出原文")
    }

    func testMacNonTranslationPolishFailureMessage() {
        XCTAssertEqual(PolishFailureMessage.macMessage(isTranslation: false), "润色失败，已输出原文")
    }

    // MARK: - iOS keyboard wording ("input")

    func testIOSTranslationFailureMessage() {
        XCTAssertEqual(PolishFailureMessage.iosMessage(isTranslation: true), "翻译失败，已输入原文")
    }

    func testIOSNonTranslationPolishFailureMessage() {
        XCTAssertEqual(PolishFailureMessage.iosMessage(isTranslation: false), "润色失败，已输入原文")
    }

    // MARK: - The two platforms never collide

    func testMacAndIOSWordingDifferForSameFailureKind() {
        XCTAssertNotEqual(
            PolishFailureMessage.macMessage(isTranslation: true),
            PolishFailureMessage.iosMessage(isTranslation: true)
        )
        XCTAssertNotEqual(
            PolishFailureMessage.macMessage(isTranslation: false),
            PolishFailureMessage.iosMessage(isTranslation: false)
        )
    }
}
