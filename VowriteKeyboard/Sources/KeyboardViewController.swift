import UIKit
import SwiftUI
import VowriteKit

class KeyboardViewController: UIInputViewController {
    private var keyboardState: KeyboardState!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Clear root background so the system keyboard backdrop shows through.
        // (Custom backgrounds caused a visible color block vs. the system area
        // above the keyboard — see KeyboardTheme.background.)
        view.backgroundColor = .clear

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

    private var heightConstraint: NSLayoutConstraint?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if heightConstraint == nil {
            let constraint = view.heightAnchor.constraint(equalToConstant: 280)
            constraint.priority = .defaultHigh
            constraint.isActive = true
            heightConstraint = constraint
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Reload config each time keyboard appears (user may have changed settings)
        keyboardState.reloadConfiguration()
        VowriteStorage.defaults.set(hasFullAccess, forKey: "keyboard_full_access")
        // Detect host app for return-to-app flow
        detectHostBundleID()
    }

    /// Detect the host app's bundle ID via private API and store it for the
    /// containing app to use when returning after activation.
    private func detectHostBundleID() {
        let sel = NSSelectorFromString("_hostBundleID")
        // Try self (UIInputViewController)
        if responds(to: sel),
           let val = perform(sel)?.takeUnretainedValue() as? String,
           !val.isEmpty, !val.hasPrefix("com.vowrite") {
            VowriteStorage.defaults.set(val, forKey: "lastHostBundleID")
            return
        }
        // Walk parent view controllers
        var vc: UIViewController? = parent
        while let p = vc {
            if p.responds(to: sel),
               let val = p.perform(sel)?.takeUnretainedValue() as? String,
               !val.isEmpty, !val.hasPrefix("com.vowrite") {
                VowriteStorage.defaults.set(val, forKey: "lastHostBundleID")
                return
            }
            vc = p.parent
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        keyboardState?.showGlobe = self.needsInputModeSwitchKey
    }

    override func textWillChange(_ textInput: (any UITextInput)?) {
        super.textWillChange(textInput)
        keyboardState.updateProxy(textDocumentProxy)
    }
}
