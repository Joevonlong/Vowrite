import VowriteKit
import SwiftUI

// MARK: - Icon Picker

struct IconPickerView: View {
    @Binding var selected: String
    @Environment(\.dismiss) private var dismiss

    private static let icons = [
        "mic.fill", "sparkles", "envelope", "bubble.left", "note.text",
        "chevron.left.forwardslash.chevron.right", "doc.text", "list.bullet",
        "person.fill", "briefcase.fill", "graduationcap.fill", "paintbrush.fill",
        "wrench.and.screwdriver.fill", "heart.fill", "star.fill", "bolt.fill",
        "globe", "music.note", "camera.fill", "book.fill",
        "pencil", "megaphone.fill", "flag.fill", "tag.fill",
        "bookmark.fill", "newspaper.fill", "phone.fill", "chart.bar.fill",
        "brain.head.profile", "text.bubble.fill",
    ]

    var body: some View {
        VStack(spacing: 12) {
            Text("Choose Icon")
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(44)), count: 6), spacing: 8) {
                ForEach(Self.icons, id: \.self) { icon in
                    let isSelected = selected == icon
                    Button {
                        selected = icon
                        dismiss()
                    } label: {
                        Image(systemName: icon)
                            .font(.title3)
                            .frame(width: 44, height: 44)
                            .background(isSelected
                                ? VW.Colors.Action.soft
                                : VW.Colors.Surface.secondary)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isSelected
                                        ? VW.Colors.Action.primary
                                        : VW.Colors.Border.standard, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(isSelected ? VW.Colors.Action.primary : VW.Colors.Text.primary)
                    .accessibilityLabel(icon.replacingOccurrences(of: ".", with: " "))
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
        }
        .padding(16)
        .frame(width: 344)
        .settingsPageStyle()
    }
}
