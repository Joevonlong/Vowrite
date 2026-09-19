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
                VStack(alignment: .leading, spacing: VW.Spacing.xl) {
                    Text("Start from a preset — you can rename it and tweak anything before saving.")
                        .font(.system(size: 13))
                        .foregroundColor(VW.Colors.Text.secondary)
                        .padding(.horizontal, VW.Spacing.section)
                        .padding(.top, VW.Spacing.section)

                    LazyVGrid(columns: columns, spacing: VW.Spacing.xl) {
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
                    .padding(.horizontal, VW.Spacing.section)
                    .padding(.bottom, VW.Spacing.section)
                }
            }
            .settingsPageStyle()
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
        HStack(spacing: VW.Spacing.xl) {
            ZStack {
                RoundedRectangle(cornerRadius: VW.Radius.panel)
                    .fill(VW.Colors.Action.soft)
                    .frame(width: 40, height: 40)
                Image(systemName: template.icon)
                    .foregroundColor(VW.Colors.Action.primary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(template.name)
                    .font(.callout.weight(.medium))
                    .foregroundColor(VW.Colors.Text.primary)
                Text(template.summary)
                    .font(.system(size: 13))
                    .foregroundColor(VW.Colors.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(VW.Spacing.xxl)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(VW.Colors.Surface.panel)
        .cornerRadius(VW.Radius.panel)
        .overlay(
            RoundedRectangle(cornerRadius: VW.Radius.panel)
                .stroke(VW.Colors.Border.standard, lineWidth: 1)
        )
    }
}
