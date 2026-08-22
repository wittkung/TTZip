// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
// TTZip

import Foundation

//
//


/// Concrete command encapsulating archive extraction with undoable directory rollback.
public final class ExtractCommand: ArchiveCommandProtocol, @unchecked Sendable {
    public let commandId: String
    public let description: String
    public var isUndoable: Bool { true }
    
    public let archivePath: String
    public let destinationDir: String
    public let password: String?
    public let autoVaultUnlock: Bool
    public let progress: (@Sendable (ArchiveProgress) -> Void)?
    
    private let engineFacade: TTZipEngineFacading
    private let lock = NSLock()
    
    private var newlyCreatedFileTree: [String] = []
    private var preExistingDirExisted: Bool = false
    private var backupDirPath: String? = nil
    private var isExecutedState: Bool = false
    
    public init(
        commandId: String = UUID().uuidString,
        description: String? = nil,
        archivePath: String,
        destinationDir: String,
        password: String? = nil,
        autoVaultUnlock: Bool = true,
        progress: (@Sendable (ArchiveProgress) -> Void)? = nil,
        engineFacade: TTZipEngineFacading = TTZipEngineFacade.shared
    ) {
        self.commandId = commandId
        self.archivePath = archivePath
        self.destinationDir = destinationDir
        self.password = password
        self.autoVaultUnlock = autoVaultUnlock
        self.progress = progress
        self.engineFacade = engineFacade
        
        let archiveName = (archivePath as NSString).lastPathComponent
        let destName = (destinationDir as NSString).lastPathComponent
        self.description = description ?? "Extract [\(archiveName)] to [\(destName)]"
    }
    
    deinit {
        purgeBackupResources()
    }
    
    public func execute() async throws -> CommandResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        let fm = FileManager.default
        
        let dirExistedBefore = fm.fileExists(atPath: destinationDir)
        let preExistingPaths = scanDirectorySet(dirPath: destinationDir)
        
        var backupMade: String? = nil
        if dirExistedBefore && !preExistingPaths.isEmpty {
            let tempBackup = "\(destinationDir).bak_\(UUID().uuidString)"
            try? fm.copyItem(atPath: destinationDir, toPath: tempBackup)
            backupMade = tempBackup
        }
        
        let extractResult = try await {
            do {
                return try await engineFacade.quickExtract(
                    archivePath: archivePath,
                    destinationDir: destinationDir,
                    password: password,
                    autoVaultUnlock: autoVaultUnlock,
                    progress: progress
                )
            } catch {
                if let bDir = backupMade, fm.fileExists(atPath: bDir) {
                    try? fm.removeItem(atPath: bDir)
                }
                throw error
            }
        }()
        
        let postExistingPaths = scanDirectorySet(dirPath: destinationDir)
        let newlyCreated = postExistingPaths.subtracting(preExistingPaths)
        
        let sortedCreated = newlyCreated.sorted {
            $0.components(separatedBy: "/").count > $1.components(separatedBy: "/").count
        }
        
        saveExecutionState(created: sortedCreated, preExisted: dirExistedBefore, backupDir: backupMade)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        var backupDict: [String: String] = [:]
        if let b = backupMade {
            backupDict[destinationDir] = b
        }
        
