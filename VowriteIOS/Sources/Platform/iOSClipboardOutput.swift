import UIKit
import VowriteKit

final class iOSClipboardOutput: TextOutputProvider {
    func prepareForOutput() {
        // No-op on iOS — no app switching needed
    }

    func output(text: String) async {
        UIPasteboard.general.string = text
    }
}
