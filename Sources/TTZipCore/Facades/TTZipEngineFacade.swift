// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-level result payload for archive extraction operations.
public struct ExtractResult: Sendable, Equatable {
    public let archivePath: String
    public let destinationDir: String
    public let durationSeconds: Double
    public let unlockedPassword: String?
    public let isVaultUnlocked: Bool
    
    public init(
        archivePath: String,
        destinationDir: String,
        durationSeconds: Double,
        unlockedPassword: String? = nil,
        isVaultUnlocked: Bool = false
    ) {
        self.archivePath = archivePath
        self.destinationDir = destinationDir
        self.durationSeconds = durationSeconds
        self.unlockedPassword = unlockedPassword
        self.isVaultUnlocked = isVaultUnlocked
    }
}

/// High-level result payload for archive inspection and structural analysis.
public struct ArchiveInspectionResult: Sendable {
    public let archivePath: String
    public let entries: [ArchiveEntry]
    public let treeNode: ArchiveCompositeDirectory
    public let securityReport: SecurityReport
    public let unlockedPassword: String?
    
    public init(
        archivePath: String,
        entries: [ArchiveEntry],
        treeNode: ArchiveCompositeDirectory,
        securityReport: SecurityReport,
        unlockedPassword: String? = nil
    ) {
        self.archivePath = archivePath
        self.entries = entries
        self.treeNode = treeNode
        self.securityReport = securityReport
        self.unlockedPassword = unlockedPassword
    }
}

/// Cryptographic hash verification result payload.
public struct HashVerificationResult: Sendable, Equatable {
    public let filePath: String
    public let crc32: String
    public let sha256: String
    
    public init(filePath: String, crc32: String, sha256: String) {
        self.filePath = filePath
        self.crc32 = crc32
        self.sha256 = sha256
    }
}

/// Unified high-level engine facade protocol.
public protocol TTZipEngineFacading: Sendable {
    func quickCompress(
        inputs: [String],
        outputPath: String,
        format: ArchiveCompressionFormat,
        level: ArchiveCompressionLevel,
        password: String?,
        splitSize: Int64?,
        filterOptions: ArchiveFilterOptions,
        advancedOptions: ArchiveAdvancedOptions?,
        progress: (@Sendable (ArchiveProgress) -> Void)?
    ) async throws -> ArchiveOperationResult
    
    func quickExtract(
        archivePath: String,
        destinationDir: String,
        password: String?,
        autoVaultUnlock: Bool,
        progress: (@Sendable (ArchiveProgress) -> Void)?
    ) async throws -> ExtractResult
    
    func extractSingleEntry(
        archivePath: String,
        entryPath: String,
        destinationDir: String,
        password: String?
    ) async throws
    
    func inspectArchive(
        archivePath: String,
        password: String?,
        autoVaultUnlock: Bool
    ) async throws -> ArchiveInspectionResult
    
    func verifyIntegrity(archivePath: String) async throws -> HashVerificationResult
    func repairArchive(damagedPath: String, outputPath: String) async throws -> Int
    func recoverPassword(archivePath: String, dictionary: [String]) async throws -> PasswordRecoveryResult
    
    // MARK: - Command Pattern: Execution and Undo/Redo Control
    var historyManager: CommandHistoryManager { get }
    var canUndoCommand: Bool { get }
    var canRedoCommand: Bool { get }
    func executeCommand(_ command: ArchiveCommandProtocol) async throws -> CommandResult
    func undoCommand() async throws -> CommandResult?
    func redoCommand() async throws -> CommandResult?
    func undoLastCommand() async throws -> CommandResult?
    func redoLastCommand() async throws -> CommandResult?
    
