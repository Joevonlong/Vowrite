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

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 10) {
            // Icon in rounded rectangle
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isActive
                        ? Color.accentColor.opacity(0.12)
                        : Color.secondary.opacity(0.08))
                    .frame(width: 48, height: 48)

                Image(systemName: mode.icon)
                    .font(.system(size: 22))
                    .foregroundColor(isActive ? .accentColor : .secondary)
            }

            // Name
            Text(mode.name)
                .font(.callout.weight(.medium))
                .foregroundColor(isActive ? .accentColor : .primary)
                .lineLimit(1)

            // Subtitle
            Text(mode.polishEnabled ? "STT + Polish" : "STT Only")
                .font(.caption2)
                .foregroundColor(.secondary)

            // Active badge
            if isActive {
                Label("Active", systemImage: "checkmark")
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.accentColor)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding(16)
        .background(
            isActive
                ? Color.accentColor.opacity(0.08)
                : Color.secondary.opacity(0.06)
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isActive
                        ? Color.accentColor.opacity(0.5)
                        : Color.primary.opacity(0.06),
                    lineWidth: isActive ? 2 : 1
                )
        )
        .shadow(
            color: isActive
                ? Color.accentColor.opacity(0.15)
                : (isHovered ? Color.black.opacity(0.08) : Color.clear),
            radius: isActive ? 10 : (isHovered ? 8 : 0),
            y: isHovered && !isActive ? 4 : 0
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.smooth(duration: 0.2), value: isHovered)
        .overlay(alignment: .topTrailing) {
            // Gear button on hover
            if isHovered {
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(.ultraThinMaterial)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .padding(8)
                .transition(.opacity)
            }
        }
        .onHover { hovering in
            withAnimation(.easeIn(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture(count: 2) {
            onEdit()
        }
        .onTapGesture(count: 1) {
            onSelect()
        }
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

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "plus.circle")
                .font(.system(size: 24))
                .foregroundColor(isHovered ? .accentColor : .secondary.opacity(0.4))

            Text("New Scene")
                .font(.caption)
                .foregroundColor(isHovered ? .accentColor : .secondary.opacity(0.5))
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding(16)
        .background(Color.clear)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )
                .foregroundColor(isHovered ? .secondary.opacity(0.4) : .secondary.opacity(0.2))
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.smooth(duration: 0.2), value: isHovered)
        .onHover { hovering in
            withAnimation(.easeIn(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            onTap()
        }
    }
}
