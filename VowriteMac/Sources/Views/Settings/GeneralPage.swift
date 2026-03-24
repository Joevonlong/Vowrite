import VowriteKit
import SwiftUI
import ServiceManagement

// MARK: - General Page

struct GeneralPageView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("General")
                    .font(.system(size: 24, weight: .bold))

                SettingsSection(icon: "keyboard", title: "Keyboard Shortcuts") {
                    VStack(spacing: 12) {
                        SettingsRow(title: "Dictate", description: "Press to start and stop dictation.") {
                            HotkeyRecorderButton(
                                currentKeyCode: appState.hotkeyManager.keyCode,
                                currentModifiers: appState.hotkeyManager.modifiers
                            ) { code, mods in
                                appState.hotkeyManager.update(keyCode: code, modifiers: mods)
                            }
                        }
                        SettingsRow(title: "Push to Talk", description: "Hold hotkey to record, release to stop.") {
                            Toggle("", isOn: Binding(
                                get: { appState.hotkeyManager.pushToTalkEnabled },
                                set: { appState.hotkeyManager.pushToTalkEnabled = $0 }
                            ))
                            .toggleStyle(.switch)
                        }
                        SettingsRow(title: "Mode Shortcuts", description: "⌃1 through ⌃9 to switch modes.") {
                            Text("Built-in")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                SettingsSection(icon: "paintpalette", title: "Appearance") {
                    SettingsRow(title: "Theme", description: "Choose between light, dark, or system appearance.") {
                        AppearancePicker(selection: $appearanceMode)
                    }
                }

                SettingsSection(icon: "globe", title: "Language") {
                    LanguageContent()
                }

                SettingsSection(icon: "lock.shield", title: "Permissions") {
                    PermissionsContent()
                }

                SettingsSection(icon: "power", title: "Startup & Recording") {
                    GeneralOptionsContent()
                }
            }
            .padding(32)
        }
    }
}

// MARK: - Language Content

struct LanguageContent: View {
    @State private var selectedLanguage: SupportedLanguage = LanguageConfig.globalLanguage

    var body: some View {
        VStack(spacing: 12) {
            SettingsRow(title: "Default Language", description: "Language hint for speech recognition. \"Auto-detect\" works best for most users.") {
                Picker("", selection: $selectedLanguage) {
                    ForEach(SupportedLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .frame(width: 180)
                .onChange(of: selectedLanguage) { _, v in
                    LanguageConfig.globalLanguage = v
                }
            }

            if selectedLanguage != .auto {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("Setting a specific language forces the speech engine to that language. If you speak multiple languages or mix languages, use \"Auto-detect\".")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Permissions Content

struct PermissionsContent: View {
    @State private var hasMic = MacPermissionManager.hasMicrophoneAccess()
    @State private var hasAcc = MacPermissionManager.hasAccessibilityAccess()
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 12) {
            SettingsRow(title: "Microphone", description: "Required for voice recording") {
                if hasMic {
                    Label("Granted", systemImage: "checkmark.circle.fill").foregroundColor(.green).font(.caption)
                } else {
                    Button("Grant") {
                        MacPermissionManager.requestMicrophoneAccess { g in Task { @MainActor in hasMic = g } }
                    }.buttonStyle(.bordered)
                }
            }
            SettingsRow(title: "Accessibility", description: "Required to paste text into apps") {
                if hasAcc {
                    Label("Granted", systemImage: "checkmark.circle.fill").foregroundColor(.green).font(.caption)
                } else {
                    Button("Open Settings") {
                        DispatchQueue.global().async { MacPermissionManager.requestAccessibilityAccess() }
                    }.buttonStyle(.bordered)
                }
            }
        }
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
                Task { @MainActor in hasMic = MacPermissionManager.hasMicrophoneAccess(); hasAcc = MacPermissionManager.hasAccessibilityAccess() }
            }
        }
        .onDisappear { timer?.invalidate() }
    }
}

// MARK: - General Options Content (Startup + Recording)

struct GeneralOptionsContent: View {
    @State private var launchAtLogin = false
    @State private var overlayStyle = OverlayStyle.current

    var body: some View {
        VStack(spacing: 12) {
            SettingsRow(title: "Launch at login", description: "Start Vowrite when you log in") {
                Toggle("", isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .onChange(of: launchAtLogin) { _, v in
                        do { if v { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } } catch {}
                    }
            }
            SettingsRow(title: "Recording overlay", description: "Size of the floating recording bar") {
                Picker("", selection: $overlayStyle) {
                    ForEach(OverlayStyle.allCases, id: \.rawValue) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .frame(width: 120)
                .onChange(of: overlayStyle) { _, v in
                    OverlayStyle.current = v
                }
            }
        }
    }
}
