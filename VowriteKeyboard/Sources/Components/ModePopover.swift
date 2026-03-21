import SwiftUI
import VowriteKit

struct ModePopover: View {
    @ObservedObject var state: KeyboardState
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
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
                    .padding(.vertical, 10)
                }
            }
        }
        .frame(width: 200)
        .presentationCompactAdaptation(.popover)
    }
}
