// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - Parallel Batch Compression & Extraction

extension ArchiveBatchFacade {
    
    // MARK: - Batch Parallel Compression
    
    public func batchCompress(
        tasks: [BatchCompressTask],
        maxConcurrent: Int = 4,
        progress: (@Sendable (Int, Int) -> Void)? = nil
    ) async -> [BatchTaskResult] {
        guard !tasks.isEmpty else { return [] }
        
        let total = tasks.count
        let concurrency = max(1, min(maxConcurrent, 16))
        
        return await withTaskGroup(of: BatchTaskResult.self) { group in
            var results: [BatchTaskResult] = []
            var submitted = 0
            var completed = 0
            
            for _ in 0..<min(concurrency, total) {
                if Task.isCancelled { break }
                let task = tasks[submitted]
                submitted += 1
                group.addTask {
                    await self.executeSingleCompressTask(task)
                }
            }
            
            for await res in group {
                results.append(res)
                completed += 1
                progress?(completed, total)
                ArchiveProgressBroadcaster.shared.broadcastBatchProgress(BatchProgressInfo(
                    completedTasks: completed,
                    totalTasks: total,
                    currentTaskPath: res.targetPath,
                    totalBytesProcessed: Int64(completed),
                    totalBytesCount: Int64(total),
                    throughputMBs: 0.0,
                    estimatedTimeRemaining: nil
                ))
                
                if Task.isCancelled {
                    group.cancelAll()
                    break
                }
                
                if submitted < total {
                    let nextTask = tasks[submitted]
                    submitted += 1
                    group.addTask {
                        await self.executeSingleCompressTask(nextTask)
                    }
                }
            }
            
            return results
        }
    }
    
    internal func executeSingleCompressTask(_ task: BatchCompressTask) async -> BatchTaskResult {
        let sm = registerStateMachine(id: task.id, taskName: "BatchCompress:\(task.outputPath)")
        if Task.isCancelled {
            try? sm.cancel()
            return BatchTaskResult(
                id: task.id,
                success: false,
                targetPath: task.outputPath,
                durationSeconds: 0,
                errorMessage: "Task cancelled"
            )
        }
        let start = Date()
        do {
            try sm.start()
            let res = try await engineFacade.quickCompress(
                inputs: task.inputs,
                outputPath: task.outputPath,
                format: task.format,
                level: task.level,
                password: task.password,
                splitSize: task.splitSize,
                progress: nil
            )
            try sm.complete()
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
            return BatchTaskResult(
                id: task.id,
                success: false,
                targetPath: task.outputPath,
                durationSeconds: elapsed,
                errorMessage: error.localizedDescription
            )
        }
    }
    
    // MARK: - Batch Parallel Extraction
    
    public func batchExtract(
        tasks: [BatchExtractTask],
        maxConcurrent: Int = 4,
        autoVaultUnlock: Bool = true,
        progress: (@Sendable (Int, Int) -> Void)? = nil
    ) async -> [BatchTaskResult] {
        guard !tasks.isEmpty else { return [] }
        
        let total = tasks.count
        let concurrency = max(1, min(maxConcurrent, 16))
        
        return await withTaskGroup(of: BatchTaskResult.self) { group in
            var results: [BatchTaskResult] = []
            var submitted = 0
            var completed = 0
            
            for _ in 0..<min(concurrency, total) {
                if Task.isCancelled { break }
                let task = tasks[submitted]
                submitted += 1
                group.addTask {
                    await self.executeSingleExtractTask(task, autoVaultUnlock: autoVaultUnlock)
                }
            }
            
            for await res in group {
                results.append(res)
                completed += 1
                progress?(completed, total)
                ArchiveProgressBroadcaster.shared.broadcastBatchProgress(BatchProgressInfo(
                    completedTasks: completed,
                    totalTasks: total,
                    currentTaskPath: res.targetPath,
                    totalBytesProcessed: Int64(completed),
                    totalBytesCount: Int64(total),
                    throughputMBs: 0.0,
                    estimatedTimeRemaining: nil
                ))
                
                if Task.isCancelled {
                    group.cancelAll()
                    break
                }
                
                if submitted < total {
                    let nextTask = tasks[submitted]
                    submitted += 1
                    group.addTask {
                        await self.executeSingleExtractTask(nextTask, autoVaultUnlock: autoVaultUnlock)
                    }
                }
            }
            
            return results
        }
    }
    
    internal func executeSingleExtractTask(_ task: BatchExtractTask, autoVaultUnlock: Bool) async -> BatchTaskResult {
        let sm = registerStateMachine(id: task.id, taskName: "BatchExtract:\(task.archivePath)")
        if Task.isCancelled {
            try? sm.cancel()
            return BatchTaskResult(
                id: task.id,
                success: false,
                targetPath: task.destinationDir,
                durationSeconds: 0,
                errorMessage: "Task cancelled"
            )
        }
        let start = Date()
        do {
            try sm.start()
            let res = try await engineFacade.quickExtract(
                archivePath: task.archivePath,
                destinationDir: task.destinationDir,
                password: task.password,
                autoVaultUnlock: autoVaultUnlock,
                progress: nil
            )
            try sm.complete()
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
