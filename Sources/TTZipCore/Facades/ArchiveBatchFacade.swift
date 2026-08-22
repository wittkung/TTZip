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
