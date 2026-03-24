import VowriteKit
import SwiftUI

// MARK: - About Page

struct AboutPageView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // App identity (centered)
                VStack(spacing: 12) {
                    Image(systemName: "mic.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.accentColor)
                    Text("Vowrite")
                        .font(.system(size: 32, weight: .bold))
                    Text("AI Voice Keyboard")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Text("Say it once. Mean it perfectly.")
                        .font(.body).italic()
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 16)

                // Version & Updates
                SettingsSection(icon: "arrow.triangle.2.circlepath", title: "Updates") {
                    VStack(spacing: 12) {
                        SettingsRow(title: "Version", description: "Current installed version") {
                            Text("v\(AppVersion.current)")
                                .font(.body.monospaced())
                                .foregroundColor(.secondary)
                        }
                        Divider()
                        SettingsRow(title: "Check for Updates", description: "Download the latest version if available") {
                            Button("Check Now...") {
                                (NSApp.delegate as? AppDelegate)?.checkForUpdates()
                            }
                            .buttonStyle(.bordered)
                        }
                        SettingsRow(title: "Automatic Updates", description: "Periodically check for new versions") {
                            Toggle("", isOn: Binding(
                                get: {
                                    (NSApp.delegate as? AppDelegate)?.updateManager.updaterController.updater.automaticallyChecksForUpdates ?? false
                                },
                                set: { newValue in
                                    (NSApp.delegate as? AppDelegate)?.updateManager.updaterController.updater.automaticallyChecksForUpdates = newValue
                                }
                            ))
                            .toggleStyle(.switch)
                        }
                    }
                }

                // Links
                SettingsSection(icon: "link", title: "Links") {
                    VStack(spacing: 12) {
                        SettingsRow(title: "Website", description: "vowrite.com") {
                            Link("Open →", destination: URL(string: "https://vowrite.com")!)
                                .font(.caption)
                        }
                        Divider()
                        SettingsRow(title: "GitHub", description: "Source code and issue tracker") {
                            Link("Open →", destination: URL(string: "https://github.com/Joevonlong/Vowrite")!)
                                .font(.caption)
                        }
                        Divider()
                        SettingsRow(title: "Changelog", description: "What's new in each version") {
                            Link("Open →", destination: URL(string: "https://github.com/Joevonlong/Vowrite/blob/main/CHANGELOG.md")!)
                                .font(.caption)
                        }
                        Divider()
                        SettingsRow(title: "License", description: "MIT License") {
                            Link("Open →", destination: URL(string: "https://github.com/Joevonlong/Vowrite/blob/main/LICENSE")!)
                                .font(.caption)
                        }
                    }
                }

                // System Info
                SettingsSection(icon: "desktopcomputer", title: "System Info") {
                    VStack(spacing: 8) {
                        systemInfoRow("macOS", value: ProcessInfo.processInfo.operatingSystemVersionString)
                        Divider()
                        systemInfoRow("Architecture", value: systemArchitecture)
                        Divider()
                        systemInfoRow("App Version", value: "v\(AppVersion.current)")
                    }
                }

                // Acknowledgments
                SettingsSection(icon: "heart", title: "Acknowledgments") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Vowrite is built with the help of these open-source projects:")
                            .font(.caption).foregroundColor(.secondary)

                        acknowledgmentRow("Sparkle", description: "Software update framework for macOS", url: "https://sparkle-project.org")
                    }
                }
            }
            .padding(32)
        }
    }

    // MARK: - Private

    private func systemInfoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(.body).fontWeight(.medium)
            Spacer()
            Text(value).font(.caption.monospaced()).foregroundColor(.secondary)
        }
    }

    private func acknowledgmentRow(_ name: String, description: String, url: String) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.body).fontWeight(.medium)
                Text(description).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Link("Visit →", destination: URL(string: url)!)
                .font(.caption)
        }
    }

    private var systemArchitecture: String {
        #if arch(arm64)
        return "Apple Silicon (arm64)"
        #elseif arch(x86_64)
        return "Intel (x86_64)"
        #else
        return "Unknown"
        #endif
    }
}
