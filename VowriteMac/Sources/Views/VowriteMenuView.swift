import VowriteKit
import SwiftUI
import AVFoundation

struct VowriteMenuView: View {
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
            Text("⚠️ Set provider keys in Settings")
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
            WindowHelper.openMainWindow()
        }
        .keyboardShortcut(",", modifiers: .command)

        // Select microphone submenu
        Menu("Select Microphone") {
            MicrophoneListView()
        }

        Button("History") {
            WindowHelper.openMainWindow()
        }

        Divider()

        // Version
        Text("Version \(AppVersion.current)")
            .foregroundColor(.secondary)

        Divider()

        Button("Quit Vowrite") {
            NSApplication.shared.terminate(nil)
        }
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
                Text("No microphones found")
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