    // MARK: - Bridge Pattern & Decorator Pattern Integration
    func operationAbstraction(for format: ArchiveCompressionFormat) -> ArchiveOperationAbstraction
    func decoratedImplementor(for format: ArchiveCompressionFormat, password: String?, splitSize: Int64?, progressHandler: (@Sendable (ArchiveProgress) -> Void)?, enableChecksum: Bool, enableMetrics: Bool) -> ArchiveEngineImplementorProtocol
}

extension TTZipEngineFacading {
    public func quickCompress(
        inputs: [String],
        outputPath: String,
        format: ArchiveCompressionFormat = .zip,
        level: ArchiveCompressionLevel = .normal,
        password: String? = nil,
        splitSize: Int64? = nil,
        progress: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) async throws -> ArchiveOperationResult {
        return try await quickCompress(
            inputs: inputs,
            outputPath: outputPath,
            format: format,
            level: level,
            password: password,
            splitSize: splitSize,
            filterOptions: .defaultClean,
            advancedOptions: nil,
            progress: progress
        )
    }
    
    public func quickExtract(
        archivePath: String,
        destinationDir: String,
        password: String? = nil,
        autoVaultUnlock: Bool = true,
        progress: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) async throws -> ExtractResult {
        return try await quickExtract(
            archivePath: archivePath,
            destinationDir: destinationDir,
            password: password,
            autoVaultUnlock: autoVaultUnlock,
            progress: progress
        )
    }
    
    public func extractSingleEntry(
        archivePath: String,
        entryPath: String,
        destinationDir: String,
        password: String? = nil
    ) async throws {
        try await extractSingleEntry(
            archivePath: archivePath,
            entryPath: entryPath,
            destinationDir: destinationDir,
            password: password
        )
    }
    
    public func inspectArchive(
        archivePath: String,
        password: String? = nil,
        autoVaultUnlock: Bool = true
    ) async throws -> ArchiveInspectionResult {
        return try await inspectArchive(
            archivePath: archivePath,
            password: password,
            autoVaultUnlock: autoVaultUnlock
        )
    }
    
    public var historyManager: CommandHistoryManager {
        return CommandHistoryManager.shared
    }
    
    /// Initializes native microkernel subsystems (structured Rust logging bridge, etc.).
    public static func initializeSubsystems() {
        ttzip_rust_set_logger({ level, target, message, file, line, _ in
            guard let msg = message else { return }
            let str = String(cString: msg)
            let tag = target != nil ? String(cString: target!) : "Rust"
            switch level {
            case TTZIP_LOG_LEVEL_ERROR: TTLogger.error("[\(tag)] \(str)")
            case TTZIP_LOG_LEVEL_WARNING: TTLogger.warning("[\(tag)] \(str)")
            case TTZIP_LOG_LEVEL_INFO: TTLogger.info("[\(tag)] \(str)")
            default: TTLogger.debug("[\(tag)] \(str)")
            }
        }, TTZIP_LOG_LEVEL_DEBUG, nil)
    }
    
    public var canUndoCommand: Bool {
        return historyManager.canUndo
    }
    
    public var canRedoCommand: Bool {
        return historyManager.canRedo
    }
    
    public func executeCommand(_ command: ArchiveCommandProtocol) async throws -> CommandResult {
        return try await historyManager.execute(command: command)
    }
    
    public func undoCommand() async throws -> CommandResult? {
        return try await historyManager.undo()
    }
    
    public func redoCommand() async throws -> CommandResult? {
        return try await historyManager.redo()
    }
    
    public func undoLastCommand() async throws -> CommandResult? {
        return try await undoCommand()
    }
    
    public func redoLastCommand() async throws -> CommandResult? {
        return try await redoCommand()
    }
    
    public func recoverPassword(archivePath: String, dictionary: [String]) async throws -> PasswordRecoveryResult {
        let engine = PasswordRecoveryEngine()
        return try await engine.recoverPassword(archivePath: archivePath, dictionary: dictionary)
    }

    public func operationAbstraction(for format: ArchiveCompressionFormat = .zip) -> ArchiveOperationAbstraction {
        return ArchiveEngineFactory.makeOperationAbstraction(for: format)
    }

