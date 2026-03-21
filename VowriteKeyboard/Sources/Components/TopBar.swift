import SwiftUI
import VowriteKit

struct TopBar: View {
    @ObservedObject var state: KeyboardState
    @State private var showModePopover = false
    @State private var showStylePopover = false

    var body: some View {
        HStack(spacing: 12) {
            // Mode selector
            Button {
                showModePopover = true
            } label: {
                HStack(spacing: 4) {
                    Text(state.currentMode.icon)
                        .font(.caption)
                    Text(state.currentMode.name)
                        .font(.caption)
                        .fontWeight(.medium)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundStyle(.primary)
            }
            .popover(isPresented: $showModePopover) {
                ModePopover(state: state, isPresented: $showModePopover)
            }

            Spacer()

            // Style selector (only when AI is on)
            if state.aiEnabled {
                Button {
                    showStylePopover = true
                } label: {
                    HStack(spacing: 4) {
                        Text(state.currentStyleName)
                            .font(.caption)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundStyle(.primary)
                }
                .popover(isPresented: $showStylePopover) {
                    StylePopover(state: state, isPresented: $showStylePopover)
                }
            }

            // AI toggle
            Toggle(isOn: Binding(
                get: { state.aiEnabled },
                set: { _ in state.toggleAI() }
            )) {
                Text("AI")
                    .font(.caption2)
                    .fontWeight(.semibold)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .fixedSize()
        }
        .padding(.horizontal, 12)
    }
}
