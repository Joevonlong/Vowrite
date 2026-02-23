import SwiftUI
import AVFoundation

struct VoxaMenuView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        // Record toggle
        Button {
            appState.toggleRecording()
        } label: {
            if appState.isRecording {
                Text("✓ Finish Recording")
            } else if case .processing = appState.state {
                Text("Processing...")
            } else {
                let shortcut = HotkeyDisplay.string(
                    keyCode: appState.hotkeyManager.keyCode,
                    modifiers: appState.hotkeyManager.modifiers
                )
                Text("Start Recording  \(shortcut)")
            }
        }
        .disabled(!appState.hasAPIKey || appState.state == .processing)

        if appState.isRecording {
            Button("✕ Cancel Recording") {
                appState.cancelRecording()
            }
        }

        Divider()

        // Status info
        if !appState.hasAPIKey {
            Text("⚠️ Set API Key in Settings")
                .foregroundColor(.secondary)
        }

        if case .error(let msg) = appState.state {
            Text("⚠️ \(msg)")
                .foregroundColor(.secondary)
        }

        if let result = appState.lastResult {
            Button("Copy Last Result") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(result, forType: .string)
            }
        }

        Divider()

        // Settings
        Button("Settings...") {
            WindowHelper.openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)

        // Select microphone submenu
        Menu("Select Microphone") {
            MicrophoneListView()
        }

        Button("History") {
            WindowHelper.openHistory()
        }

        Divider()

        // Version
        Text("Version 0.4")
            .foregroundColor(.secondary)

        Divider()

        Button("Quit Voxa") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}

struct MicrophoneListView: View {
    @State private var devices: [AVCaptureDevice] = []
    @State private var selectedID: String = ""

    var body: some View {
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
            Text("No microphones found")
                .foregroundColor(.secondary)
        }
    }

    init() {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )
        _devices = State(initialValue: discoverySession.devices)
        _selectedID = State(initialValue: UserDefaults.standard.string(forKey: "selectedMicrophoneID")
            ?? AVCaptureDevice.default(for: .audio)?.uniqueID ?? "")
    }
}
