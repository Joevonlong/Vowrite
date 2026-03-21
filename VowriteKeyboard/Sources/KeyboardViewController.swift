import UIKit
import SwiftUI
import VowriteKit

class KeyboardViewController: UIInputViewController {
    private var keyboardState: KeyboardState!

    override func viewDidLoad() {
        super.viewDidLoad()

        // 1. Configure shared storage
        VowriteStorage.configure(suiteName: VowriteStorage.appGroupID)

        // 2. Keychain migration (if needed)
        KeychainHelper.migrateToAccessGroup()

        // 3. Create state
        keyboardState = KeyboardState(
            inputViewController: self
        )

        // 4. SwiftUI keyboard view
        let keyboardView = KeyboardView(state: keyboardState)
        let hosting = UIHostingController(rootView: keyboardView)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        hosting.view.backgroundColor = .clear

        addChild(hosting)
        self.view.addSubview(hosting.view)
        hosting.didMove(toParent: self)

        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: self.view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
        ])

        // 5. Write status for Container App detection
        VowriteStorage.defaults.set(true, forKey: "keyboard_active")
        VowriteStorage.defaults.set(hasFullAccess, forKey: "keyboard_full_access")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Reload config each time keyboard appears (user may have changed settings)
        keyboardState.reloadConfiguration()
        VowriteStorage.defaults.set(hasFullAccess, forKey: "keyboard_full_access")
    }

    override func textDocumentProxyDidChange() {
        super.textDocumentProxyDidChange()
        keyboardState.updateProxy(textDocumentProxy)
    }
}