    public func decoratedImplementor(
        for format: ArchiveCompressionFormat = .zip,
        password: String? = nil,
        splitSize: Int64? = nil,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil,
        enableChecksum: Bool = true,
        enableMetrics: Bool = true
    ) -> ArchiveEngineImplementorProtocol {
        return ArchiveEngineFactory.makeDecoratedImplementor(
            for: format,
            password: password,
            splitVolumeSizeBytes: splitSize,
            progressHandler: progressHandler,
            enableChecksum: enableChecksum,
            enableMetrics: enableMetrics
        )
    }
}


// MARK: - Engine Facade Main

//
//


/// Facade Pattern: Unified primary archive orchestration facade center (`TTZipEngineFacade`).
/// Provides streamlined high-level APIs for compression, extraction, password vault, integrity verification,
/// preview generation, security scanning, split-volume management, and archive self-healing repair.
public final class TTZipEngineFacade: TTZipEngineFacading, @unchecked Sendable {
    public static let shared = TTZipEngineFacade()
    
    public let historyManager: CommandHistoryManager
    internal let pipelineBuilderProvider: @Sendable () -> ArchivePipelineBuilder
    internal let reader: ArchiveReading
    internal let securityScanner: SecurityScanner
    internal let passwordVault: PasswordVaultManaging
    internal let integrityChecker: ArchiveIntegrityChecking
    internal let repairEngine: ArchiveRepairEngine
    internal let recoveryEngine: PasswordRecoveryEngine
    internal let splitEngine: NativeParallelEncryptedSplitEngine
    
    private convenience init() {
        self.init(
            historyManager: CommandHistoryManager.shared,
            pipelineBuilderProvider: { ArchivePipelineBuilder() },
            reader: ArchiveEngineFactory.makeReader(),
            securityScanner: SecurityScanner.shared,
            passwordVault: PasswordVaultManager.shared,
            integrityChecker: ArchiveEngineFactory.makeIntegrityChecker(),
            repairEngine: ArchiveRepairEngine(),
            recoveryEngine: PasswordRecoveryEngine(),
            splitEngine: NativeParallelEncryptedSplitEngine()
        )
    }
    
    internal init(
        historyManager: CommandHistoryManager = CommandHistoryManager.shared,
        pipelineBuilderProvider: @Sendable @escaping () -> ArchivePipelineBuilder = { ArchivePipelineBuilder() },
        reader: ArchiveReading = ArchiveEngineFactory.makeReader(),
        securityScanner: SecurityScanner = SecurityScanner.shared,
        passwordVault: PasswordVaultManaging = PasswordVaultManager.shared,
        integrityChecker: ArchiveIntegrityChecking = ArchiveEngineFactory.makeIntegrityChecker(),
        repairEngine: ArchiveRepairEngine = ArchiveRepairEngine(),
        recoveryEngine: PasswordRecoveryEngine = PasswordRecoveryEngine(),
        splitEngine: NativeParallelEncryptedSplitEngine = NativeParallelEncryptedSplitEngine()
    ) {
        self.historyManager = historyManager
        self.pipelineBuilderProvider = pipelineBuilderProvider
        self.reader = reader
        self.securityScanner = securityScanner
        self.passwordVault = passwordVault
        self.integrityChecker = integrityChecker
        self.repairEngine = repairEngine
        self.recoveryEngine = recoveryEngine
        self.splitEngine = splitEngine
    }
    
    // MARK: - Command Pattern Convenience Wrappers
    
