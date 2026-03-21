import SwiftUI

struct BottomBar: View {
    @ObservedObject var state: KeyboardState
    @State private var deleteTimer: Timer?
    @State private var deleteSpeed: TimeInterval = 0.1

    var body: some View {
        HStack(spacing: 0) {
            // Globe (next keyboard)
            Button {
                state.advanceToNextKeyboard()
            } label: {
                Image(systemName: "globe")
                    .font(.system(size: 16))
                    .frame(maxHeight: .infinity)
                    .frame(width: 44)
            }

            // Space bar
            Button {
                state.insertSpace()
            } label: {
                Text("space")
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 6))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 4)
            }

            // Return
            Button {
                state.insertReturn()
            } label: {
                Image(systemName: "return")
                    .font(.system(size: 14))
                    .frame(maxHeight: .infinity)
                    .frame(width: 44)
            }

            // Delete (with long-press repeat)
            Button {
                state.deleteBackward()
            } label: {
                Image(systemName: "delete.left")
                    .font(.system(size: 14))
                    .frame(maxHeight: .infinity)
                    .frame(width: 44)
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
        .foregroundStyle(.primary)
        .padding(.horizontal, 4)
    }

    private func startContinuousDelete() {
        deleteSpeed = 0.1
        deleteTimer = Timer.scheduledTimer(withTimeInterval: deleteSpeed, repeats: true) { _ in
            state.deleteBackward()
            // Accelerate
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
