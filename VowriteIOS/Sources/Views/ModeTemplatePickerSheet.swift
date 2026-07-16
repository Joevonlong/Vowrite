import SwiftUI
import VowriteKit

// MARK: - Mode Template Picker Sheet
//
// F-077: Lists the 15 builtin ModeTemplates. Picking one hands the template
// back to the caller, which opens the existing ModeEditorSheet pre-filled —
// this sheet itself never creates a Mode.

struct ModeTemplatePickerSheet: View {
    let onPick: (ModeTemplate) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(ModeTemplate.builtins) { template in
                        Button {
                            onPick(template)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: template.icon)
                                    .foregroundColor(.accentColor)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(template.name)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    Text(template.summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } footer: {
                    Text("Start from a preset — you can rename it and tweak anything before saving.")
                }
            }
            .navigationTitle("From Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
