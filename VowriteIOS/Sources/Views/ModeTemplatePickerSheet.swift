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
                                    .font(.title3)
                                    .foregroundStyle(VW.Colors.Action.primary)
                                    .frame(width: 40, height: 40)
                                    .background(VW.Colors.Action.soft, in: RoundedRectangle(cornerRadius: VW.Radius.control))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(template.name)
                                        .font(.body)
                                        .foregroundStyle(VW.Colors.Text.primary)
                                    Text(template.summary)
                                        .font(.caption)
                                        .foregroundStyle(VW.Colors.Text.secondary)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(VW.Colors.Surface.panel)
                    }
                } footer: {
                    Text("Start from a preset — you can rename it and tweak anything before saving.")
                }
            }
            .vwIOSForm()
            .navigationTitle("Choose a Starting Point")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
