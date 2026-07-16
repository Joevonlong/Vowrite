import VowriteKit
import SwiftUI
import AppKit

// MARK: - Per-App Modes Section (F-081)
//
// Extracted into its own View (rather than a computed property on
// PersonalizationPageView, like the Scenes/Learning sections there) to keep
// PersonalizationPageView's struct body under SwiftLint's type_body_length
// limit — same reasoning GeneralPage.swift already applies to
// TranslationLanguagesContent/PermissionsContent/etc.

struct PerAppModesSectionView: View {
    @ObservedObject private var perAppModeManager = PerAppModeManager.shared
    @ObservedObject private var modeManager = ModeManager.shared
    @State private var isAddingAppMapping = false

    private var autoSwitchDescription: String {
        "Automatically applies a scene based on which app is frontmost when you start recording. "
            + "Manually switching scenes wins until you move to a different mapped app."
    }

    var body: some View {
        SettingsSection(icon: "square.stack.3d.up", title: "Per-App Modes") {
            VStack(alignment: .leading, spacing: VW.Spacing.xl) {
                SettingsRow(title: "Auto-switch by app", description: autoSwitchDescription) {
                    Toggle("", isOn: Binding(
                        get: { perAppModeManager.enabled },
                        set: { perAppModeManager.enabled = $0 }
                    ))
                    .toggleStyle(.switch)
                }

                if perAppModeManager.enabled {
                    Divider()
                    mappingList
                    HStack {
                        Spacer()
                        Button {
                            isAddingAppMapping = true
                        } label: {
                            Label("Add App", systemImage: "plus")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
        .sheet(isPresented: $isAddingAppMapping) {
            AddPerAppModeMappingSheet(
                perAppModeManager: perAppModeManager,
                modeManager: modeManager
            )
        }
    }

    // MARK: - Mapping list

    private struct MappingEntry {
        let bundleID: String
        let modeId: UUID
    }

    private var sortedMappingEntries: [MappingEntry] {
        perAppModeManager.mapping
            .map { MappingEntry(bundleID: $0.key, modeId: $0.value) }
            .sorted { displayName(for: $0.bundleID) < displayName(for: $1.bundleID) }
    }

    @ViewBuilder
    private var mappingList: some View {
        if sortedMappingEntries.isEmpty {
            Text("No apps mapped yet.")
                .font(.caption)
                .foregroundColor(.secondary)
        } else {
            VStack(spacing: 10) {
                ForEach(sortedMappingEntries, id: \.bundleID) { entry in
                    mappingRow(entry)
                    if entry.bundleID != sortedMappingEntries.last?.bundleID {
                        Divider()
                    }
                }
            }
        }
    }

    private func mappingRow(_ entry: MappingEntry) -> some View {
        HStack(spacing: VW.Spacing.md) {
            appIconImage(for: entry.bundleID)
                .resizable()
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(displayName(for: entry.bundleID))
                    .font(.body)
                Text(entry.bundleID)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            mappedModePicker(for: entry)

            Button {
                withAnimation(VW.Anim.easeQuick) {
                    perAppModeManager.removeMapping(bundleID: entry.bundleID)
                }
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Remove mapping")
        }
    }

    /// F-081: A mapping whose target Mode was deleted elsewhere (Scenes)
    /// shows "Missing scene" instead of silently looking unmapped or
    /// crashing — the underlying decision (`PerAppModeDecision.lookupMapping`
    /// returning `.missingMode`) already treats it as "no override," this
    /// just makes that visible so the user can re-pick or remove it.
    @ViewBuilder
    private func mappedModePicker(for entry: MappingEntry) -> some View {
        let target = modeManager.modes.first { $0.id == entry.modeId }
        HStack(spacing: 6) {
            if target == nil {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.caption2)
                    .help("The scene this app was mapped to was deleted.")
            }
            Picker("", selection: Binding<UUID>(
                get: { entry.modeId },
                set: { perAppModeManager.setMapping(bundleID: entry.bundleID, modeId: $0) }
            )) {
                if target == nil {
                    Text("Missing scene").tag(entry.modeId)
                }
                ForEach(modeManager.modes) { mode in
                    Text(mode.name).tag(mode.id)
                }
            }
            .labelsHidden()
            .frame(width: 140)
        }
    }

    // MARK: - App name/icon lookup

    private func displayName(for bundleID: String) -> String {
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first,
           let name = running.localizedName {
            return name
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return FileManager.default.displayName(atPath: url.path)
                .replacingOccurrences(of: ".app", with: "")
        }
        return bundleID
    }

    private func appIconImage(for bundleID: String) -> Image {
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first,
           let icon = running.icon {
            return Image(nsImage: icon)
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
        }
        return Image(systemName: "app.dashed")
    }
}