    public func compressWithCommand(
        inputs: [String],
        outputPath: String,
        format: ArchiveCompressionFormat = .zip,
        level: ArchiveCompressionLevel = .normal,
        password: String? = nil,
        splitSize: Int64? = nil,
        filterOptions: ArchiveFilterOptions = ArchiveFilterOptions(),
        advancedOptions: ArchiveAdvancedOptions? = nil,
        progress: (@Sendable (ArchiveProgress) -> Void)? = nil,
        engineFacade: TTZipEngineFacading? = nil
    ) async throws -> CommandResult {
        let command = CompressCommand(
            inputs: inputs,
            outputPath: outputPath,
            format: format,
            level: level,
            password: password,
            splitSize: splitSize,
            filterOptions: filterOptions,
            advancedOptions: advancedOptions,
            progress: progress,
            engineFacade: engineFacade ?? self
        )
        return try await executeCommand(command)
    }
    
    public func extractWithCommand(
        archivePath: String,
        destinationDir: String,
        password: String? = nil,
        autoVaultUnlock: Bool = true,
        progress: (@Sendable (ArchiveProgress) -> Void)? = nil,
        engineFacade: TTZipEngineFacading? = nil
    ) async throws -> CommandResult {
        let command = ExtractCommand(
            archivePath: archivePath,
            destinationDir: destinationDir,
            password: password,
            autoVaultUnlock: autoVaultUnlock,
            progress: progress,
            engineFacade: engineFacade ?? self
        )
        return try await executeCommand(command)
    }
    
    public func repairWithCommand(
        damagedPath: String,
        outputPath: String
    ) async throws -> CommandResult {
        let command = RepairCommand(
            damagedPath: damagedPath,
            outputPath: outputPath,
            engineFacade: self
        )
        return try await executeCommand(command)
    }
}

// MARK: - Compress Facade

//
//


// MARK: - Unified Compression Facade

extension TTZipEngineFacade {
    public func quickCompress(
        inputs: [String],
        outputPath: String,
        format: ArchiveCompressionFormat = .zip,
        level: ArchiveCompressionLevel = .normal,
        password: String? = nil,
        splitSize: Int64? = nil,
        filterOptions: ArchiveFilterOptions = .defaultClean,
        advancedOptions: ArchiveAdvancedOptions? = nil,
        progress: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) async throws -> ArchiveOperationResult {
        guard !inputs.isEmpty && !outputPath.isEmpty else {
            throw ArchiveError.readFailed(code: -10)
        }
        
        let combinedProgress: @Sendable (ArchiveProgress) -> Void = { p in
            progress?(p)
        }
        
        if let splitBytes = splitSize, splitBytes > 0, (format == .sevenZip || format == .zip) {
            let splitFormat: NativeParallelEncryptedSplitEngine.SplitFormat = (format == .sevenZip) ? .sevenZip : .zip
            let outputDir = (outputPath as NSString).deletingLastPathComponent
            let baseName = (outputPath as NSString).lastPathComponent
            let targetDir = outputDir.isEmpty ? "." : outputDir
            
            let startTime = Date()
            let generatedVolumes = try await splitEngine.createStandardEncryptedSplitVolume(
                format: splitFormat,
                sourcePaths: inputs,
                outputDir: targetDir,
                baseName: baseName,
                splitVolumeSizeBytes: splitBytes,
                password: password ?? ""
            )
            
            let elapsed = max(0.001, Date().timeIntervalSince(startTime))
            var totalOrigBytes: Int64 = 0
            let fm = FileManager.default
            for p in inputs {
                if let attr = try? fm.attributesOfItem(atPath: p) {
                    if (attr[.type] as? FileAttributeType) == .typeDirectory {
                        let component = ArchiveComponentTreeBuilder.buildTree(fromDiskPath: p)
                        totalOrigBytes += component.sizeBytes
                    } else {
                        totalOrigBytes += (attr[.size] as? Int64) ?? 0
                    }
                }
            }
            
            var compressedSize: Int64 = 0
            for vol in generatedVolumes {
                if let attr = try? fm.attributesOfItem(atPath: vol) {
                    compressedSize += (attr[.size] as? Int64) ?? 0
                }
            }
            let rate = (Double(totalOrigBytes) / 1024.0 / 1024.0) / elapsed
            
            return ArchiveOperationResult(
                outputPath: outputPath,
                originalBytes: totalOrigBytes,
                compressedBytes: compressedSize,
                durationSeconds: elapsed,
                throughputMBs: rate
            )
        }
        
        var builder = pipelineBuilderProvider()
            .withInputPaths(inputs)
            .withOutputPath(outputPath)
            .withFormat(format)
            .withLevel(level)
            .withFilterOptions(filterOptions)
            .withPassword(password)
            .withSplitVolumeSize(splitSize)
        
        if let adv = advancedOptions {
            builder = builder.withAdvancedOptions(adv)
        }
        
        builder = builder.withProgressHandler(combinedProgress)
        
        return try await builder.executeCreate()
    }
}

