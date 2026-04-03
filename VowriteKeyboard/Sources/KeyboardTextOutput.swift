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

    func output(text: String) async {
        await MainActor.run {
            proxy?.insertText(text)
        }
    }
}
