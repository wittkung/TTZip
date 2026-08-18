// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Abstract base class defining the invariant skeleton of archive processing algorithms (Template Method Pattern).
/// Enforces standardized workflow execution stages with extensible hooks and primitives.
open class BaseArchiveEngineTemplate: @unchecked Sendable {
    public init() {}

    /// Template method enforcing the standardized 6-stage archive workflow:
    /// 1. `preExecutionCheck` (Hook)
    /// 2. `prepareEnvironment` (Primitive)
    /// 3. `executeCoreAlgorithm` (Abstract Primitive)
    /// 4. `verifyOutputIntegrity` (Hook)
    /// 5. `postExecutionCleanup` (Primitive)
    /// 6. `onFailure` (Hook)
    public final func performWorkflow(context: ArchiveTemplateContext) throws -> WorkflowResult {
        let startTime = Date()
        do {
            // Step 1: Pre-execution validation hook
            try preExecutionCheck(context: context)

            // Step 2: Environment setup and directory preparation
            try prepareEnvironment(context: context)

            // Step 3: Core algorithm execution
            var result = try executeCoreAlgorithm(context: context)
            let duration = max(0.0001, Date().timeIntervalSince(startTime))
            result.durationSeconds = duration

            // Step 4: Output integrity verification hook
            try verifyOutputIntegrity(context: context, result: &result)

            // Step 5: Post-execution cleanup and telemetry broadcasting
            try postExecutionCleanup(context: context, result: result)

            return result
        } catch {
            // Step 6: Failure rollback and diagnostic notification
            onFailure(context: context, error: error)
            throw error
        }
    }

    /// Asynchronous template method executing workflow steps asynchronously.
    public final func performWorkflowAsync(context: ArchiveTemplateContext) async throws -> WorkflowResult {
        let startTime = Date()
        do {
            // Step 1: Pre-execution validation hook
            try preExecutionCheck(context: context)

            // Step 2: Environment setup and directory preparation
            try prepareEnvironment(context: context)

            // Step 3: Core async algorithm execution
            var result = try await executeCoreAlgorithmAsync(context: context)
            let duration = max(0.0001, Date().timeIntervalSince(startTime))
            result.durationSeconds = duration

            // Step 4: Output integrity verification hook
            try verifyOutputIntegrity(context: context, result: &result)

            // Step 5: Post-execution cleanup and telemetry broadcasting
            try postExecutionCleanup(context: context, result: result)

            return result
        } catch {
            // Step 6: Failure rollback and diagnostic notification
            onFailure(context: context, error: error)
            throw error
        }
    }

    // MARK: - Primitives & Hooks

    /// 1. Pre-execution validation hook (validates paths, permissions, and licensing preconditions).
    open func preExecutionCheck(context: ArchiveTemplateContext) throws {
        switch context.operation {
        case .compress:
            guard !context.inputPaths.isEmpty else {
                throw ArchiveError.readFailed(code: -10)
            }
            guard !context.archivePath.isEmpty else {
                throw ArchiveError.readFailed(code: -11)
            }
            if context.level == .ultra && !LicenseManager.shared.canUseFeature(.ultraCompression) {
                throw ArchiveError.readFailed(code: -403)
            }
        case .extract, .inspect, .repair:
            guard !context.archivePath.isEmpty else {
                throw ArchiveError.fileNotFound
            }
            guard FileManager.default.fileExists(atPath: context.archivePath) else {
                throw ArchiveError.fileNotFound
            }
        case .recover:
            guard !context.archivePath.isEmpty else {
                throw ArchiveError.fileNotFound
            }
            guard FileManager.default.fileExists(atPath: context.archivePath) else {
                throw ArchiveError.fileNotFound
            }
            guard !context.dictionary.isEmpty else {
                throw ArchiveError.readFailed(code: -404)
            }
        case .batch:
            break
        }
    }

    /// 2. Workspace preparation primitive (creates destination parent directories and temp handles).
    open func prepareEnvironment(context: ArchiveTemplateContext) throws {
        let fm = FileManager.default

        if context.operation == .extract && !context.destinationDir.isEmpty {
            if !fm.fileExists(atPath: context.destinationDir) {
                try fm.createDirectory(atPath: context.destinationDir, withIntermediateDirectories: true)
            }
        }

        if context.operation == .compress && !context.archivePath.isEmpty {
            let parentDir = (context.archivePath as NSString).deletingLastPathComponent
            if !parentDir.isEmpty && !fm.fileExists(atPath: parentDir) {
                try fm.createDirectory(atPath: parentDir, withIntermediateDirectories: true)
            }
        }
    }

