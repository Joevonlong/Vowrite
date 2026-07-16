import VowriteKit
import SwiftUI
import AppKit

// MARK: - Add Per-App Mode Mapping Sheet (F-081)
//
// Two ways to pick a target app: choose from currently-running regular apps
// (NSWorkspace.runningApplications filtered to .activationPolicy == .regular,
// same filter Dock-visible apps use — background/agent processes are noise
// here), or type a bundle id manually for an app that isn't running right
// now. Either way, a Mode must be chosen before "Add" is enabled.

struct AddPerAppModeMappingSheet: View {
    @ObservedObject var perAppModeManager: PerAppModeManager
    @ObservedObject var modeManager: ModeManager

    @Environment(\.dismiss) private var dismiss

    private enum Source: String, CaseIterable, Identifiable {
        case runningApps = "Running Apps"
        case manual = "Manual Entry"
        var id: String { rawValue }
    }

    @State private var source: Source = .runningApps
    @State private var selectedBundleID: String?
    @State private var manualBundleID: String = ""
    @State private var selectedModeId: UUID

    init(perAppModeManager: PerAppModeManager, modeManager: ModeManager) {
        self.perAppModeManager = perAppModeManager
        self.modeManager = modeManager
        _selectedModeId = State(initialValue: modeManager.currentMode.id)
    }

    private var runningApps: [NSRunningApplication] {
        let myBundleID = Bundle.main.bundleIdentifier
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil && $0.bundleIdentifier != myBundleID }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    private var resolvedBundleID: String? {
        switch source {
        case .runningApps:
            return selectedBundleID
        case .manual:
            let trimmed = manualBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
    }

    private var canAdd: Bool { resolvedBundleID != nil }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Picker("", selection: $source) {
                    ForEach(Source.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Group {
                    switch source {
                    case .runningApps:
                        runningAppsList
                    case .manual:
                        manualEntryForm
                    }
                }
                .padding(.horizontal, 20)

                Divider()
                    .padding(.horizontal, 20)

                HStack {
                    Text("Scene")
                        .font(.body.weight(.semibold))
                    Spacer()
                    Picker("", selection: $selectedModeId) {
                        ForEach(modeManager.modes) { mode in
                            Text(mode.name).tag(mode.id)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .navigationTitle("Add App Mapping")
            .frame(minWidth: 460, idealWidth: 480, minHeight: 420, idealHeight: 460)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let bundleID = resolvedBundleID else { return }
                        perAppModeManager.setMapping(bundleID: bundleID, modeId: selectedModeId)
                        dismiss()
                    }
                    .disabled(!canAdd)
                }
            }
        }
    }

    private var runningAppsList: some View {
        Group {
            if runningApps.isEmpty {
                Text("No running apps found.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(runningApps, id: \.bundleIdentifier) { app in
                            appRow(app)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
    }

    private func appRow(_ app: NSRunningApplication) -> some View {
        let bundleID = app.bundleIdentifier ?? ""
        let isSelected = selectedBundleID == bundleID
        return Button {
            selectedBundleID = bundleID
        } label: {
            HStack(spacing: 10) {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 22, height: 22)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(app.localizedName ?? bundleID)
                        .font(.callout)
                        .foregroundColor(.primary)
                    Text(bundleID)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(8)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private var manualEntryForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bundle Identifier")
                .font(.body.weight(.semibold))
            TextField("e.g. com.tinyspeck.slackmacgap", text: $manualBundleID)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
            Text("Find it via \"osascript -e 'id of app \\\"AppName\\\"'\" in Terminal, or About This App in the app's menu.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
