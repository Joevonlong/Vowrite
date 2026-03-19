import SwiftUI
import VowriteKit

struct HomeView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                backgroundGradient
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    // Mode indicator
                    modeIndicator
                        .padding(.bottom, 32)

                    // Main content area: recording or result
                    switch appState.state {
                    case .idle:
                        idleView
                    case .recording:
                        RecordingView()
                    case .processing:
                        processingView
                    case .error(let message):
                        errorView(message)
                    }

                    Spacer()

                    // Last result preview
                    if let result = appState.lastResult, appState.state == .idle {
                        ResultPreviewCard(text: result)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 16)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.spring(duration: 0.4), value: appState.state)
            }
            .navigationTitle("Vowrite")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Subviews

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(.systemBackground).opacity(0.95)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var modeIndicator: some View {
        let mode = ModeManager.shared.currentMode
        return HStack(spacing: 6) {
            Text(mode.icon)
                .font(.caption)
            Text(mode.name)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var idleView: some View {
        VStack(spacing: 20) {
            // Large record button
            RecordButton {
                appState.toggleRecording()
            }

            Text("Tap to record")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var processingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.accentColor)

            Text("Processing...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.red)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Try Again") {
                appState.toggleRecording()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Record Button

struct RecordButton: View {
    let action: () -> Void
    @State private var isPressing = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 4)
                    .frame(width: 120, height: 120)

                // Pulsing background
                Circle()
                    .fill(Color.accentColor.opacity(isPressing ? 0.2 : 0.1))
                    .frame(width: 110, height: 110)

                // Inner circle
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 80, height: 80)
                    .shadow(color: .accentColor.opacity(0.4), radius: 12, y: 4)

                // Mic icon
                Image(systemName: "mic.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressing = true }
                .onEnded { _ in isPressing = false }
        )
        .scaleEffect(isPressing ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressing)
    }
}

// MARK: - Result Preview Card

struct ResultPreviewCard: View {
    let text: String
    @State private var showCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Last Result")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    UIPasteboard.general.string = text
                    showCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showCopied = false
                    }
                } label: {
                    Label(showCopied ? "Copied" : "Copy",
                          systemImage: showCopied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)

                ShareLink(item: text) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }

            Text(text)
                .font(.body)
                .lineLimit(4)
                .foregroundStyle(.primary)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
