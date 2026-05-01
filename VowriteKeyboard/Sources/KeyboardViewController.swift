import UIKit
import SwiftUI
import Combine
import VowriteKit

class KeyboardViewController: UIInputViewController {
    private var keyboardState: KeyboardState!
    private var heightCancellable: AnyCancellable?

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .secondarySystemBackground

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
        hosting.view.backgroundColor = .secondarySystemBackground

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

    /// Base keyboard height in points. The actual constraint constant is
    /// `baseKeyboardHeight + keyboardState.extraTopHeight` so the keyboard
    /// can grow during the F-067 bulk-delete popup gesture.
    private let baseKeyboardHeight: CGFloat = 280

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Set explicit height to claim the full keyboard area
        if heightConstraint == nil {
            let constraint = view.heightAnchor.constraint(equalToConstant: baseKeyboardHeight)
            constraint.priority = .defaultHigh
            constraint.isActive = true
            heightConstraint = constraint
        }
        // F-067: Observe popup-driven extra top height and grow the keyboard
        // so the bulk-delete popup can render in the new top space without
        // being clipped by the system keyboard window.
        if heightCancellable == nil {
            heightCancellable = keyboardState.$extraTopHeight
                .receive(on: DispatchQueue.main)
                .sink { [weak self] extra in
                    guard let self = self,
                          let constraint = self.heightConstraint else { return }
                    constraint.constant = self.baseKeyboardHeight + extra
                    UIView.animate(
                        withDuration: 0.22,
                        delay: 0,
                        options: [.curveEaseOut, .beginFromCurrentState]
                    ) {
                        self.view.superview?.layoutIfNeeded()
                    }
                }
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
