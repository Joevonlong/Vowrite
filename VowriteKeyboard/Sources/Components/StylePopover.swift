import SwiftUI
import VowriteKit

struct StylePopover: View {
    @ObservedObject var state: KeyboardState
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            ForEach(state.styles) { style in
                Button {
                    state.currentStyleName = style.name
                    // Update mode's output style (temporary, not persisted)
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
                    .padding(.vertical, 10)
                }
            }
        }
        .frame(width: 220)
        .presentationCompactAdaptation(.popover)
    }
}
