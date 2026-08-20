// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

private final class AtomicProgressCounter: @unchecked Sendable {
    private var count: Int = 0
    private let lock = NSLock()

    func increment() -> Int {
        lock.lock()
        defer { lock.unlock() }
        count += 1
        return count
    }
}

/// Batch archive execution engine dispatching batch tasks to `ArchiveWorkerPool`.
public final class BatchArchiveEngine: @unchecked Sendable {
    public static let shared = BatchArchiveEngine()
    private let workerPool: ArchiveWorkerPool
    private let engineFacade: TTZipEngineFacading

    private convenience init() {
        self.init(workerPool: .shared, engineFacade: TTZipEngineFacade.shared)
    }

    internal init(
        workerPool: ArchiveWorkerPool = .shared,
        engineFacade: TTZipEngineFacading = TTZipEngineFacade.shared
    ) {
        self.workerPool = workerPool
        self.engineFacade = engineFacade
    }

    /// Dispatches batch compression tasks across worker pool threads.
    public func executeBatchCompress(
        tasks: [BatchCompressTask],
        priority: TaskPriorityLevel = .userInitiated,
        progress: (@Sendable (Int, Int) -> Void)? = nil
    ) async -> [BatchTaskResult] {
        guard !tasks.isEmpty else { return [] }

        let facade = self.engineFacade
        let total = tasks.count
        let progressCounter = AtomicProgressCounter()

        let items = tasks.map { task in
            ArchiveWorkItem(itemID: task.id.uuidString, priority: priority) {
                let sm = ArchiveBatchFacade.shared.registerStateMachine(id: task.id, taskName: "BatchCompress:\(task.outputPath)")
                let start = Date()
                do {
                    try sm.start()
                    let res = try await facade.quickCompress(
                        inputs: task.inputs,
                        outputPath: task.outputPath,
                        format: task.format,
                        level: task.level,
                        password: task.password,
                        splitSize: task.splitSize,
                        progress: nil
                    )
                    try sm.complete()

                    let cur = progressCounter.increment()
                    progress?(cur, total)

                    return BatchTaskResult(
                        id: task.id,
                        success: true,
                        targetPath: res.outputPath,
                        durationSeconds: res.durationSeconds,
                        errorMessage: nil
                    )
                } catch {
                    try? sm.fail(error: error)
                    let elapsed = Date().timeIntervalSince(start)

                    let cur = progressCounter.increment()
                    progress?(cur, total)

                    return BatchTaskResult(
                        id: task.id,
                        success: false,
                        targetPath: task.outputPath,
                        durationSeconds: elapsed,
                        errorMessage: error.localizedDescription
                    )
                }
            }
        }

        workerPool.start()

        let results = await withTaskGroup(of: BatchTaskResult.self) { group in
            for item in items {
                group.addTask {
                    var caughtError: Error? = nil
                    do {
                        if let res = try await self.workerPool.executeAndAwait(item) as? BatchTaskResult {
                            return res
                        }
                    } catch {
                        caughtError = error
                    }

                    if let task = tasks.first(where: { $0.id.uuidString == item.itemID }) {
                        return BatchTaskResult(
                            id: task.id,
                            success: false,
                            targetPath: task.outputPath,
                            durationSeconds: 0,
                            errorMessage: caughtError?.localizedDescription ?? "Task execution failed"
                        )
                    }
                    return BatchTaskResult(id: UUID(), success: false, targetPath: "", durationSeconds: 0, errorMessage: nil)
                }
            }

            var resList: [BatchTaskResult] = []
            for await res in group {
                resList.append(res)
            }
            return resList
        }

        await workerPool.drain()
        return results
    }

    /// Dispatches batch extraction tasks across worker pool threads.
    public func executeBatchExtract(
        tasks: [BatchExtractTask],
        priority: TaskPriorityLevel = .userInitiated,
        autoVaultUnlock: Bool = true,
        progress: (@Sendable (Int, Int) -> Void)? = nil
    ) async -> [BatchTaskResult] {
        guard !tasks.isEmpty else { return [] }

        let facade = self.engineFacade
        let total = tasks.count
        let progressCounter = AtomicProgressCounter()

        let items = tasks.map { task in
            ArchiveWorkItem(itemID: task.id.uuidString, priority: priority) {
                let sm = ArchiveBatchFacade.shared.registerStateMachine(id: task.id, taskName: "BatchExtract:\(task.archivePath)")
                let start = Date()
                do {
                    try sm.start()
                    let res = try await facade.quickExtract(
                        archivePath: task.archivePath,
                        destinationDir: task.destinationDir,
                        password: task.password,
                        autoVaultUnlock: autoVaultUnlock,
                        progress: nil
                    )
                    try sm.complete()

                    let cur = progressCounter.increment()
                    progress?(cur, total)

                    return BatchTaskResult(
                        id: task.id,
                        success: true,
                        targetPath: res.destinationDir,
                        durationSeconds: res.durationSeconds,
                        errorMessage: nil
                    )
                } catch {
                    try? sm.fail(error: error)
                    let elapsed = Date().timeIntervalSince(start)

                    let cur = progressCounter.increment()
                    progress?(cur, total)

                    return BatchTaskResult(
                        id: task.id,
                        success: false,
                        targetPath: task.destinationDir,
                        durationSeconds: elapsed,
                        errorMessage: error.localizedDescription
                    )
                }
            }
        }

        workerPool.start()

        let results = await withTaskGroup(of: BatchTaskResult.self) { group in
            for item in items {
                group.addTask {
                    var caughtError: Error? = nil
                    do {
                        if let res = try await self.workerPool.executeAndAwait(item) as? BatchTaskResult {
                            return res
                        }
                    } catch {
                        caughtError = error
                    }

                    if let task = tasks.first(where: { $0.id.uuidString == item.itemID }) {
                        return BatchTaskResult(
                            id: task.id,
                            success: false,
                            targetPath: task.destinationDir,
                            durationSeconds: 0,
                            errorMessage: caughtError?.localizedDescription ?? "Task execution failed"
                        )
                    }
                    return BatchTaskResult(id: UUID(), success: false, targetPath: "", durationSeconds: 0, errorMessage: nil)
                }
            }

            var resList: [BatchTaskResult] = []
            for await res in group {
                resList.append(res)
            }
            return resList
        }

        await workerPool.drain()
        return results
    }
}

