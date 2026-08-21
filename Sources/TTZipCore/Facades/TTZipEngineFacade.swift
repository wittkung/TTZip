// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// 【2.5 外观模式 (Facade Pattern)】主归档统一门面中心 (`TTZipEngineFacade`)
/// 为解压/打包引擎、密码库、哈希校验、解压预览、安全扫描、分卷切片与修复恢复提供极简单 API 高层接口
public final class TTZipEngineFacade: TTZipEngineFacading, @unchecked Sendable {
    public static let shared = TTZipEngineFacade()
    
    public let historyManager: CommandHistoryManager
    internal let pipelineBuilderProvider: @Sendable () -> ArchivePipelineBuilder
    internal let reader: ArchiveReading
    internal let securityFacade: ArchiveSecurityFacading
    internal let passwordVault: PasswordVaultManaging
    internal let integrityChecker: ArchiveIntegrityChecking
    internal let repairEngine: ArchiveRepairEngine
    internal let recoveryEngine: PasswordRecoveryEngine
    internal let splitEngine: NativeParallelEncryptedSplitEngine
    
    private var activeStateMachines: [UUID: ArchiveTaskStateMachine] = [:]
    private let stateMachineLock = NSLock()
    
    private convenience init() {
        self.init(
            historyManager: CommandHistoryManager.shared,
            pipelineBuilderProvider: { ArchivePipelineBuilder() },
            reader: ArchiveEngineFactory.makeReader(),
            securityFacade: ArchiveSecurityFacade.shared,
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
        securityFacade: ArchiveSecurityFacading = ArchiveSecurityFacade.shared,
        passwordVault: PasswordVaultManaging = PasswordVaultManager.shared,
        integrityChecker: ArchiveIntegrityChecking = ArchiveEngineFactory.makeIntegrityChecker(),
        repairEngine: ArchiveRepairEngine = ArchiveRepairEngine(),
        recoveryEngine: PasswordRecoveryEngine = PasswordRecoveryEngine(),
        splitEngine: NativeParallelEncryptedSplitEngine = NativeParallelEncryptedSplitEngine()
    ) {
        self.historyManager = historyManager
        self.pipelineBuilderProvider = pipelineBuilderProvider
        self.reader = reader
        self.securityFacade = securityFacade
        self.passwordVault = passwordVault
        self.integrityChecker = integrityChecker
        self.repairEngine = repairEngine
        self.recoveryEngine = recoveryEngine
        self.splitEngine = splitEngine
    }
    
    // MARK: - 【3.5 状态模式 (State Pattern)】任务状态机生命周期 API 实现
    
    public func createTaskStateMachine(taskName: String = "ArchiveTask", totalBytes: Int64 = 0) -> ArchiveTaskStateMachine {
        let sm = ArchiveTaskStateMachine(taskName: taskName, totalBytes: totalBytes)
        stateMachineLock.lock()
        activeStateMachines[sm.id] = sm
        stateMachineLock.unlock()
        return sm
    }
    
    public func getTaskStateMachine(id: UUID) -> ArchiveTaskStateMachine? {
        stateMachineLock.lock()
        defer { stateMachineLock.unlock() }
        return activeStateMachines[id]
    }
    
    public func pauseTask(id: UUID) throws {
        guard let sm = getTaskStateMachine(id: id) else {
            throw CommandError.invalidState(reason: "未找到 ID 为 \(id) 的任务状态机")
        }
        try sm.pause()
    }
    
    public func resumeTask(id: UUID) throws {
        guard let sm = getTaskStateMachine(id: id) else {
            throw CommandError.invalidState(reason: "未找到 ID 为 \(id) 的任务状态机")
        }
        try sm.resume()
    }
    
    public func cancelTask(id: UUID) throws {
        guard let sm = getTaskStateMachine(id: id) else {
            throw CommandError.invalidState(reason: "未找到 ID 为 \(id) 的任务状态机")
        }
        try sm.cancel()
    }
    
    // MARK: - 命令模式便捷包装方法
    
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
            engineFacade: engineFacade ?? SecurityProtectionProxy.shared
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
            engineFacade: engineFacade ?? SecurityProtectionProxy.shared
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
