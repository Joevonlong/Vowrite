import Foundation

public enum CredentialManager {

    /// Called before each dictation. Proactively refreshes any OAuth tokens
    /// that are close to expiry (within the provider's safety window).
    /// Has a 3-second timeout per provider — if refresh times out, recording
    /// still starts and uses any existing token (or falls back to API key).
    public static func prepareCredentials(for config: SplitAPIConfiguration) async {
        let providers = Set([config.stt.provider.providerID, config.polish.provider.providerID])
        await withTaskGroup(of: Void.self) { group in
            for providerID in providers {
                group.addTask {
                    await refreshWithTimeout(providerID: providerID)
                }
            }
        }
    }

    // MARK: - Internal (testable)

    /// Races `operation` against a timeout and returns as soon as either
    /// settles, WITHOUT waiting for the loser.
    ///
    /// This can't be built on `TaskGroup`/`async let`: those are structured —
    /// Swift will not let their scope exit until every child task has finished,
    /// cancelled or not, and cancellation is only cooperative. The real refresh
    /// (`OAuthRefreshManager.refreshIfNeeded`) internally spawns its own
    /// unstructured `Task` that never checks cancellation and awaits a
    /// URLSession call with a long default timeout, so a TaskGroup-based race
    /// would still block here for up to that long. Two independent unstructured
    /// `Task`s racing to resume a single continuation actually let the loser be
    /// abandoned: the function returns while the loser keeps running in the
    /// background — the token is still refreshed for the *next* dictation, per
    /// the existing best-effort contract, it just doesn't block this one.
    ///
    /// `operation` defaults to the real refresh and is injectable so tests can
    /// verify the timeout bound with a never-completing operation instead of a
    /// real network call.
    static func refreshWithTimeout(
        providerID: String,
        timeoutNanoseconds: UInt64 = 3_000_000_000,
        operation: @escaping @Sendable (String) async -> Void = { id in
            await OAuthRefreshManager.shared.refreshIfNeeded(for: id)
        }
    ) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let fireOnce = SingleFire { continuation.resume() }

            Task {
                await operation(providerID)
                fireOnce.fire()
            }
            Task {
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                fireOnce.fire()
            }
        }
    }
}

/// Runs its action at most once, safe to call concurrently from multiple threads.
private final class SingleFire: @unchecked Sendable {
    private let lock = NSLock()
    private var hasFired = false
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    func fire() {
        lock.lock()
        let alreadyFired = hasFired
        hasFired = true
        lock.unlock()
        guard !alreadyFired else { return }
        action()
    }
}
