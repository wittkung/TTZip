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

    /// Creates work item for single compress task.
    private func createCompressWorkItem(
        task: BatchCompressTask,
        priority: TaskPriorityLevel,
        total: Int,
        progressCounter: AtomicProgressCounter,
        progress: (@Sendable (Int, Int) -> Void)?
    ) -> ArchiveWorkItem {
        let facade = self.engineFacade
        return ArchiveWorkItem(itemID: task.id.uuidString, priority: priority) {
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

    /// Creates work item for single extract task.
    private func createExtractWorkItem(
        task: BatchExtractTask,
        priority: TaskPriorityLevel,
        autoVaultUnlock: Bool,
        total: Int,
        progressCounter: AtomicProgressCounter,
        progress: (@Sendable (Int, Int) -> Void)?
    ) -> ArchiveWorkItem {
        let facade = self.engineFacade
        return ArchiveWorkItem(itemID: task.id.uuidString, priority: priority) {
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

    /// Dispatches batch compression tasks across worker pool threads.
    public func executeBatchCompress(
        tasks: [BatchCompressTask],
        priority: TaskPriorityLevel = .userInitiated,
        progress: (@Sendable (Int, Int) -> Void)? = nil
    ) async -> [BatchTaskResult] {
        guard !tasks.isEmpty else { return [] }

        let total = tasks.count
        let progressCounter = AtomicProgressCounter()

        let items = tasks.map { task in
            createCompressWorkItem(task: task, priority: priority, total: total, progressCounter: progressCounter, progress: progress)
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

        let total = tasks.count
        let progressCounter = AtomicProgressCounter()

        let items = tasks.map { task in
            createExtractWorkItem(task: task, priority: priority, autoVaultUnlock: autoVaultUnlock, total: total, progressCounter: progressCounter, progress: progress)
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
