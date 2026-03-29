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

                SettingsSection(icon: "waveform.circle", title: "Recording Indicator") {
                    RecordingIndicatorPicker()
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

// MARK: - Recording Indicator Picker

struct RecordingIndicatorPicker: View {
    @State private var selectedPreset = IndicatorPreset.current

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose the visual style shown while recording.")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: VW.Spacing.xl) {
                ForEach(IndicatorPreset.allCases, id: \.rawValue) { preset in
                    Button {
                        withAnimation(VW.Anim.springQuick) {
                            selectedPreset = preset
                            IndicatorPreset.current = preset
                        }
                    } label: {
                        VStack(spacing: VW.Spacing.md) {
                            indicatorPreview(for: preset)
                                .frame(width: 80, height: 48)

                            Text(preset.displayName)
                                .font(.caption)
                                .fontWeight(selectedPreset == preset ? .semibold : .regular)
                                .foregroundColor(selectedPreset == preset ? .accentColor : .secondary)
                        }
                        .padding(VW.Spacing.xl)
                        .frame(width: 120)
                        .background(
                            selectedPreset == preset
                                ? VW.Colors.Accent.light
                                : VW.Colors.Background.subtle
                        )
                        .cornerRadius(VW.Radius.xxxl)
                        .overlay(
                            RoundedRectangle(cornerRadius: VW.Radius.xxxl)
                                .stroke(
                                    selectedPreset == preset
                                        ? Color.accentColor.opacity(0.4)
                                        : VW.Colors.Stroke.light,
                                    lineWidth: selectedPreset == preset ? 1.5 : 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func indicatorPreview(for preset: IndicatorPreset) -> some View {
        switch preset {
        case .classicBar:
            HStack(spacing: 2) {
                ForEach(0..<7, id: \.self) { i in
                    let center = 3.0
                    let dist = abs(Double(i) - center) / center
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.white.opacity(1.0 - dist * 0.3))
                        .frame(width: 2, height: CGFloat(6 + (1.0 - dist) * 10))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.black.opacity(0.85)))

        case .orbPulse:
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 40, height: 40)
                    .blur(radius: 6)
                Circle()
                    .fill(RadialGradient(
                        colors: [.orange, .orange.opacity(0.3), .clear],
                        center: .center, startRadius: 8, endRadius: 20
                    ))
                    .frame(width: 32, height: 32)
                Image(systemName: "mic.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
            }
        }
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
            SettingsRow(title: "Sound feedback", description: "Play audio cues when recording starts and stops.") {
                Toggle("", isOn: Binding(
                    get: { SoundFeedback.isEnabled },
                    set: { SoundFeedback.isEnabled = $0 }
                ))
                .toggleStyle(.switch)
            }
            if IndicatorPreset.current == .classicBar {
                SettingsRow(title: "Bar size", description: "Size of the classic recording bar") {
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
}