// MARK: - Extract Facade

//
//


// MARK: - Unified Extraction Facade

extension TTZipEngineFacade {
    public func quickExtract(
        archivePath: String,
        destinationDir: String,
        password: String? = nil,
        autoVaultUnlock: Bool = true,
        progress: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) async throws -> ExtractResult {
        guard !archivePath.isEmpty, !destinationDir.isEmpty, FileManager.default.fileExists(atPath: archivePath) else {
            throw ArchiveError.fileNotFound
        }
        
        let combinedProgress: @Sendable (ArchiveProgress) -> Void = { p in
            progress?(p)
        }
        
        if let explicitPwd = password, !explicitPwd.isEmpty {
            let elapsed = try await executePipelineExtract(
                archivePath: archivePath,
                destinationDir: destinationDir,
                password: explicitPwd,
                progress: combinedProgress
            )
            ArchivePasswordStore.shared.setPassword(explicitPwd, for: archivePath)
            return ExtractResult(
                archivePath: archivePath,
                destinationDir: destinationDir,
                durationSeconds: elapsed,
                unlockedPassword: explicitPwd,
                isVaultUnlocked: false
            )
        } else {
            do {
                let elapsed = try await executePipelineExtract(
                    archivePath: archivePath,
                    destinationDir: destinationDir,
                    password: nil,
                    progress: combinedProgress
                )
                return ExtractResult(
                    archivePath: archivePath,
                    destinationDir: destinationDir,
                    durationSeconds: elapsed,
                    unlockedPassword: nil,
                    isVaultUnlocked: false
                )
            } catch {
                // Password-less extraction failed, try password vault auto-unlock
            }
        }
        
        if autoVaultUnlock {
            let vaultEntries = passwordVault.getEntries()
            for entry in vaultEntries {
                do {
                    let elapsed = try await executePipelineExtract(
                        archivePath: archivePath,
                        destinationDir: destinationDir,
                        password: entry.password,
                        progress: combinedProgress
                    )
                    passwordVault.recordUsage(id: entry.id)
                    ArchivePasswordStore.shared.setPassword(entry.password, for: archivePath)
                    return ExtractResult(
                        archivePath: archivePath,
                        destinationDir: destinationDir,
                        durationSeconds: elapsed,
                        unlockedPassword: entry.password,
                        isVaultUnlocked: true
                    )
                } catch {
                    // Try next candidate password in vault
                }
            }
        }
        
        throw ArchiveError.passwordRequired
    }
    
    public func extractSingleEntry(
        archivePath: String,
        entryPath: String,
        destinationDir: String,
        password: String? = nil
    ) async throws {
        guard !archivePath.isEmpty, !destinationDir.isEmpty, FileManager.default.fileExists(atPath: archivePath) else {
            throw ArchiveError.fileNotFound
        }
        
        let explicitPwd = password ?? ArchivePasswordStore.shared.getPassword(for: archivePath)
        let extractor = ArchiveEngineFactory.makeExtractor()
        try await extractor.extractSingleFile(
            archivePath: archivePath,
            entryPath: entryPath,
            destinationDir: destinationDir,
            password: explicitPwd
        )
    }
    
