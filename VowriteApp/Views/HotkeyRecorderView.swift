import SwiftUI
import AppKit
import Carbon.HIToolbox

// MARK: - Hotkey Recorder Button (opens a capture panel)

struct HotkeyRecorderButton: View {
    let currentKeyCode: UInt32
    let currentModifiers: UInt32
    let onSave: (UInt32, UInt32) -> Void

    @State private var isShowingPanel = false

    var body: some View {
        Button {
            showCapturePanel()
        } label: {
            Text(HotkeyDisplay.string(keyCode: currentKeyCode, modifiers: currentModifiers))
                .font(.system(.body, design: .monospaced, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(minWidth: 120)
                .background(Color.secondary.opacity(0.12))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func showCapturePanel() {
        let panel = HotkeyCapturePanel(currentKeyCode: currentKeyCode, currentModifiers: currentModifiers) { code, mods in
            onSave(code, mods)
        }
        panel.showCapture()
    }
}

// MARK: - Capture Panel (dedicated NSPanel for reliable key capture)

final class HotkeyCapturePanel: NSPanel {
    private let captureView: HotkeyCaptureView
    private var onComplete: ((UInt32, UInt32) -> Void)?

    init(currentKeyCode: UInt32, currentModifiers: UInt32, onComplete: @escaping (UInt32, UInt32) -> Void) {
        self.onComplete = onComplete

        let viewFrame = NSRect(x: 0, y: 0, width: 340, height: 160)
        self.captureView = HotkeyCaptureView(frame: viewFrame)

        super.init(
            contentRect: viewFrame,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        self.title = "Record Shortcut"
        self.isFloatingPanel = true
        self.level = .modalPanel
        self.contentView = captureView
        self.isReleasedWhenClosed = false
        self.becomesKeyOnlyIfNeeded = false
        self.hidesOnDeactivate = false

        captureView.onCapture = { [weak self] code, mods in
            onComplete(code, mods)
            self?.close()
        }
        captureView.onCancel = { [weak self] in
            self?.close()
        }
    }

    func showCapture() {
        center()
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        // Make the captureView first responder so it gets keyDown
        makeFirstResponder(captureView)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - Capture View (NSView that actually catches keyDown)

final class HotkeyCaptureView: NSView {
    var onCapture: ((UInt32, UInt32) -> Void)?
    var onCancel: (() -> Void)?

    private let label = NSTextField(labelWithString: "")
    private let sublabel = NSTextField(labelWithString: "")
    private let currentLabel = NSTextField(labelWithString: "")
    private let cancelButton = NSButton()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true

        // Main instruction
        label.stringValue = "Press your shortcut now"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.alignment = .center
        label.isEditable = false
        label.isBezeled = false
        label.drawsBackground = false
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        // Sub instruction
        sublabel.stringValue = "Use a modifier key (⌘⌥⌃⇧) + another key\nPress Esc to cancel"
        sublabel.font = .systemFont(ofSize: 12)
        sublabel.textColor = .secondaryLabelColor
        sublabel.alignment = .center
        sublabel.maximumNumberOfLines = 2
        sublabel.isEditable = false
        sublabel.isBezeled = false
        sublabel.drawsBackground = false
        sublabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sublabel)

        // Waiting indicator
        currentLabel.stringValue = "⌨️ Waiting for input..."
        currentLabel.font = .systemFont(ofSize: 14, weight: .medium)
        currentLabel.textColor = .systemOrange
        currentLabel.alignment = .center
        currentLabel.isEditable = false
        currentLabel.isBezeled = false
        currentLabel.drawsBackground = false
        currentLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(currentLabel)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 16),

            currentLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            currentLabel.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 16),

            sublabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            sublabel.topAnchor.constraint(equalTo: currentLabel.bottomAnchor, constant: 16),
            sublabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 16),
        ])
    }

    override var acceptsFirstResponder: Bool { true }
    override func becomeFirstResponder() -> Bool { true }

    override func keyDown(with event: NSEvent) {
        let code = UInt32(event.keyCode)

        // Escape = cancel
        if code == UInt32(kVK_Escape) {
            onCancel?()
            return
        }

        // Ignore modifier-only key codes
        let modifierKeys: Set<UInt16> = [54, 55, 56, 58, 59, 60, 61, 62]
        if modifierKeys.contains(event.keyCode) { return }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Must have at least one modifier
        guard flags.contains(.command) || flags.contains(.option) ||
              flags.contains(.control) || flags.contains(.shift) else {
            currentLabel.stringValue = "⚠️ Need a modifier key!"
            currentLabel.textColor = .systemRed
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.currentLabel.stringValue = "⌨️ Waiting for input..."
                self?.currentLabel.textColor = .systemOrange
            }
            return
        }

        var carbonMods: UInt32 = 0
        if flags.contains(.command) { carbonMods |= UInt32(cmdKey) }
        if flags.contains(.option) { carbonMods |= UInt32(optionKey) }
        if flags.contains(.control) { carbonMods |= UInt32(controlKey) }
        if flags.contains(.shift) { carbonMods |= UInt32(shiftKey) }

        // Show what was captured briefly
        let display = HotkeyDisplay.string(keyCode: code, modifiers: carbonMods)
        currentLabel.stringValue = "✅ \(display)"
        currentLabel.textColor = .systemGreen

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.onCapture?(code, carbonMods)
        }
    }

    // Prevent the "bonk" system sound for unhandled keys
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        return true
    }
}

// MARK: - Display helpers

enum HotkeyDisplay {
    static func string(keyCode: UInt32, modifiers: UInt32) -> String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        parts.append(keyName(for: keyCode))
        return parts.joined()
    }

    static func keyName(for keyCode: UInt32) -> String {
        let names: [Int: String] = [
            kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_Escape: "⎋",
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
            kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
            kVK_UpArrow: "↑", kVK_DownArrow: "↓", kVK_LeftArrow: "←", kVK_RightArrow: "→",
            kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D", kVK_ANSI_E: "E",
            kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H", kVK_ANSI_I: "I", kVK_ANSI_J: "J",
            kVK_ANSI_K: "K", kVK_ANSI_L: "L", kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O",
            kVK_ANSI_P: "P", kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
            kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X", kVK_ANSI_Y: "Y",
            kVK_ANSI_Z: "Z", kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3",
            kVK_ANSI_4: "4", kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7", kVK_ANSI_8: "8",
            kVK_ANSI_9: "9", kVK_ANSI_Minus: "-", kVK_ANSI_Equal: "=",
            kVK_ANSI_LeftBracket: "[", kVK_ANSI_RightBracket: "]",
            kVK_ANSI_Semicolon: ";", kVK_ANSI_Quote: "'", kVK_ANSI_Comma: ",",
            kVK_ANSI_Period: ".", kVK_ANSI_Slash: "/", kVK_ANSI_Backslash: "\\", kVK_ANSI_Grave: "`"
        ]
        return names[Int(keyCode)] ?? "Key\(keyCode)"
    }
}
