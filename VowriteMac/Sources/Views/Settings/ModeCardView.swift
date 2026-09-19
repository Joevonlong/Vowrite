import VowriteKit
import SwiftUI

// MARK: - Mode Card View

struct ModeCardView: View {
    let mode: Mode
    let isActive: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    var onDelete: (() -> Void)? = nil   // nil for builtin
    var onReset: (() -> Void)? = nil    // non-nil for builtin

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                VStack(alignment: .leading, spacing: VW.Spacing.xl) {
                    HStack {
                        Image(systemName: mode.icon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(VW.Colors.Action.primary)
                        Spacer()
                        if isActive {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(VW.Colors.Action.primary)
                                .accessibilityHidden(true)
                        }
                    }
                    Text(mode.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isActive ? VW.Colors.Action.primary : VW.Colors.Text.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(mode.polishEnabled ? "STT + Polish" : "STT Only")
                        .font(.system(size: 12))
                        .foregroundStyle(VW.Colors.Text.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
                .padding(VW.Spacing.xxl)
                .contentShape(Rectangle())
            }
            .onTapGesture(count: 2) { onEdit() }
            .onTapGesture(count: 1) { onSelect() }
            .focusable()
            .onKeyPress(.return) {
                onSelect()
                return .handled
            }
            .onKeyPress(.space) {
                onSelect()
                return .handled
            }
            .accessibilityLabel(mode.name)
            .accessibilityValue(isActive ? "Active scene" : "")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onSelect() }
            .accessibilityAddTraits(isActive ? [.isSelected] : [])

            HStack {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Edit \(mode.name)")
                Spacer()
                Text(isActive ? "Active" : (mode.isBuiltin ? "Built-in" : "Custom"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isActive ? VW.Colors.Action.primary : VW.Colors.Text.secondary)
            }
            .padding(.horizontal, VW.Spacing.xxl)
            .padding(.bottom, VW.Spacing.xxl)
        }
        .background(isActive ? VW.Colors.Action.soft : VW.Colors.Surface.panel)
        .clipShape(RoundedRectangle(cornerRadius: VW.Radius.panel))
        .overlay(
            RoundedRectangle(cornerRadius: VW.Radius.panel)
                .stroke(isActive ? VW.Colors.Action.primary : VW.Colors.Border.standard, lineWidth: 1)
        )
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit…", systemImage: "pencil")
            }

            Button {
                onDuplicate()
            } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
            }

            Divider()

            if let onReset {
                Button {
                    onReset()
                } label: {
                    Label("Reset to Default", systemImage: "arrow.counterclockwise")
                }
            }

            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - New Scene Placeholder Card

struct NewSceneCardView: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: VW.Spacing.xl) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                Text("New Scene")
                    .font(.system(size: 14, weight: .semibold))
                Text("Create your own way to write.")
                    .font(.system(size: 12))
            }
            .foregroundStyle(VW.Colors.Text.secondary)
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
            .padding(VW.Spacing.xxl)
            .contentShape(Rectangle())
            .background(VW.Colors.Surface.panel)
            .clipShape(RoundedRectangle(cornerRadius: VW.Radius.panel))
            .overlay(
                RoundedRectangle(cornerRadius: VW.Radius.panel)
                    .stroke(VW.Colors.Border.standard, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            )
        }
        .buttonStyle(.plain)
    }
}
