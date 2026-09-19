import VowriteKit
import SwiftUI
import AVFoundation

/// Native status menu keeps macOS focus, submenu, and keyboard behavior.
struct VowriteMenuView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var modeManager = ModeManager.shared

    private var sessionActive: Bool { appState.isRecording || appState.state == .processing }

    private var autoPaste: Binding<Bool> {
        Binding(
            get: { modeManager.currentMode.autoPaste },
            set: { enabled in
                var mode = modeManager.currentMode
                mode.autoPaste = enabled
                modeManager.updateMode(mode)
            }
        )
    }

    var body: some View {
        Text("Vowrite").font(.headline)
        if !appState.hasAPIKey {
            Text("Provider setup required")
        }
        if case .error(let message) = appState.state {
            Text(message)
        }

        Button { appState.toggleRecording() } label: {
            if appState.isRecording {
                Label("Finish Recording", systemImage: "checkmark")
            } else if case .processing = appState.state {
                Label("Processing…", systemImage: "ellipsis")
            } else {
                let shortcut = HotkeyDisplay.string(keyCode: appState.hotkeyManager.keyCode, modifiers: appState.hotkeyManager.modifiers)
                Label("Start Speaking  \(shortcut)", systemImage: "mic")
            }
        }
        .disabled(!appState.hasAPIKey || appState.state == .processing)

        if appState.isRecording {
            Button { appState.cancelRecording() } label: { Label("Cancel Recording", systemImage: "xmark") }
        }

        Divider()

        Menu {
            ForEach(modeManager.modes) { mode in
                Button {
                    modeManager.select(mode)
                    PerAppModeManager.shared.noteManualModeSwitch()
                } label: {
                    if mode.id == modeManager.currentModeId {
                        Label(mode.name, systemImage: "checkmark")
                    } else {
                        Label(mode.name, systemImage: mode.icon)
                    }
                }
                .disabled(sessionActive)
            }
            Divider()
            Button("Manage Scenes…") { WindowHelper.openMainWindow(destination: .personalization) }
        } label: {
            Label(modeManager.currentMode.name, systemImage: modeManager.currentMode.icon)
        }

        Toggle("Auto-paste for This Scene", isOn: autoPaste)
            .disabled(sessionActive)

        Menu { MicrophoneListView() } label: { Label("Microphone", systemImage: "mic") }

        Divider()

        Button {
            guard let result = appState.lastResult else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(result, forType: .string)
        } label: { Label("Copy Last Result", systemImage: "doc.on.doc") }
        .disabled(appState.lastResult == nil)

        Button { WindowHelper.openMainWindow(destination: .models) } label: { Label("Models…", systemImage: "cpu") }
        Button { WindowHelper.openMainWindow(destination: .general) } label: { Label("Settings…", systemImage: "slider.horizontal.3") }
            .keyboardShortcut(",", modifiers: .command)
        Button { WindowHelper.openMainWindow(destination: .history) } label: { Label("History", systemImage: "clock.arrow.circlepath") }

        Divider()
        Text("Version \(AppVersion.current)")
        Button("Quit Vowrite") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q", modifiers: .command)
    }
}

struct MicrophoneListView: View {
    @State private var devices: [AVCaptureDevice] = []
    @State private var selectedID: String = ""

    var body: some View {
        Group {
            ForEach(devices, id: \.uniqueID) { device in
                Button {
                    selectedID = device.uniqueID
                    UserDefaults.standard.set(device.uniqueID, forKey: "selectedMicrophoneID")
                } label: {
                    HStack {
                        Text(device.localizedName)
                        if device.uniqueID == selectedID {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            if devices.isEmpty {
                Text("No microphones found — check your device connection")
                    .foregroundColor(.secondary)
            }
        }
        // V-3 perf fix: AVCaptureDevice.DiscoverySession enumerates hardware and is
        // expensive; it used to run in `init()`, which SwiftUI invokes every time
        // the parent menu's body is rebuilt (e.g. 20 Hz while recording), even
        // while this submenu is closed. Discovery now runs only when the submenu
        // actually appears, matching the same "rescan every time it's shown"
        // behavior as before, just without the per-parent-render cost.
        .onAppear {
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.microphone, .external],
                mediaType: .audio,
                position: .unspecified
            )
            devices = discoverySession.devices
            selectedID = UserDefaults.standard.string(forKey: "selectedMicrophoneID")
                ?? AVCaptureDevice.default(for: .audio)?.uniqueID ?? ""
        }
    }
}
