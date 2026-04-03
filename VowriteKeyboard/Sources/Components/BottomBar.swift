import SwiftUI
import UIKit
import VowriteKit

// MARK: - Globe Key (UIKit — uses handleInputModeList)

/// UIViewRepresentable that wires into Apple's official keyboard-switching API.
/// Using handleInputModeList(from:with:) for .allTouchEvents tells iOS that
/// this extension handles input-mode switching, so the system hides its own
/// globe + dictation bar below the keyboard.
struct GlobeKeyButton: UIViewRepresentable {
    let inputViewController: UIInputViewController?

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        button.setImage(UIImage(systemName: "globe", withConfiguration: config), for: .normal)
        button.tintColor = UIColor.label
        if let ivc = inputViewController {
            button.addTarget(ivc,
                action: #selector(UIInputViewController.handleInputModeList(from:with:)),
                for: .allTouchEvents)
        }
        return button
    }

    func updateUIView(_ uiView: UIButton, context: Context) {}
}
