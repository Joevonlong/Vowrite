import XCTest
@testable import VowriteKit

final class ProviderModelMigration202608Tests: ProviderModelMigration202608TestCase {
    private static let processRunnerFlag = "F084_PROCESS_RUNNER"
    private static let processSuiteKey = "F084_PROCESS_SUITE"
    private static let processDirectoryKey = "F084_PROCESS_DIRECTORY"
    private static let processResultKey = "F084_PROCESS_RESULT"

    func testKeyboardFirstEmptyGroupDefersUntilContainerImportsLegacyConfiguration() {
        let before = defaults.persistentDomain(forName: suiteName)

        XCTAssertEqual(
            ProviderModelMigration202608.runIfNeeded(defaults: defaults, lockDirectory: directory),
            .deferred
        )
        assertPersistentDomainEquals(before)
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: ProviderModelMigration202608.journalURL(in: directory).path
            )
        )

        // Simulate the container's later standard-defaults import into the
        // same App Group suite.
        defaults.set(APIProvider.groq.rawValue, forKey: StorageKeys.splitAPIPolishProvider)
        defaults.set("qwen/qwen3-32b", forKey: StorageKeys.splitAPIPolishModel)
        defaults.synchronize()

        XCTAssertEqual(
            ProviderModelMigration202608.runIfNeeded(defaults: defaults, lockDirectory: directory),
            .committed
        )
        XCTAssertEqual(
            defaults.string(forKey: StorageKeys.splitAPIPolishModel),
            "openai/gpt-oss-120b"
        )
    }

    func testKeyboardFirstMigratesStaleAppGroupDataImmediately() {
        defaults.set(APIProvider.together.rawValue, forKey: StorageKeys.splitAPISTTProvider)
        defaults.set("whisper-large-v3", forKey: StorageKeys.splitAPISTTModel)

        XCTAssertEqual(
            ProviderModelMigration202608.runIfNeeded(defaults: defaults, lockDirectory: directory),
            .committed
        )
        XCTAssertEqual(
            defaults.string(forKey: StorageKeys.splitAPISTTModel),
            "openai/whisper-large-v3"
        )
    }

    func testSameBareModeIDsRemainByteForByteUnchangedForAggregatorAndCustomUse() throws {
        var mode = Mode.builtinModes[0]
        mode.polishModel = "deepseek-chat"
        let modeData = try JSONEncoder().encode([mode])
        defaults.set(modeData, forKey: StorageKeys.vowriteModes)
        defaults.set(APIProvider.openrouter.rawValue, forKey: StorageKeys.splitAPIPolishProvider)
        defaults.set("deepseek-chat", forKey: StorageKeys.splitAPIPolishModel)

        XCTAssertEqual(
            ProviderModelMigration202608.runIfNeeded(defaults: defaults, lockDirectory: directory),
            .committed
        )

        XCTAssertEqual(defaults.string(forKey: StorageKeys.splitAPIPolishModel), "deepseek-chat")
        XCTAssertEqual(defaults.data(forKey: StorageKeys.vowriteModes), modeData)
    }

    func testCorruptModesAbortWithZeroDefaultsOrJournalWrites() throws {
        defaults.set(APIProvider.groq.rawValue, forKey: StorageKeys.splitAPIPolishProvider)
        defaults.set("qwen/qwen3-32b", forKey: StorageKeys.splitAPIPolishModel)
        defaults.set(Data("not-json".utf8), forKey: StorageKeys.vowriteModes)
        let before = defaults.persistentDomain(forName: suiteName)

        XCTAssertEqual(
            ProviderModelMigration202608.runIfNeeded(defaults: defaults, lockDirectory: directory),
            .blockedCorruptData
        )

        assertPersistentDomainEquals(before)
        XCTAssertFalse(FileManager.default.fileExists(atPath: ProviderModelMigration202608.journalURL(in: directory).path))
    }

    func testCorruptUserPresetsAbortWithoutMaskingAsEmptyCollection() throws {
        defaults.set(APIProvider.groq.rawValue, forKey: StorageKeys.splitAPIPolishProvider)
        defaults.set("qwen/qwen3-32b", forKey: StorageKeys.splitAPIPolishModel)
        defaults.set(Data("not-json".utf8), forKey: StorageKeys.splitAPIUserPresets)
        let before = defaults.persistentDomain(forName: suiteName)

        XCTAssertEqual(
            ProviderModelMigration202608.runIfNeeded(defaults: defaults, lockDirectory: directory),
            .blockedCorruptData
        )

        assertPersistentDomainEquals(before)
        XCTAssertFalse(FileManager.default.fileExists(atPath: ProviderModelMigration202608.journalURL(in: directory).path))
    }

    func testUndecodableProviderAbortsWithZeroWrites() {
        defaults.set("Removed Provider", forKey: StorageKeys.splitAPIPolishProvider)
        defaults.set("qwen/qwen3-32b", forKey: StorageKeys.splitAPIPolishModel)
        let before = defaults.persistentDomain(forName: suiteName)

        XCTAssertEqual(
            ProviderModelMigration202608.runIfNeeded(defaults: defaults, lockDirectory: directory),
            .blockedCorruptData
        )

        assertPersistentDomainEquals(before)
    }

    func testInterruptionAfterJournalAndEveryWriteRecoversToVerifiedFinalState() throws {
        for interruptAfter in 0...3 {
            let attemptSuite = "\(suiteName!).\(interruptAfter)"
            let attemptDefaults = try XCTUnwrap(UserDefaults(suiteName: attemptSuite))
            attemptDefaults.removePersistentDomain(forName: attemptSuite)
            let attemptDirectory = directory.appendingPathComponent("attempt-\(interruptAfter)", isDirectory: true)
            try FileManager.default.createDirectory(at: attemptDirectory, withIntermediateDirectories: true)

            attemptDefaults.set(APIProvider.together.rawValue, forKey: StorageKeys.splitAPISTTProvider)
            attemptDefaults.set("whisper-large-v3", forKey: StorageKeys.splitAPISTTModel)
            attemptDefaults.set(APIProvider.groq.rawValue, forKey: StorageKeys.splitAPIPolishProvider)
            attemptDefaults.set("llama-3.3-70b-versatile", forKey: StorageKeys.splitAPIPolishModel)
            let preset = UserAPIPreset(
                id: UUID(),
                name: "Legacy",
                configuration: SplitAPIConfiguration(
                    stt: APIEndpointConfiguration(provider: .groq, model: "whisper-large-v3"),
                    polish: APIEndpointConfiguration(provider: .siliconflow, model: "zai-org/GLM-4.6")
                )
            )
            attemptDefaults.set(try JSONEncoder().encode([preset]), forKey: StorageKeys.splitAPIUserPresets)

            XCTAssertEqual(
                ProviderModelMigration202608.runIfNeeded(
                    defaults: attemptDefaults,
                    lockDirectory: attemptDirectory,
                    interruptAfterAppliedEntries: interruptAfter
                ),
                .interrupted
            )
            XCTAssertEqual(
                ProviderModelMigration202608.runIfNeeded(defaults: attemptDefaults, lockDirectory: attemptDirectory),
                .committed
            )
            XCTAssertEqual(attemptDefaults.string(forKey: StorageKeys.splitAPISTTModel), "openai/whisper-large-v3")
            XCTAssertEqual(attemptDefaults.string(forKey: StorageKeys.splitAPIPolishModel), "openai/gpt-oss-120b")
            XCTAssertEqual(
                attemptDefaults.string(forKey: StorageKeys.providerModelCompatibilityMigrationID),
                ProviderModelSafetyRules.migrationID
            )
            attemptDefaults.removePersistentDomain(forName: attemptSuite)
        }
    }

    func testRecoveryStopsOnUnexpectedThirdValueAndPreservesUserEdit() {
        defaults.set(APIProvider.groq.rawValue, forKey: StorageKeys.splitAPIPolishProvider)
        defaults.set("qwen/qwen3-32b", forKey: StorageKeys.splitAPIPolishModel)

        XCTAssertEqual(
            ProviderModelMigration202608.runIfNeeded(
                defaults: defaults,
                lockDirectory: directory,
                interruptAfterAppliedEntries: 0
            ),
            .interrupted
        )
        defaults.set("enterprise/custom-model", forKey: StorageKeys.splitAPIPolishModel)

        XCTAssertEqual(
            ProviderModelMigration202608.runIfNeeded(defaults: defaults, lockDirectory: directory),
            .blockedUnexpectedState
        )
        XCTAssertEqual(defaults.string(forKey: StorageKeys.splitAPIPolishModel), "enterprise/custom-model")
        XCTAssertNil(defaults.string(forKey: StorageKeys.providerModelCompatibilityMigrationID))
    }

    func testRecoveryRevalidatesModesBeforeApplyingPreparedJournal() throws {
        defaults.set(APIProvider.groq.rawValue, forKey: StorageKeys.splitAPIPolishProvider)
        defaults.set("qwen/qwen3-32b", forKey: StorageKeys.splitAPIPolishModel)
        defaults.set(
            try JSONEncoder().encode([Mode.builtinModes[0]]),
            forKey: StorageKeys.vowriteModes
        )
        XCTAssertEqual(
            ProviderModelMigration202608.runIfNeeded(
                defaults: defaults,
                lockDirectory: directory,
                interruptAfterAppliedEntries: 0
            ),
            .interrupted
        )
        let journalBefore = try Data(contentsOf: ProviderModelMigration202608.journalURL(in: directory))

        defaults.set(Data("not-json-after-prepare".utf8), forKey: StorageKeys.vowriteModes)

        XCTAssertEqual(
            ProviderModelMigration202608.runIfNeeded(defaults: defaults, lockDirectory: directory),
            .blockedCorruptData
        )
        XCTAssertEqual(defaults.string(forKey: StorageKeys.splitAPIPolishModel), "qwen/qwen3-32b")
        XCTAssertNil(defaults.string(forKey: StorageKeys.providerModelCompatibilityMigrationID))
        XCTAssertEqual(
            try Data(contentsOf: ProviderModelMigration202608.journalURL(in: directory)),
            journalBefore
        )
    }

    func testTamperedJournalWithDuplicateEntryIsRejectedBeforeAnyConfigWrite() throws {
        defaults.set(APIProvider.groq.rawValue, forKey: StorageKeys.splitAPIPolishProvider)
        defaults.set("qwen/qwen3-32b", forKey: StorageKeys.splitAPIPolishModel)
        XCTAssertEqual(
            ProviderModelMigration202608.runIfNeeded(
                defaults: defaults,
                lockDirectory: directory,
                interruptAfterAppliedEntries: 0
            ),
            .interrupted
        )
        try mutateJournal { journal in
            var entries = try XCTUnwrap(journal["entries"] as? [[String: Any]])
            entries.append(try XCTUnwrap(entries.first))
            journal["entries"] = entries
        }

        XCTAssertEqual(
            ProviderModelMigration202608.runIfNeeded(defaults: defaults, lockDirectory: directory),
            .blockedJournal
        )
        XCTAssertEqual(defaults.string(forKey: StorageKeys.splitAPIPolishModel), "qwen/qwen3-32b")
        XCTAssertNil(defaults.string(forKey: StorageKeys.providerModelCompatibilityMigrationID))
    }

    func testTamperedJournalHashesAndPayloadAreRejectedBeforeResume() throws {
        defaults.set(APIProvider.groq.rawValue, forKey: StorageKeys.splitAPIPolishProvider)
        defaults.set("qwen/qwen3-32b", forKey: StorageKeys.splitAPIPolishModel)
        XCTAssertEqual(
            ProviderModelMigration202608.runIfNeeded(
                defaults: defaults,
                lockDirectory: directory,
                interruptAfterAppliedEntries: 0
            ),
            .interrupted
        )
        try mutateJournal { journal in
            var entries = try XCTUnwrap(journal["entries"] as? [[String: Any]])
            entries[0]["afterHash"] = String(repeating: "0", count: 64)
            var after = try XCTUnwrap(entries[0]["after"] as? [String: Any])
            after["value"] = "attacker/model"
            entries[0]["after"] = after
            journal["entries"] = entries
        }

        XCTAssertEqual(
            ProviderModelMigration202608.runIfNeeded(defaults: defaults, lockDirectory: directory),
            .blockedJournal
        )
        XCTAssertEqual(defaults.string(forKey: StorageKeys.splitAPIPolishModel), "qwen/qwen3-32b")
    }

    func testRollbackRejectsTamperedCommittedJournalWithoutWriting() throws {
        defaults.set(APIProvider.groq.rawValue, forKey: StorageKeys.splitAPIPolishProvider)
        defaults.set("qwen/qwen3-32b", forKey: StorageKeys.splitAPIPolishModel)
        XCTAssertEqual(
            ProviderModelMigration202608.runIfNeeded(defaults: defaults, lockDirectory: directory),
            .committed
        )
        try mutateJournal { journal in
            var entries = try XCTUnwrap(journal["entries"] as? [[String: Any]])
            entries[0]["key"] = StorageKeys.vowriteModes
            journal["entries"] = entries
        }
        let migrated = defaults.string(forKey: StorageKeys.splitAPIPolishModel)

        XCTAssertEqual(
            ProviderModelMigration202608.rollbackIfAllowed(
                defaults: defaults,
                lockDirectory: directory,
                isModelAllowed: { _, _, _ in true }
            ),
            .blockedJournal
        )
        XCTAssertEqual(defaults.string(forKey: StorageKeys.splitAPIPolishModel), migrated)
        XCTAssertEqual(
            defaults.string(forKey: StorageKeys.providerModelCompatibilityMigrationID),
            ProviderModelSafetyRules.migrationID
        )
    }

    func testRollbackRestoresOnlyAllowedAfterHashesAndPreservesThirdValues() {
        defaults.set(APIProvider.together.rawValue, forKey: StorageKeys.splitAPISTTProvider)
        defaults.set("whisper-large-v3", forKey: StorageKeys.splitAPISTTModel)
        defaults.set(APIProvider.groq.rawValue, forKey: StorageKeys.splitAPIPolishProvider)
        defaults.set("qwen/qwen3-32b", forKey: StorageKeys.splitAPIPolishModel)
        XCTAssertEqual(
            ProviderModelMigration202608.runIfNeeded(defaults: defaults, lockDirectory: directory),
            .committed
        )

        // Current rules still retire both old targets, so production rollback
        // must not restore either one.
        XCTAssertEqual(
            ProviderModelMigration202608.rollbackIfAllowed(defaults: defaults, lockDirectory: directory),
            .nothingToRollback
        )
        XCTAssertEqual(defaults.string(forKey: StorageKeys.splitAPISTTModel), "openai/whisper-large-v3")

        // Simulate a rollback build that re-allows the old targets while a user
        // has independently edited one migrated key.
        defaults.set("enterprise/custom-model", forKey: StorageKeys.splitAPIPolishModel)
        XCTAssertEqual(
            ProviderModelMigration202608.rollbackIfAllowed(
                defaults: defaults,
                lockDirectory: directory,
                isModelAllowed: { _, _, _ in true }
            ),
            .rolledBack
        )
        XCTAssertEqual(defaults.string(forKey: StorageKeys.splitAPISTTModel), "whisper-large-v3")
        XCTAssertEqual(defaults.string(forKey: StorageKeys.splitAPIPolishModel), "enterprise/custom-model")
        XCTAssertNil(defaults.string(forKey: StorageKeys.providerModelCompatibilityMigrationID))
        XCTAssertNil(defaults.string(forKey: StorageKeys.providerModelCompatibilityRulesetHash))
    }

    func testRolledBackJournalAllowsACleanReupgrade() {
        defaults.set(APIProvider.groq.rawValue, forKey: StorageKeys.splitAPIPolishProvider)
        defaults.set("qwen/qwen3-32b", forKey: StorageKeys.splitAPIPolishModel)
        XCTAssertEqual(
            ProviderModelMigration202608.runIfNeeded(defaults: defaults, lockDirectory: directory),
            .committed
        )
        XCTAssertEqual(
            ProviderModelMigration202608.rollbackIfAllowed(
                defaults: defaults,
                lockDirectory: directory,
                isModelAllowed: { _, _, _ in true }
            ),
            .rolledBack
        )
        XCTAssertEqual(defaults.string(forKey: StorageKeys.splitAPIPolishModel), "qwen/qwen3-32b")

        XCTAssertEqual(
            ProviderModelMigration202608.runIfNeeded(defaults: defaults, lockDirectory: directory),
            .committed
        )
        XCTAssertEqual(
            defaults.string(forKey: StorageKeys.splitAPIPolishModel),
            "openai/gpt-oss-120b"
        )
    }

    func testOneHundredConcurrentAttemptsProduceOneCommittedState() {
        defaults.set(APIProvider.groq.rawValue, forKey: StorageKeys.splitAPIPolishProvider)
        defaults.set("qwen/qwen3-32b", forKey: StorageKeys.splitAPIPolishModel)
        let testDefaults = defaults!
        let testDirectory = directory!
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "ProviderModelMigration202608Tests.concurrent", attributes: .concurrent)
        let resultLock = NSLock()
        var results: [ProviderModelMigration202608.RunResult] = []

        for _ in 0..<100 {
            group.enter()
            queue.async {
                let result = ProviderModelMigration202608.runIfNeeded(
                    defaults: testDefaults,
                    lockDirectory: testDirectory
                )
                resultLock.lock()
                results.append(result)
                resultLock.unlock()
                group.leave()
            }
        }

        XCTAssertEqual(group.wait(timeout: .now() + 10), .success)
        XCTAssertEqual(results.count, 100)
        XCTAssertEqual(results.filter { $0 == .committed }.count, 1)
        XCTAssertTrue(results.allSatisfy { $0 == .committed || $0 == .alreadyComplete })
        XCTAssertEqual(defaults.string(forKey: StorageKeys.splitAPIPolishModel), "openai/gpt-oss-120b")
        XCTAssertEqual(
            defaults.string(forKey: StorageKeys.providerModelCompatibilityMigrationID),
            ProviderModelSafetyRules.migrationID
        )
    }

    func testNormalConfigurationWriteCannotInterleaveBetweenValidationAndMigrationWrite() {
        defaults.set(APIProvider.groq.rawValue, forKey: StorageKeys.splitAPIPolishProvider)
        defaults.set("qwen/qwen3-32b", forKey: StorageKeys.splitAPIPolishModel)
        let migrationReachedWriteBoundary = DispatchSemaphore(value: 0)
        let allowMigrationToContinue = DispatchSemaphore(value: 0)
        let writerStarted = DispatchSemaphore(value: 0)
        let writerFinished = DispatchSemaphore(value: 0)
        let group = DispatchGroup()
        let testDefaults = defaults!
        let testDirectory = directory!

        group.enter()
        DispatchQueue.global().async {
            _ = ProviderModelMigration202608.runIfNeeded(
                defaults: testDefaults,
                lockDirectory: testDirectory,
                afterPreparedJournalBeforeResume: {
                    migrationReachedWriteBoundary.signal()
                    _ = allowMigrationToContinue.wait(timeout: .now() + 5)
                }
            )
            group.leave()
        }
        XCTAssertEqual(migrationReachedWriteBoundary.wait(timeout: .now() + 5), .success)

        let userConfiguration = SplitAPIConfiguration(
            stt: APIEndpointConfiguration(provider: .groq, model: "whisper-large-v3-turbo"),
            polish: APIEndpointConfiguration(provider: .openrouter, model: "qwen/qwen3-32b")
        )
        group.enter()
        DispatchQueue.global().async {
            writerStarted.signal()
            _ = APIConfig.apply(
                userConfiguration,
                defaults: testDefaults,
                lockDirectory: testDirectory
            )
            writerFinished.signal()
            group.leave()
        }
        XCTAssertEqual(writerStarted.wait(timeout: .now() + 5), .success)
        XCTAssertEqual(writerFinished.wait(timeout: .now() + 0.1), .timedOut)

        allowMigrationToContinue.signal()
        XCTAssertEqual(group.wait(timeout: .now() + 5), .success)
        XCTAssertEqual(
            defaults.string(forKey: StorageKeys.splitAPIPolishProvider),
            APIProvider.openrouter.rawValue
        )
        XCTAssertEqual(defaults.string(forKey: StorageKeys.splitAPIPolishModel), "qwen/qwen3-32b")
    }

    /// Invoked in isolation by `testTwoRealProcessRunners...`. A normal test
    /// suite run treats this as a no-op so it cannot recursively spawn runners.
    func testProcessRunner() throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment[Self.processRunnerFlag] == "1" else { return }
        let processSuite = try XCTUnwrap(environment[Self.processSuiteKey])
        let processDirectory = try XCTUnwrap(environment[Self.processDirectoryKey])
        let resultPath = try XCTUnwrap(environment[Self.processResultKey])
        let processDefaults = try XCTUnwrap(UserDefaults(suiteName: processSuite))

        let result = ProviderModelMigration202608.runIfNeeded(
            defaults: processDefaults,
            lockDirectory: URL(fileURLWithPath: processDirectory, isDirectory: true)
        )
        try Data(String(describing: result).utf8).write(
            to: URL(fileURLWithPath: resultPath),
            options: .atomic
        )
        XCTAssertTrue(result == .committed || result == .alreadyComplete)
    }

    func testTwoRealProcessRunnersProduceOneCommittedJournal() throws {
        let processSuite = "\(suiteName!).process"
        let processDefaults = try XCTUnwrap(UserDefaults(suiteName: processSuite))
        processDefaults.removePersistentDomain(forName: processSuite)
        defer { processDefaults.removePersistentDomain(forName: processSuite) }
        processDefaults.set(APIProvider.groq.rawValue, forKey: StorageKeys.splitAPIPolishProvider)
        processDefaults.set("qwen/qwen3-32b", forKey: StorageKeys.splitAPIPolishModel)
        processDefaults.synchronize()

        let bundlePath = Bundle(for: Self.self).bundleURL.path
        var processes: [Process] = []
        var outputPipes: [Pipe] = []
        var resultURLs: [URL] = []
        var expectations: [XCTestExpectation] = []

        for index in 0..<2 {
            let resultURL = directory.appendingPathComponent("process-result-\(index).txt")
            resultURLs.append(resultURL)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            process.arguments = [
                "xctest",
                "-XCTest",
                "VowriteKitTests.ProviderModelMigration202608Tests/testProcessRunner",
                bundlePath,
            ]
            var environment = ProcessInfo.processInfo.environment
            environment[Self.processRunnerFlag] = "1"
            environment[Self.processSuiteKey] = processSuite
            environment[Self.processDirectoryKey] = directory.path
            environment[Self.processResultKey] = resultURL.path
            process.environment = environment
            let pipe = Pipe()
            outputPipes.append(pipe)
            process.standardOutput = pipe
            process.standardError = pipe
            let expectation = expectation(description: "process runner \(index)")
            expectations.append(expectation)
            process.terminationHandler = { _ in expectation.fulfill() }
            processes.append(process)
        }

        try processes.forEach { try $0.run() }
        wait(for: expectations, timeout: 30)
        for (index, process) in processes.enumerated() {
            if process.isRunning { process.terminate() }
            let output = String(
                data: outputPipes[index].fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ) ?? ""
            XCTAssertEqual(process.terminationStatus, 0, output)
        }

        let results = try resultURLs.map {
            try String(contentsOf: $0, encoding: .utf8)
        }.sorted()
        XCTAssertEqual(results, ["alreadyComplete", "committed"])
        processDefaults.synchronize()
        XCTAssertEqual(
            processDefaults.string(forKey: StorageKeys.splitAPIPolishModel),
            "openai/gpt-oss-120b"
        )
        XCTAssertEqual(
            processDefaults.string(forKey: StorageKeys.providerModelCompatibilityMigrationID),
            ProviderModelSafetyRules.migrationID
        )
    }
}
