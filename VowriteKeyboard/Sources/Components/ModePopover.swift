import SwiftUI
import VowriteKit

struct ModePopover: View {
    @ObservedObject var state: KeyboardState
    @Binding var isPresented: Bool

    var body: some View {
        ScrollView {
        VStack(spacing: 0) {
            ForEach(state.modes) { mode in
                Button {
                    state.switchMode(to: mode)
                    isPresented = false
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: mode.icon)
                            .font(.body)
                            .foregroundStyle(KeyboardTheme.chipActiveText)
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
        }
        .frame(width: 260)
        .frame(maxHeight: 240)
        .presentationCompactAdaptation(.popover)
    }
}
