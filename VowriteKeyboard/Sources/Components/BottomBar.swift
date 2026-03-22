import SwiftUI
import VowriteKit

struct BottomBar: View {
    @ObservedObject var state: KeyboardState
    @State private var showSettingsPopover = false

    var body: some View {
        HStack {
            // Globe — keyboard switcher
            Button {
                state.advanceToNextKeyboard()
            } label: {
                Image(systemName: "globe")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(KeyboardTheme.iconColor)
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
                        state.currentStyleName = style.name
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
