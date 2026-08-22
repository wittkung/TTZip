// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

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
