import SwiftUI
import UIKit
import VowriteKit

struct TopBar: View {
    @ObservedObject var state: KeyboardState

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "dot.radiowaves.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(KeyboardTheme.titleColor)
                Text("Vowrite")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(KeyboardTheme.titleColor)
            }
            Spacer()
            ModeToggleButton(state: state)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - F-071 Mode Toggle

private struct ModeToggleButton: View {
    @ObservedObject var state: KeyboardState

    private var isDisabled: Bool {
        state.viewState == .recording || state.viewState == .processing
    }

    var body: some View {
        HStack(spacing: 0) {
            segment(
                isActive: state.inputMode == .voice,
                label: { Image(systemName: "waveform").font(.system(size: 14, weight: .medium)) },
                onTap: { state.toggleInputMode() }
            )
            segment(
                isActive: state.inputMode == .keyboard,
                label: { Text("拼").font(.system(size: 15, weight: .medium)) },
                onTap: { state.toggleInputMode() }
            )
        }
        .padding(3)
        .background(Capsule().fill(Color(UIColor.systemGray4)))
        .opacity(isDisabled ? 0.4 : 1.0)
        .allowsHitTesting(!isDisabled)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: state.inputMode)
    }

    @ViewBuilder
    private func segment<Label: View>(
        isActive: Bool,
        @ViewBuilder label: () -> Label,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            label()
                .foregroundStyle(isActive ? KeyboardTheme.titleColor : KeyboardTheme.subtitleColor)
                .frame(width: 36, height: 28)
                .background(
                    Group {
                        if isActive {
                            Capsule()
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                        }
                    }
                )
        }
    }
}
