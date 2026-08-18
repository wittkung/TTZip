// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Concrete command encapsulating archive scanning and recovery with transactional rollback.
public final class RepairCommand: ArchiveCommandProtocol, @unchecked Sendable {
    public let commandId: String
    public let description: String
    public var isUndoable: Bool { true }
    
    public let damagedPath: String
    public let outputPath: String
    private let engineFacade: TTZipEngineFacading
    private let lock = NSLock()
    
    private var createdArtifacts: [String] = []
    private var backupFilePath: String? = nil
    private var isExecutedState: Bool = false
    
    public init(
        commandId: String = UUID().uuidString,
        description: String? = nil,
        damagedPath: String,
        outputPath: String,
        engineFacade: TTZipEngineFacading = TTZipEngineFacade.shared
    ) {
        self.commandId = commandId
        self.damagedPath = damagedPath
        self.outputPath = outputPath
        self.engineFacade = engineFacade
        
        let file = (damagedPath as NSString).lastPathComponent
        self.description = description ?? "Repair damaged archive [\(file)]"
    }
    
    deinit {
        purgeBackupResources()
    }
    
    public func execute() async throws -> CommandResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        let fm = FileManager.default
        
        let backupPathCandidate = "\(outputPath).bak_\(UUID().uuidString)"
        var backupMade: String? = nil
        if fm.fileExists(atPath: outputPath) {
            try? fm.copyItem(atPath: outputPath, toPath: backupPathCandidate)
            backupMade = backupPathCandidate
        }
        
        let recoveredCount: Int
        do {
            recoveredCount = try await engineFacade.repairArchive(damagedPath: damagedPath, outputPath: outputPath)
        } catch {
            if let b = backupMade, fm.fileExists(atPath: b) {
                try? fm.removeItem(atPath: b)
            }
            throw error
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        var artifacts: [String] = []
        if fm.fileExists(atPath: outputPath) {
            artifacts.append(outputPath)
        }
        
        saveExecutionState(artifacts: artifacts, backupPath: backupMade)
        
        var backupDict: [String: String] = [:]
        if let b = backupMade {
            backupDict[outputPath] = b
        }
        
        return CommandResult(
            commandId: commandId,
            success: true,
            message: "Archive repaired successfully, recovered \(recoveredCount) data blocks",
            artifactsCreated: artifacts,
            backupPaths: backupDict,
            executionDuration: duration,
            metadata: ["recoveredCount": "\(recoveredCount)"]
        )
    }
    
    public func undo() async throws {
        let (executed, artifacts, backup) = getUndoStateSnapshot()
        guard executed else {
            throw CommandError.invalidState(reason: "Repair command has not been executed; cannot undo.")
        }
        
        let fm = FileManager.default
        
        for path in artifacts {
            if fm.fileExists(atPath: path) {
                try? fm.removeItem(atPath: path)
            }
        }
        
        if let backup = backup, fm.fileExists(atPath: backup) {
            if fm.fileExists(atPath: outputPath) {
                try? fm.removeItem(atPath: outputPath)
            }
            do {
                try fm.moveItem(atPath: backup, toPath: outputPath)
            } catch {
                throw CommandError.undoFailed(reason: "Failed to restore original backup during repair undo: \(error.localizedDescription)")
            }
        }
        
        resetExecutionStateOnUndoSuccess()
    }
    
    public func purgeBackupResources() {
        lock.lock()
        let b = self.backupFilePath
        self.backupFilePath = nil
        lock.unlock()
        
        if let b = b, FileManager.default.fileExists(atPath: b) {
            try? FileManager.default.removeItem(atPath: b)
        }
    }
    
    // MARK: - Internal Synchronization Helpers
    
    private func saveExecutionState(artifacts: [String], backupPath: String?) {
        lock.lock()
        defer { lock.unlock() }
        self.createdArtifacts = artifacts
        self.backupFilePath = backupPath
        self.isExecutedState = true
    }
    
    private func getUndoStateSnapshot() -> (executed: Bool, artifacts: [String], backup: String?) {
        lock.lock()
        defer { lock.unlock() }
        return (self.isExecutedState, self.createdArtifacts, self.backupFilePath)
    }
    
    private func resetExecutionStateOnUndoSuccess() {
        lock.lock()
        defer { lock.unlock() }
        self.isExecutedState = false
        self.createdArtifacts.removeAll()
        self.backupFilePath = nil
    }
}
