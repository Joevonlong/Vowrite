import SwiftUI
import VowriteKit

struct TopBar: View {
    @ObservedObject var state: KeyboardState
    @State private var deleteTimer: Timer?
    @State private var deleteSpeed: TimeInterval = 0.1

    var body: some View {
        HStack {
            // Brand
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

            // Action buttons
            HStack(spacing: 12) {
                actionButton(text: "@") {
                    state.insertText("@")
                }

                actionButton(text: "─") {
                    state.insertSpace()
                }

                // Delete with long-press repeat
                actionButton(symbol: "delete.left") {
                    state.deleteBackward()
                }
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.3)
                        .onEnded { _ in
                            startContinuousDelete()
                        }
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { _ in
                            stopContinuousDelete()
                        }
                )
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Action Button

    @ViewBuilder
    private func actionButton(
        symbol: String? = nil,
        text: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(KeyboardTheme.buttonFill)
                    .frame(width: KeyboardTheme.actionButtonSize,
                           height: KeyboardTheme.actionButtonSize)

                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(KeyboardTheme.iconColor)
                } else if let text {
                    Text(text)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(KeyboardTheme.iconColor)
                }
            }
        }
    }

    // MARK: - Continuous Delete

    private func startContinuousDelete() {
        deleteSpeed = 0.1
        deleteTimer = Timer.scheduledTimer(withTimeInterval: deleteSpeed, repeats: true) { _ in
            state.deleteBackward()
            if deleteSpeed > 0.05 {
                deleteSpeed -= 0.01
                deleteTimer?.invalidate()
                deleteTimer = Timer.scheduledTimer(withTimeInterval: deleteSpeed, repeats: true) { _ in
                    state.deleteBackward()
                }
            }
        }
    }

    private func stopContinuousDelete() {
        deleteTimer?.invalidate()
        deleteTimer = nil
        deleteSpeed = 0.1
    }
}
