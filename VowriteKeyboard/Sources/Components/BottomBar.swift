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

// MARK: - Bottom Bar

struct BottomBar: View {
    @ObservedObject var state: KeyboardState
    @State private var showSettingsPopover = false

    var body: some View {
        HStack {
            // Globe — keyboard switcher (only when system requires it)
            if state.showGlobe {
                GlobeKeyButton(inputViewController: state.viewController)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            // Return button — "换行"
            Button {
                state.insertReturn()
            } label: {
                Text("换行")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(KeyboardTheme.subtitleColor)
                    .frame(width: KeyboardTheme.returnButtonWidth,
                           height: KeyboardTheme.returnButtonHeight)
                    .background(
                        KeyboardTheme.buttonFill,
                        in: RoundedRectangle(cornerRadius: KeyboardTheme.returnButtonCornerRadius)
                    )
            }

            Spacer()

            // Sparkle — quick settings
            Button {
                showSettingsPopover = true
            } label: {
                Image(systemName: "sparkle")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(KeyboardTheme.subtitleColor)
                    .frame(width: 44, height: 44)
            }
            .popover(isPresented: $showSettingsPopover) {
                QuickSettingsPopover(state: state, isPresented: $showSettingsPopover)
            }
        }
        .padding(.horizontal, 12)
    }
}

// MARK: - Quick Settings Popover

private struct QuickSettingsPopover: View {
    @ObservedObject var state: KeyboardState
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            // AI Toggle
            HStack {
                Text("AI Polish")
                    .font(.subheadline)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { state.aiEnabled },
                    set: { _ in state.toggleAI() }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // Mode section
            Text("Mode")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

            ForEach(state.modes) { mode in
                Button {
                    state.switchMode(to: mode)
                    isPresented = false
                } label: {
                    HStack(spacing: 8) {
                        Text(mode.icon)
                            .font(.body)
                        Text(mode.name)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Spacer()
                        if mode.id == state.currentMode.id {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }

            // Style section (when AI is on)
            if state.aiEnabled {
                Divider()
                    .padding(.top, 4)

                Text("Style")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                ForEach(state.styles) { style in
                    Button {
                        state.selectStyle(style)
                        isPresented = false
                    } label: {
                        HStack(spacing: 8) {
                            Text(style.icon)
                                .font(.body)
                            Text(style.name)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Spacer()
                            if style.name == state.currentStyleName {
                                Image(systemName: "checkmark")
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .frame(width: 240)
        .presentationCompactAdaptation(.popover)
    }
}
