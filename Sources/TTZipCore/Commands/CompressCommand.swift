// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Concrete command encapsulating archive compression with transactional rollback support.
public final class CompressCommand: ArchiveCommandProtocol, @unchecked Sendable {
    public let commandId: String
    public let description: String
    public var isUndoable: Bool { true }
    
    public let inputs: [String]
    public let outputPath: String
    public let format: ArchiveCompressionFormat
    public let level: ArchiveCompressionLevel
    public let password: String?
    public let splitSize: Int64?
    public let filterOptions: ArchiveFilterOptions
    public let advancedOptions: ArchiveAdvancedOptions?
    public let progress: (@Sendable (ArchiveProgress) -> Void)?
    
    private let engineFacade: TTZipEngineFacading
    private let lock = NSLock()
    
    private var createdArtifacts: [String] = []
    private var backupFileMap: [String: String] = [:]
    private var isExecutedState: Bool = false
    
    public init(
        commandId: String = UUID().uuidString,
        description: String? = nil,
        inputs: [String],
        outputPath: String,
        format: ArchiveCompressionFormat = .zip,
        level: ArchiveCompressionLevel = .normal,
        password: String? = nil,
        splitSize: Int64? = nil,
        filterOptions: ArchiveFilterOptions = ArchiveFilterOptions(),
        advancedOptions: ArchiveAdvancedOptions? = nil,
        progress: (@Sendable (ArchiveProgress) -> Void)? = nil,
        engineFacade: TTZipEngineFacading = TTZipEngineFacade.shared
    ) {
        self.commandId = commandId
        self.inputs = inputs
        self.outputPath = outputPath
        self.format = format
        self.level = level
        self.password = password
        self.splitSize = splitSize
        self.filterOptions = filterOptions
        self.advancedOptions = advancedOptions
        self.progress = progress
        self.engineFacade = engineFacade
        
        let targetName = (outputPath as NSString).lastPathComponent
        self.description = description ?? "Compress files to [\(targetName)] (\(format.rawValue.uppercased()))"
    }
    
    deinit {
        purgeBackupResources()
    }
    
    public func execute() async throws -> CommandResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        let fm = FileManager.default
        
        let outputDir = (outputPath as NSString).deletingLastPathComponent
        let baseName = (outputPath as NSString).lastPathComponent
        let baseStem = (baseName as NSString).deletingPathExtension
        
        let preExistingInOutputDir = scanDirectorySet(dirPath: outputDir)
        
        var backupDict: [String: String] = [:]
        if fm.fileExists(atPath: outputDir) {
            if let dirContents = try? fm.contentsOfDirectory(atPath: outputDir) {
                for item in dirContents {
                    let fullPath = (outputDir as NSString).appendingPathComponent(item)
                    if item == baseName || isSplitVolumeMatch(fileName: item, baseName: baseName, baseStem: baseStem) {
                        let backupPathCandidate = "\(fullPath).bak_\(UUID().uuidString)"
                        try? fm.copyItem(atPath: fullPath, toPath: backupPathCandidate)
                        backupDict[fullPath] = backupPathCandidate
                    }
                }
            }
        }
        
        let result = try await {
            do {
                return try await engineFacade.quickCompress(
                    inputs: inputs,
                    outputPath: outputPath,
                    format: format,
                    level: level,
                    password: password,
                    splitSize: splitSize,
                    filterOptions: filterOptions,
                    advancedOptions: advancedOptions,
                    progress: progress
                )
            } catch {
                for (_, backupPath) in backupDict {
                    if fm.fileExists(atPath: backupPath) {
                        try? fm.removeItem(atPath: backupPath)
                    }
                }
                throw error
            }
        }()
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        let postExistingInOutputDir = scanDirectorySet(dirPath: outputDir)
        let newlyCreated = postExistingInOutputDir.subtracting(preExistingInOutputDir)
        
        var artifactsSet = Set<String>()
        if fm.fileExists(atPath: outputPath) {
            artifactsSet.insert(outputPath)
        }
        for path in newlyCreated {
            if !path.contains(".bak_") {
                artifactsSet.insert(path)
            }
        }
        if let dirContents = try? fm.contentsOfDirectory(atPath: outputDir) {
            for item in dirContents {
                if !item.contains(".bak_") && isSplitVolumeMatch(fileName: item, baseName: baseName, baseStem: baseStem) {
                    let fullPath = (outputDir as NSString).appendingPathComponent(item)
                    artifactsSet.insert(fullPath)
                }
            }
        }
        
        let sortedArtifacts = Array(artifactsSet)
        saveExecutionState(artifacts: sortedArtifacts, backupMap: backupDict)
        
