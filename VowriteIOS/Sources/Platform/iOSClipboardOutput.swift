import UIKit
import VowriteKit

// swiftlint:disable:next type_name
final class iOSClipboardOutput: TextOutputProvider {
    func prepareForOutput() {
        // No-op on iOS — no app switching needed
    }

    func output(text: String) async -> Bool {
        // `TextOutputProvider` is `@MainActor`-isolated, so this already runs on
        // the main actor — the `MainActor.run` hop this used to need is gone.
        UIPasteboard.general.string = text
        return true
    }
}