        return CommandResult(
            commandId: commandId,
            success: true,
            message: "Extraction completed to \(destinationDir)",
            artifactsCreated: sortedCreated,
            backupPaths: backupDict,
            executionDuration: duration,
            metadata: ["unlockedPassword": extractResult.unlockedPassword ?? ""]
        )
    }
    
    public func undo() async throws {
        let (executed, createdTree, preExisted, backupDir) = getUndoStateSnapshot()
        guard executed else {
            throw CommandError.invalidState(reason: "Extraction command has not been executed; cannot undo.")
        }
        
        let fm = FileManager.default
        
        for path in createdTree {
            if fm.fileExists(atPath: path) {
                try? fm.removeItem(atPath: path)
            }
        }
        
        var backupRestoreFailed = false
        if let backupDir = backupDir, fm.fileExists(atPath: backupDir) {
            let backupPaths = scanDirectorySet(dirPath: backupDir)
            for bPath in backupPaths {
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: bPath, isDirectory: &isDir), !isDir.boolValue {
                    let relPath = String(bPath.dropFirst(backupDir.count + 1))
                    let origPath = (destinationDir as NSString).appendingPathComponent(relPath)
                    if fm.fileExists(atPath: origPath) {
                        try? fm.removeItem(atPath: origPath)
                    }
                    let parentDir = (origPath as NSString).deletingLastPathComponent
                    try? fm.createDirectory(atPath: parentDir, withIntermediateDirectories: true)
                    if (try? fm.copyItem(atPath: bPath, toPath: origPath)) == nil {
                        backupRestoreFailed = true
                    }
                }
            }
            if !backupRestoreFailed {
                try? fm.removeItem(atPath: backupDir)
            }
        }
        
        if !preExisted && fm.fileExists(atPath: destinationDir) {
            if let contents = try? fm.contentsOfDirectory(atPath: destinationDir), contents.isEmpty {
                try? fm.removeItem(atPath: destinationDir)
            }
        }
        
        if backupRestoreFailed {
            throw CommandError.undoFailed(reason: "Failed to restore backup directory during extraction undo.")
        } else {
            resetExecutionStateOnUndoSuccess()
        }
    }
    
    public func purgeBackupResources() {
        lock.lock()
        let bDir = self.backupDirPath
        self.backupDirPath = nil
        lock.unlock()
        
        if let bDir = bDir, FileManager.default.fileExists(atPath: bDir) {
            try? FileManager.default.removeItem(atPath: bDir)
        }
    }
    
    // MARK: - Internal Synchronization Helpers
    
    private func saveExecutionState(created: [String], preExisted: Bool, backupDir: String?) {
        lock.lock()
        defer { lock.unlock() }
        self.newlyCreatedFileTree = created
        self.preExistingDirExisted = preExisted
        self.backupDirPath = backupDir
        self.isExecutedState = true
    }
    
    private func getUndoStateSnapshot() -> (executed: Bool, createdTree: [String], preExisted: Bool, backupDir: String?) {
        lock.lock()
        defer { lock.unlock() }
        return (self.isExecutedState, self.newlyCreatedFileTree, self.preExistingDirExisted, self.backupDirPath)
    }
    
    private func resetExecutionStateOnUndoSuccess() {
        lock.lock()
        defer { lock.unlock() }
        self.isExecutedState = false
        self.newlyCreatedFileTree.removeAll()
        self.backupDirPath = nil
    }
    
    private func scanDirectorySet(dirPath: String) -> Set<String> {
        let fm = FileManager.default
        guard fm.fileExists(atPath: dirPath) else { return [] }
        
        var result = Set<String>()
        if let enumerator = fm.enumerator(atPath: dirPath) {
            while let relativePath = enumerator.nextObject() as? String {
                let fullPath = (dirPath as NSString).appendingPathComponent(relativePath)
                result.insert(fullPath)
            }
        }
        return result
    }
}

// MARK: - Repair Command

//
//


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

// MARK: - Macro Command

//
//


/// Composite / macro command orchestrating a sequence of archive operations with automated reverse rollback.
public final class MacroArchiveCommand: ArchiveCommandProtocol, @unchecked Sendable {
    public let commandId: String
    public let description: String
    public var isUndoable: Bool {
        commands.allSatisfy { $0.isUndoable }
    }
    
    public let commands: [ArchiveCommandProtocol]
    private let lock = NSLock()
    
    private var executedSubCommands: [ArchiveCommandProtocol] = []
    private var isExecutedState: Bool = false
    