// MARK: - PasswordRecoveryEngine WorkerPool Extension

private final class PasswordRecoveryAccumulator: @unchecked Sendable {
    private var foundPwd: String? = nil
    private var attempts: Int64 = 0
    private let lock = NSLock()

    func isFound() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return foundPwd != nil
    }

    func update(attemptsCount: Int64, password: String?, workerPool: ArchiveWorkerPool) {
        lock.lock()
        defer { lock.unlock() }
        self.attempts += attemptsCount
        if let pwd = password, self.foundPwd == nil {
            self.foundPwd = pwd
            workerPool.cancelAll()
        }
    }

    func snapshot() -> (foundPassword: String?, totalAttempts: Int64) {
        lock.lock()
        defer { lock.unlock() }
        return (foundPwd, attempts)
    }
}

extension PasswordRecoveryEngine {
    /// Executes parallel dictionary-based password recovery via worker pool.
    public func recoverPasswordParallel(
        archivePath: String,
        dictionary: [String],
        chunkSize: Int = 50,
        workerPool: ArchiveWorkerPool = .shared,
        priority: TaskPriorityLevel = .userInitiated
    ) async throws -> PasswordRecoveryResult {
        guard !dictionary.isEmpty else {
            return PasswordRecoveryResult(foundPassword: nil, totalAttempts: 0, durationSeconds: 0)
        }

        let start = Date()
        let chunks = stride(from: 0, to: dictionary.count, by: chunkSize).map {
            Array(dictionary[$0..<min($0 + chunkSize, dictionary.count)])
        }

        let accumulator = PasswordRecoveryAccumulator()

        let workItems = chunks.enumerated().map { (index, chunk) in
            ArchiveWorkItem(itemID: "pwd_chunk_\(index)", priority: priority) {
                if accumulator.isFound() {
                    return nil as String?
                }

                let res = try await self.recoverPassword(archivePath: archivePath, dictionary: chunk)
                accumulator.update(attemptsCount: res.totalAttempts, password: res.foundPassword, workerPool: workerPool)

                return res.foundPassword
            }
        }

        workerPool.start()

        await withTaskGroup(of: Void.self) { group in
            for item in workItems {
                group.addTask {
                    _ = try? await workerPool.executeAndAwait(item)
                }
            }
        }

        await workerPool.drain()

        let duration = max(0.001, Date().timeIntervalSince(start))
        let snap = accumulator.snapshot()

        return PasswordRecoveryResult(
            foundPassword: snap.foundPassword,
            totalAttempts: snap.totalAttempts,
            durationSeconds: duration
        )
    }
}

// MARK: - FormatDiagnosticSuiteRunner WorkerPool Extension

private final class DiagnosticResultsAccumulator: @unchecked Sendable {
    private var results: [ArchiveCompressionFormat: Bool] = [:]
    private let lock = NSLock()

    func set(format: ArchiveCompressionFormat, passed: Bool) {
        lock.lock()
        defer { lock.unlock() }
        results[format] = passed
    }

    func getResults() -> [ArchiveCompressionFormat: Bool] {
        lock.lock()
        defer { lock.unlock() }
        return results
    }
}

extension FormatDiagnosticSuiteRunner {
    /// Runs format diagnostic test suites concurrently using `ArchiveWorkerPool`.
    public func runDiagnosticSuitesParallel(
        configs: [FormatDiagnosticConfig],
        workerPool: ArchiveWorkerPool = .shared,
        priority: TaskPriorityLevel = .utility
    ) async -> [ArchiveCompressionFormat: Bool] {
        guard !configs.isEmpty else { return [:] }

        let accumulator = DiagnosticResultsAccumulator()

        let items = configs.map { config in
            ArchiveWorkItem(itemID: "diag_\(config.format.rawValue)", priority: priority) {
                let passed = (try? self.runDiagnosticSuite(config: config)) ?? false
                accumulator.set(format: config.format, passed: passed)
                return passed
            }
        }

        workerPool.start()

        await withTaskGroup(of: Void.self) { group in
            for item in items {
                group.addTask {
                    _ = try? await workerPool.executeAndAwait(item)
                }
            }
        }

        await workerPool.drain()

        return accumulator.getResults()
    }
}
