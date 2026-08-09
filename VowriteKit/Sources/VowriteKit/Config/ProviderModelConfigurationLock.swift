import Darwin
import Foundation
import os

/// One lock domain for F-084 migration and every normal writer of the raw
/// provider/model/preset/Mode values it validates. POSIX locking coordinates
/// the iOS app and keyboard; the process lock covers concurrent threads because
/// record locks owned by one process otherwise coalesce.
enum ProviderModelConfigurationLock {
    private static let lockFilename = ".provider-model-compat-2026-08-v1.lock"
    private static let inProcessLock = NSLock()
    private static let logger = Logger(
        subsystem: "com.vowrite.kit",
        category: "provider-model-config-lock"
    )

    static func productionDirectory() -> URL? {
        #if os(iOS)
        return FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: VowriteStorage.appGroupID
        )
        #else
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("Vowrite", isDirectory: true)
        #endif
    }

    static func withExclusiveLock<Result>(
        lockDirectory: URL,
        unavailable: Result,
        operation: () -> Result
    ) -> Result {
        inProcessLock.lock()
        defer { inProcessLock.unlock() }

        do {
            try FileManager.default.createDirectory(
                at: lockDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            return unavailable
        }

        let lockURL = lockDirectory.appendingPathComponent(lockFilename)
        let descriptor = lockURL.path.withCString {
            Darwin.open($0, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        }
        guard descriptor >= 0 else { return unavailable }
        defer { Darwin.close(descriptor) }

        var fileLock = flock()
        fileLock.l_type = Int16(F_WRLCK)
        fileLock.l_whence = Int16(SEEK_SET)
        guard Darwin.fcntl(descriptor, F_SETLKW, &fileLock) != -1 else {
            return unavailable
        }
        defer {
            var unlock = flock()
            unlock.l_type = Int16(F_UNLCK)
            unlock.l_whence = Int16(SEEK_SET)
            _ = Darwin.fcntl(descriptor, F_SETLK, &unlock)
        }
        return operation()
    }

    static func withProductionLock<Result>(_ operation: () -> Result) -> Result? {
        guard let directory = productionDirectory() else { return nil }
        return withExclusiveLock(
            lockDirectory: directory,
            unavailable: nil,
            operation: operation
        )
    }

    static func performMutation(_ operation: () -> Void) {
        let succeeded = withProductionLock {
            operation()
            return true
        }
        if succeeded != true {
            logger.error("Provider configuration write skipped because the shared lock is unavailable")
        }
    }

    static func readSnapshot<Result>(_ operation: () -> Result) -> Result {
        // Reads cannot report lock failure through the existing synchronous
        // API. Falling back keeps configuration available; writes remain
        // fail-closed and migration itself never proceeds without the lock.
        withProductionLock(operation) ?? operation()
    }
}