        return CommandResult(
            commandId: commandId,
            success: true,
            message: "Archive compression completed in \(String(format: "%.2f", duration))s",
            artifactsCreated: sortedArtifacts,
            backupPaths: backupDict,
            executionDuration: duration,
            metadata: ["compressedSize": "\(result.compressedBytes)", "originalSize": "\(result.originalBytes)"]
        )
    }
    
    public func undo() async throws {
        let (executed, artifacts, backups) = getUndoStateSnapshot()
        guard executed else {
            throw CommandError.invalidState(reason: "Command has not been executed yet; cannot undo.")
        }
        
        let fm = FileManager.default
        let outputDir = (outputPath as NSString).deletingLastPathComponent
        let baseName = (outputPath as NSString).lastPathComponent
        let baseStem = (baseName as NSString).deletingPathExtension
        
        for path in artifacts {
            if fm.fileExists(atPath: path) {
                try? fm.removeItem(atPath: path)
            }
        }
        
        if fm.fileExists(atPath: outputDir), let dirContents = try? fm.contentsOfDirectory(atPath: outputDir) {
            for item in dirContents {
                if !item.contains(".bak_") {
                    let fullPath = (outputDir as NSString).appendingPathComponent(item)
                    if backups[fullPath] == nil && isSplitVolumeMatch(fileName: item, baseName: baseName, baseStem: baseStem) {
                        try? fm.removeItem(atPath: fullPath)
                    }
                }
            }
        }
        
        var unRestoredBackups: [String: String] = [:]
        for (origPath, backupPath) in backups {
            if fm.fileExists(atPath: backupPath) {
                if fm.fileExists(atPath: origPath) {
                    try? fm.removeItem(atPath: origPath)
                }
                do {
                    try fm.moveItem(atPath: backupPath, toPath: origPath)
                } catch {
                    unRestoredBackups[origPath] = backupPath
                }
            }
        }
        
        if !unRestoredBackups.isEmpty {
            saveExecutionState(artifacts: [], backupMap: unRestoredBackups)
            throw CommandError.undoFailed(reason: "Failed to restore all backup files during undo.")
        } else {
            resetExecutionStateOnUndoSuccess()
        }
    }
    
    public func purgeBackupResources() {
        lock.lock()
        defer { lock.unlock() }
        let fm = FileManager.default
        for (_, backupPath) in backupFileMap {
            try? fm.removeItem(atPath: backupPath)
        }
        backupFileMap.removeAll()
    }
    
    // MARK: - Internal Synchronization Helpers
    
    private func saveExecutionState(artifacts: [String], backupMap: [String: String]) {
        lock.lock()
        defer { lock.unlock() }
        self.createdArtifacts = artifacts
        self.backupFileMap = backupMap
        self.isExecutedState = true
    }
    
    private func getUndoStateSnapshot() -> (executed: Bool, artifacts: [String], backups: [String: String]) {
        lock.lock()
        defer { lock.unlock() }
        return (self.isExecutedState, self.createdArtifacts, self.backupFileMap)
    }
    
    private func resetExecutionStateOnUndoSuccess() {
        lock.lock()
        defer { lock.unlock() }
        self.isExecutedState = false
        self.createdArtifacts.removeAll()
        self.backupFileMap.removeAll()
    }
    
    private func isSplitVolumeMatch(fileName: String, baseName: String, baseStem: String) -> Bool {
        if fileName.hasPrefix(baseName + ".") { return true }
        if fileName.hasPrefix(baseStem + ".") {
            let ext = (fileName as NSString).pathExtension.lowercased()
            if ext.hasPrefix("z") && ext.dropFirst().allSatisfy({ $0.isNumber }) { return true }
            if ext.allSatisfy({ $0.isNumber }) && !ext.isEmpty { return true }
            if ext.hasPrefix("part") { return true }
        }
        return false
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

// MARK: - Fluent Builder for CompressCommand

/// Fluent builder constructing `CompressCommand` instances.
public struct CompressCommandBuilder: Sendable {
    public var commandId: String = UUID().uuidString
    public var description: String? = nil
    public var inputs: [String] = []
    public var outputPath: String = ""
    public var format: ArchiveCompressionFormat = .zip
    public var level: ArchiveCompressionLevel = .normal
    public var password: String? = nil
    public var splitSize: Int64? = nil
    public var filterOptions: ArchiveFilterOptions = ArchiveFilterOptions()
    public var advancedOptions: ArchiveAdvancedOptions? = nil
    public var progress: (@Sendable (ArchiveProgress) -> Void)? = nil
    public var engineFacade: TTZipEngineFacading = TTZipEngineFacade.shared

    public init() {}

    public func withInputs(_ inputs: [String]) -> CompressCommandBuilder {
        var copy = self
        copy.inputs = inputs
        return copy
    }

    public func withOutputPath(_ path: String) -> CompressCommandBuilder {
        var copy = self
        copy.outputPath = path
        return copy
    }

    public func withFormat(_ format: ArchiveCompressionFormat) -> CompressCommandBuilder {
        var copy = self
        copy.format = format
        return copy
    }

    public func withLevel(_ level: ArchiveCompressionLevel) -> CompressCommandBuilder {
        var copy = self
        copy.level = level
        return copy
    }

    public func withPassword(_ pwd: String?) -> CompressCommandBuilder {
        var copy = self
        copy.password = pwd
        return copy
    }

    public func withSplitSize(_ size: Int64?) -> CompressCommandBuilder {
        var copy = self
        copy.splitSize = size
        return copy
    }

    public func withFilterOptions(_ options: ArchiveFilterOptions) -> CompressCommandBuilder {
        var copy = self
        copy.filterOptions = options
        return copy
    }

    public func withAdvancedOptions(_ options: ArchiveAdvancedOptions?) -> CompressCommandBuilder {
        var copy = self
        copy.advancedOptions = options
        return copy
    }

    public func withProgress(_ progress: (@Sendable (ArchiveProgress) -> Void)?) -> CompressCommandBuilder {
        var copy = self
        copy.progress = progress
        return copy
    }

    public func build() -> CompressCommand {
        return CompressCommand(
            commandId: commandId,
            description: description,
            inputs: inputs,
            outputPath: outputPath,
            format: format,
            level: level,
            password: password,
            splitSize: splitSize,
            filterOptions: filterOptions,
            advancedOptions: advancedOptions,
            progress: progress,
            engineFacade: engineFacade
        )
    }
}

public extension CompressCommand {
    static func builder() -> CompressCommandBuilder {
        return CompressCommandBuilder()
    }
}
