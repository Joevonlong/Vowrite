import VowriteKit
import SwiftUI

// MARK: - Mode Template Picker Sheet
//
// F-077: Lists the 15 builtin ModeTemplates. Picking one hands the template
// back to the caller, which opens the existing ModeEditorSheet pre-filled —
// this sheet itself never creates a Mode.

struct ModeTemplatePickerSheet: View {
    let onPick: (ModeTemplate) -> Void

    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Start from a preset — you can rename it and tweak anything before saving.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(ModeTemplate.builtins) { template in
                            Button {
                                onPick(template)
                                dismiss()
                            } label: {
                                templateRow(template)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("From Template")
            .frame(minWidth: 500, idealWidth: 540, minHeight: 480, idealHeight: 560)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func templateRow(_ template: ModeTemplate) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: template.icon)
                    .foregroundColor(.accentColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(template.name)
                    .font(.callout.weight(.medium))
                    .foregroundColor(.primary)
                Text(template.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
