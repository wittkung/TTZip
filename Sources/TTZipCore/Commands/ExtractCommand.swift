// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

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
