import VowriteKit
import SwiftUI
import ServiceManagement
import AppKit

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
                                if appState.hotkeyManager.dictateConflictsWithTranslate(keyCode: code, modifiers: mods) {
                                    showHotkeyConflictAlert(against: "Translate")
                                    return
                                }
                                appState.hotkeyManager.update(keyCode: code, modifiers: mods)
                            }
                        }
                        // F-063: Dedicated translate hotkey row
                        SettingsRow(title: "Translate", description: "Press to record and translate into your selected target language. Configure target in Modes → Translate.") {
                            HotkeyRecorderButton(
                                currentKeyCode: appState.hotkeyManager.translateKeyCode,
                                currentModifiers: appState.hotkeyManager.translateModifiers
                            ) { code, mods in
                                if appState.hotkeyManager.translateConflictsWithDictate(keyCode: code, modifiers: mods) {
                                    showHotkeyConflictAlert(against: "Dictate")
                                    return
                                }
                                appState.hotkeyManager.updateTranslate(keyCode: code, modifiers: mods)
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

                SettingsSection(icon: "globe.badge.chevron.backward", title: "Translation") {
                    TranslationLanguagesContent()
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

// F-063: Reject hotkey assignments that collide with another existing shortcut.
@MainActor
fileprivate func showHotkeyConflictAlert(against otherName: String) {
    let alert = NSAlert()
    alert.messageText = "Shortcut already in use"
    alert.informativeText = "This combination is already assigned to “\(otherName)”. Please choose a different shortcut."
    alert.alertStyle = .warning
    alert.addButton(withTitle: "OK")
    alert.runModal()
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

// MARK: - Translation Languages Content (F-066)

struct TranslationLanguagesContent: View {
    @ObservedObject private var modeManager = ModeManager.shared

    private var translateIndex: Int? {
        modeManager.modes.firstIndex { $0.isBuiltin && $0.isTranslation }
    }

    private var source: SupportedLanguage {
        guard let i = translateIndex,
              let raw = modeManager.modes[i].language,
              let lang = SupportedLanguage(rawValue: raw) else { return .auto }
        return lang
    }

    private var target: SupportedLanguage {
        guard let i = translateIndex,
              let raw = modeManager.modes[i].targetLanguage,
              let lang = SupportedLanguage(rawValue: raw),
              lang != .auto else { return .en }
        return lang
    }

    var body: some View {
        VStack(spacing: 12) {
            SettingsRow(title: "Source Language", description: "Speech-recognition hint for the Translate mode. Auto-detect handles mixed-language input.") {
                Picker("", selection: Binding(get: { source }, set: setSource)) {
                    ForEach(SupportedLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .frame(width: 180)
            }

            SettingsRow(title: "Target Language", description: "Translate output is rendered in this language.") {
                Picker("", selection: Binding(get: { target }, set: setTarget)) {
                    ForEach(SupportedLanguage.allCases.filter { $0 != .auto }) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .frame(width: 180)
            }

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                    .font(.caption)
                Text("Applies to the built-in Translate mode (⇧⌥Space). Custom translation modes keep their own settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
    }

    private func setSource(_ lang: SupportedLanguage) {
        guard let i = translateIndex else { return }
        var mode = modeManager.modes[i]
        mode.language = (lang == .auto) ? nil : lang.rawValue
        modeManager.updateMode(mode)
    }

    private func setTarget(_ lang: SupportedLanguage) {
        guard let i = translateIndex, lang != .auto else { return }
        var mode = modeManager.modes[i]
        mode.targetLanguage = lang.rawValue
        modeManager.updateMode(mode)
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

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: VW.Spacing.xl) {
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

        case .rippleRing:
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.cyan.opacity(0.3 - Double(i) * 0.08), lineWidth: 1.5)
                        .frame(width: CGFloat(20 + i * 10), height: CGFloat(20 + i * 10))
                }
                Image(systemName: "mic.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
            }

        case .spectrumArc:
            ZStack {
                ForEach(0..<8, id: \.self) { i in
                    let angle = Angle.degrees(-90 + (180.0 / 7.0) * Double(i))
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color(hue: 0.75 - Double(i) / 7.0 * 0.2, saturation: 0.7, brightness: 0.9))
                        .frame(width: 2.5, height: CGFloat(4 + (i % 3) * 3))
                        .offset(y: -16)
                        .rotationEffect(angle)
                }
                Image(systemName: "mic.fill")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.white)
            }

        case .minimalDot:
            Circle()
                .fill(Color(hue: 0.55, saturation: 0.8, brightness: 0.95))
                .frame(width: 20, height: 20)
                .shadow(color: Color.cyan.opacity(0.4), radius: 4)
        }
    }
}

// MARK: - General Options Content (Startup + Recording)

struct GeneralOptionsContent: View {
    @State private var launchAtLogin = false
    @State private var overlayStyle = OverlayStyle.current
    @AppStorage("autoLearnCorrections") private var autoLearnCorrections = true

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
            SettingsRow(title: "Auto-learn corrections", description: "Automatically learn when you correct pasted text.") {
                Toggle("", isOn: $autoLearnCorrections)
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
