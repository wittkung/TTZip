// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - Archive Batch Facading Protocol

/// Batch processing facade protocol.
public protocol ArchiveBatchFacading: Sendable {
    func batchCompress(
        tasks: [BatchCompressTask],
        maxConcurrent: Int,
        progress: (@Sendable (Int, Int) -> Void)?
    ) async -> [BatchTaskResult]
    
    func batchExtract(
        tasks: [BatchExtractTask],
        maxConcurrent: Int,
        autoVaultUnlock: Bool,
        progress: (@Sendable (Int, Int) -> Void)?
    ) async -> [BatchTaskResult]
    
    func batchExecuteMacro(
        commands: [ArchiveCommandProtocol],
        description: String?
    ) async throws -> CommandResult
    
    func batchCompressTransactional(
        tasks: [BatchCompressTask]
    ) async throws -> CommandResult
    
    func batchExtractTransactional(
        tasks: [BatchExtractTask],
        autoVaultUnlock: Bool
    ) async throws -> CommandResult
}

extension ArchiveBatchFacading {
    public func batchCompress(
        tasks: [BatchCompressTask],
        maxConcurrent: Int = 4,
        progress: (@Sendable (Int, Int) -> Void)? = nil
    ) async -> [BatchTaskResult] {
        return await batchCompress(tasks: tasks, maxConcurrent: maxConcurrent, progress: progress)
    }
    
    public func batchExtract(
        tasks: [BatchExtractTask],
        maxConcurrent: Int = 4,
        autoVaultUnlock: Bool = true,
        progress: (@Sendable (Int, Int) -> Void)? = nil
    ) async -> [BatchTaskResult] {
        return await batchExtract(tasks: tasks, maxConcurrent: maxConcurrent, autoVaultUnlock: autoVaultUnlock, progress: progress)
    }
    
    public func batchExecuteMacro(
        commands: [ArchiveCommandProtocol],
        description: String? = nil
    ) async throws -> CommandResult {
        return try await batchExecuteMacro(commands: commands, description: description)
    }
    
    public func batchCompressTransactional(
        tasks: [BatchCompressTask]
    ) async throws -> CommandResult {
        return try await batchCompressTransactional(tasks: tasks)
    }
    
    public func batchExtractTransactional(
        tasks: [BatchExtractTask],
        autoVaultUnlock: Bool = true
    ) async throws -> CommandResult {
        return try await batchExtractTransactional(tasks: tasks, autoVaultUnlock: autoVaultUnlock)
    }
}

// MARK: - Archive Batch Facade Implementation

/// Unified batch operations facade orchestrating parallel TaskGroups and transactional macro commands.
public final class ArchiveBatchFacade: ArchiveBatchFacading, @unchecked Sendable {
    public static let shared = ArchiveBatchFacade()
    
    internal let engineFacade: TTZipEngineFacading
    
    private convenience init() {
        self.init(engineFacade: TTZipEngineFacade.shared)
    }
    
    internal init(engineFacade: TTZipEngineFacading = TTZipEngineFacade.shared) {
        self.engineFacade = engineFacade
    }
    
    // MARK: - Transactional Macro Batch Operations
    
    public func batchExecuteMacro(
        commands: [ArchiveCommandProtocol],
        description: String? = nil
    ) async throws -> CommandResult {
        let macro = MacroArchiveCommand(
            description: description ?? "Transactional batch task (\(commands.count) sub-steps)",
            commands: commands
        )
        return try await engineFacade.executeCommand(macro)
    }
    
    public func batchCompressTransactional(
        tasks: [BatchCompressTask]
    ) async throws -> CommandResult {
        let commands = tasks.map { task in
            CompressCommand(
                inputs: task.inputs,
                outputPath: task.outputPath,
                format: task.format,
                level: task.level,
                password: task.password,
                splitSize: task.splitSize,
                engineFacade: self.engineFacade
            )
        }
        return try await batchExecuteMacro(commands: commands, description: "Transactional batch compression (\(tasks.count) tasks)")
    }
    
    public func batchExtractTransactional(
        tasks: [BatchExtractTask],
        autoVaultUnlock: Bool = true
    ) async throws -> CommandResult {
        let commands = tasks.map { task in
            ExtractCommand(
                archivePath: task.archivePath,
                destinationDir: task.destinationDir,
                password: task.password,
                autoVaultUnlock: autoVaultUnlock,
                engineFacade: self.engineFacade
            )
        }
        return try await batchExecuteMacro(commands: commands, description: "Transactional batch extraction (\(tasks.count) tasks)")
    }
}

// MARK: - Batch Models

//
//


// MARK: - Batch Task Models

/// Batch compression task specification.
public struct BatchCompressTask: Identifiable, Sendable {
    public let id: UUID
    public let inputs: [String]
    public let outputPath: String
    public let format: ArchiveCompressionFormat
    public let level: ArchiveCompressionLevel
    public let password: String?
    public let splitSize: Int64?
    
    public init(
        id: UUID = UUID(),
        inputs: [String],
        outputPath: String,
        format: ArchiveCompressionFormat = .zip,
        level: ArchiveCompressionLevel = .normal,
        password: String? = nil,
        splitSize: Int64? = nil
    ) {
        self.id = id
        self.inputs = inputs
        self.outputPath = outputPath
        self.format = format
        self.level = level
        self.password = password
        self.splitSize = splitSize
    }
}

/// Batch extraction task specification.
public struct BatchExtractTask: Identifiable, Sendable {
    public let id: UUID
    public let archivePath: String
    public let destinationDir: String
    public let password: String?
    
    public init(
        id: UUID = UUID(),
        archivePath: String,
        destinationDir: String,
        password: String? = nil
    ) {
        self.id = id
        self.archivePath = archivePath
        self.destinationDir = destinationDir
        self.password = password
    }
}

/// Outcome payload for a batch task execution.
public struct BatchTaskResult: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let success: Bool
    public let targetPath: String
    public let durationSeconds: Double
    public let errorMessage: String?
    
    public init(
        id: UUID,
        success: Bool,
        targetPath: String,
        durationSeconds: Double,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.success = success
        self.targetPath = targetPath
        self.durationSeconds = durationSeconds
        self.errorMessage = errorMessage
    }
}

// MARK: - Parallel Processing

//
//


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
        if Task.isCancelled {
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
            let res = try await engineFacade.quickCompress(
                inputs: task.inputs,
                outputPath: task.outputPath,
                format: task.format,
                level: task.level,
                password: task.password,
                splitSize: task.splitSize,
                progress: nil
            )
            return BatchTaskResult(
                id: task.id,
                success: true,
                targetPath: res.outputPath,
                durationSeconds: res.durationSeconds,
                errorMessage: nil
            )
        } catch {
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
        if Task.isCancelled {
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
            let res = try await engineFacade.quickExtract(
                archivePath: task.archivePath,
                destinationDir: task.destinationDir,
                password: task.password,
                autoVaultUnlock: autoVaultUnlock,
                progress: nil
            )
            return BatchTaskResult(
                id: task.id,
                success: true,
                targetPath: res.destinationDir,
                durationSeconds: res.durationSeconds,
                errorMessage: nil
            )
        } catch {
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