    public init(
        commandId: String = UUID().uuidString,
        description: String? = nil,
        commands: [ArchiveCommandProtocol]
    ) {
        self.commandId = commandId
        self.commands = commands
        self.description = description ?? "Macro command (\(commands.count) atomic steps)"
    }
    
    deinit {
        purgeBackupResources()
    }
    
    public func execute() async throws -> CommandResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        clearExecutedList()
        
        var combinedArtifacts: [String] = []
        var combinedBackups: [String: String] = [:]
        
        for (index, command) in commands.enumerated() {
            do {
                let subResult = try await command.execute()
                
                appendExecutedCommand(command)
                
                combinedArtifacts.append(contentsOf: subResult.artifactsCreated)
                for (k, v) in subResult.backupPaths {
                    combinedBackups[k] = v
                }
            } catch {
                let rollbackErrors = await performRollback()
                
                throw CommandError.macroExecutionFailed(
                    failedIndex: index,
                    underlyingError: error.localizedDescription,
                    rollbackErrors: rollbackErrors
                )
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        markAsExecuted()
        
        return CommandResult(
            commandId: commandId,
            success: true,
            message: "Macro command executed successfully (\(commands.count) sub-steps)",
            artifactsCreated: combinedArtifacts,
            backupPaths: combinedBackups,
            executionDuration: duration
        )
    }
    
    public func undo() async throws {
        let (executed, toUndo) = getUndoStateAndReset()
        guard executed || !toUndo.isEmpty else {
            throw CommandError.invalidState(reason: "Macro command has not been executed; cannot undo.")
        }
        
        var undoErrors: [String] = []
        var remainingCommands = toUndo
        
        for command in toUndo.reversed() {
            do {
                if command.isUndoable {
                    try await command.undo()
                }
                _ = remainingCommands.popLast()
            } catch {
                undoErrors.append("Undo failed for [\(command.description)]: \(error.localizedDescription)")
            }
        }
        
        if !undoErrors.isEmpty {
            restoreUnfinishedState(remainingCommands)
            throw CommandError.undoFailed(reason: undoErrors.joined(separator: "; "))
        }
    }
    
    public func purgeBackupResources() {
        for command in commands {
            command.purgeBackupResources()
        }
    }
    
    // MARK: - Rollback Helpers
    
    private func performRollback() async -> [String] {
        let toRollback = getExecutedListAndReset()
        
        var rollbackErrors: [String] = []
        for command in toRollback.reversed() {
            do {
                if command.isUndoable {
                    try await command.undo()
                }
            } catch {
                rollbackErrors.append("Rollback failed for [\(command.description)]: \(error.localizedDescription)")
            }
        }
        
        return rollbackErrors
    }
    
    // MARK: - Internal Synchronization Helpers
    
    private func clearExecutedList() {
        lock.lock()
        defer { lock.unlock() }
        executedSubCommands.removeAll()
        isExecutedState = false
    }
    
    private func appendExecutedCommand(_ command: ArchiveCommandProtocol) {
        lock.lock()
        defer { lock.unlock() }
        executedSubCommands.append(command)
    }
    
    private func markAsExecuted() {
        lock.lock()
        defer { lock.unlock() }
        isExecutedState = true
    }
    
    private func restoreUnfinishedState(_ unfinished: [ArchiveCommandProtocol]) {
        lock.lock()
        defer { lock.unlock() }
        executedSubCommands = unfinished
        isExecutedState = !unfinished.isEmpty
    }
    
    private func getExecutedListAndReset() -> [ArchiveCommandProtocol] {
        lock.lock()
        defer { lock.unlock() }
        let list = executedSubCommands
        executedSubCommands.removeAll()
        isExecutedState = false
        return list
    }
    
    private func getUndoStateAndReset() -> (executed: Bool, list: [ArchiveCommandProtocol]) {
        lock.lock()
        defer { lock.unlock() }
        let wasExecuted = isExecutedState
        let list = executedSubCommands
        isExecutedState = false
        executedSubCommands.removeAll()
        return (wasExecuted, list)
    }
}