    internal func executePipelineExtract(
        archivePath: String,
        destinationDir: String,
        password: String?,
        progress: (@Sendable (ArchiveProgress) -> Void)?
    ) async throws -> Double {
        var builder = pipelineBuilderProvider()
            .withArchivePath(archivePath)
            .withDestinationDir(destinationDir)
            .withPassword(password)
        
        if let progress = progress {
            builder = builder.withProgressHandler(progress)
        }
        
        let res = try await builder.executeExtract()
        return res.throughputMBs
    }
}

// MARK: - Inspect Facade

//
//


// MARK: - Unified Archive Inspection & Structure Probing Facade

extension TTZipEngineFacade {
    public func inspectArchive(
        archivePath: String,
        password: String? = nil,
        autoVaultUnlock: Bool = true
    ) async throws -> ArchiveInspectionResult {
        guard !archivePath.isEmpty, FileManager.default.fileExists(atPath: archivePath) else {
            throw ArchiveError.fileNotFound
        }
        
        let explicitPwd = password ?? ArchivePasswordStore.shared.getPassword(for: archivePath)
        
        do {
            let entries = try await reader.inspect(archivePath: archivePath, password: explicitPwd)
            let treeNode = ArchiveComponentTreeBuilder.buildTree(from: entries)
            let securityReport = securityScanner.scanEntriesForReport(entries)
            if let p = explicitPwd, !p.isEmpty {
                ArchivePasswordStore.shared.setPassword(p, for: archivePath)
            }
            return ArchiveInspectionResult(
                archivePath: archivePath,
                entries: entries,
                treeNode: treeNode,
                securityReport: securityReport,
                unlockedPassword: explicitPwd
            )
        } catch ArchiveError.passwordRequired {
            // Fall through to password vault auto-unlock
        } catch {
            if explicitPwd != nil && explicitPwd?.isEmpty == false {
                throw error
            }
        }
        
        if autoVaultUnlock {
            let vaultEntries = passwordVault.getEntries()
            for entry in vaultEntries {
                if let entries = try? await reader.inspect(archivePath: archivePath, password: entry.password) {
                    passwordVault.recordUsage(id: entry.id)
                    ArchivePasswordStore.shared.setPassword(entry.password, for: archivePath)
                    let treeNode = ArchiveComponentTreeBuilder.buildTree(from: entries)
                    let securityReport = securityScanner.scanEntriesForReport(entries)
                    return ArchiveInspectionResult(
                        archivePath: archivePath,
                        entries: entries,
                        treeNode: treeNode,
                        securityReport: securityReport,
                        unlockedPassword: entry.password
                    )
                }
            }
        }
        
        throw ArchiveError.passwordRequired
    }
    
    // MARK: - Auxiliary High-Level Facade (Integrity, Repair & Password Recovery)
    
    public func verifyIntegrity(archivePath: String) async throws -> HashVerificationResult {
        let crc = integrityChecker.computeCRC32(filePath: archivePath)
        let sha = try await integrityChecker.computeSHA256(filePath: archivePath)
        return HashVerificationResult(filePath: archivePath, crc32: crc, sha256: sha)
    }
    
    public func repairArchive(damagedPath: String, outputPath: String) async throws -> Int {
        guard !damagedPath.isEmpty, !outputPath.isEmpty, FileManager.default.fileExists(atPath: damagedPath) else {
            throw ArchiveError.fileNotFound
        }
        return try await repairEngine.repairArchive(damagedArchivePath: damagedPath, repairedOutputPath: outputPath)
    }
    
    public func recoverPassword(
        archivePath: String,
        dictionary: [String]
    ) async throws -> PasswordRecoveryResult {
        return try await recoveryEngine.recoverPassword(archivePath: archivePath, dictionary: dictionary)
    }
}
