import Sparkle
import Combine
import VowriteKit

final class MacUpdateManager: ObservableObject, UpdateProvider {
    /// Single shared instance. Sparkle's SPUStandardUpdaterController must never be
    /// started twice — a second instance is a Sparkle programmer error. `init` is
    /// private so `.shared` is the only way to obtain a MacUpdateManager.
    static let shared = MacUpdateManager()

    let updaterController: SPUStandardUpdaterController

    @Published var canCheckForUpdates = false
    @Published var automaticallyChecksForUpdates = false

    private init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$canCheckForUpdates)

        updaterController.updater.publisher(for: \.automaticallyChecksForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$automaticallyChecksForUpdates)
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    func setAutomaticChecks(_ enabled: Bool) {
        updaterController.updater.automaticallyChecksForUpdates = enabled
    }
}