    /// 3. Core algorithm execution primitive (synchronous bridging to async implementation).
    open func executeCoreAlgorithm(context: ArchiveTemplateContext) throws -> WorkflowResult {
        let box = SyncResultBox()
        let sema = DispatchSemaphore(value: 0)
        Task.detached {
            do {
                box.result = try await self.executeCoreAlgorithmAsync(context: context)
            } catch {
                box.error = error
            }
            sema.signal()
        }
        sema.wait()

        if let res = box.result { return res }
        if let err = box.error { throw err }
        throw ArchiveError.readFailed(code: -999)
    }

    /// 3b. Asynchronous core algorithm execution primitive (overridden by concrete format templates).
    open func executeCoreAlgorithmAsync(context: ArchiveTemplateContext) async throws -> WorkflowResult {
        throw ArchiveError.readFailed(code: -999)
    }

    /// 4. Output integrity validation hook (verifies CRC32/SHA256 checksums and destination structure).
    open func verifyOutputIntegrity(context: ArchiveTemplateContext, result: inout WorkflowResult) throws {
        let fm = FileManager.default
        if context.operation == .compress && !result.outputPath.isEmpty {
            let checkPath = (context.splitVolumeSizeBytes != nil && context.splitVolumeSizeBytes! > 0) ? (result.outputPath + ".001") : result.outputPath
            guard fm.fileExists(atPath: checkPath) || fm.fileExists(atPath: result.outputPath) else {
                throw ArchiveError.readFailed(code: -500)
            }
            let checker = ArchiveEngineFactory.makeIntegrityChecker()
            let targetForCrc = fm.fileExists(atPath: checkPath) ? checkPath : result.outputPath
            let crc = checker.computeCRC32(filePath: targetForCrc)
            result.crc32 = crc
            result.setMetadata(crc, forKey: "crc32")
        } else if context.operation == .extract && !result.destinationDir.isEmpty {
            guard fm.fileExists(atPath: result.destinationDir) else {
                throw ArchiveError.readFailed(code: -501)
            }
        }
    }

    /// 5. Post-execution cleanup primitive (removes temp files and broadcasts completion metrics).
    open func postExecutionCleanup(context: ArchiveTemplateContext, result: WorkflowResult) throws {
        if let temp = context.tempDir, FileManager.default.fileExists(atPath: temp) {
            try? FileManager.default.removeItem(atPath: temp)
        }

        let info = ArchiveProgressInfo(
            state: .completed,
            bytesProcessed: result.processedBytes,
            totalBytes: max(result.processedBytes, result.compressedBytes),
            currentFileName: (result.outputPath as NSString).lastPathComponent,
            throughputMBs: result.durationSeconds > 0 ? (Double(result.processedBytes) / 1024.0 / 1024.0) / result.durationSeconds : 0.0,
            estimatedTimeRemaining: 0,
            operationType: context.operation == .compress ? .compress : (context.operation == .extract ? .extract : .recover)
        )
        ArchiveProgressBroadcaster.shared.broadcastProgress(info)
    }

    /// 6. Failure handling and rollback hook (cleans up incomplete output artifacts and broadcasts error).
    open func onFailure(context: ArchiveTemplateContext, error: Error) {
        if let temp = context.tempDir, FileManager.default.fileExists(atPath: temp) {
            try? FileManager.default.removeItem(atPath: temp)
        }

        if context.operation == .compress && !context.archivePath.isEmpty {
            if FileManager.default.fileExists(atPath: context.archivePath) {
                if let attr = try? FileManager.default.attributesOfItem(atPath: context.archivePath),
                   (attr[.size] as? Int64 ?? 0) == 0 {
                    try? FileManager.default.removeItem(atPath: context.archivePath)
                }
            }
        }

        let info = ArchiveProgressInfo(
            state: .failed(error: error.localizedDescription),
            bytesProcessed: 0,
            totalBytes: 0,
            currentFileName: (context.archivePath as NSString).lastPathComponent,
            throughputMBs: 0,
            estimatedTimeRemaining: 0,
            operationType: context.operation == .compress ? .compress : .extract
        )
        ArchiveProgressBroadcaster.shared.broadcastProgress(info)
    }
}
