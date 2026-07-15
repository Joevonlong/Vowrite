import UIKit
import VowriteKit

final class KeyboardTextOutput: TextOutputProvider {
    weak var proxy: UITextDocumentProxy?

    init(proxy: UITextDocumentProxy) {
        self.proxy = proxy
    }

    func prepareForOutput() {
        // No-op for keyboard (macOS needs to remember focused app)
    }

    func output(text: String) async -> Bool {
        // `TextOutputProvider` is `@MainActor`-isolated, so this already runs on
        // the main actor — the `MainActor.run` hop this used to need is gone.
        proxy?.insertText(text)
        return true
    }
}
