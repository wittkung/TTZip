import Foundation
import CTTZipBridge

/// 归档解压高级产物抽象，向外观使用者提供清晰且精炼的处理结果
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

/// 归档检测与探索高级产物，整合目录条目、组合树、安全审计与哈希指纹
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

/// 哈希完整性校验高级产物
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

/// 主归档统一外观接口协议
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
    func recoverPassword(archivePath: String, dictionary: [String], stateMachine: ArchiveTaskStateMachine?) async throws -> PasswordRecoveryResult
    
    // MARK: - 【3.4 命令模式 (Command Pattern)】命令与 Undo/Redo 控制
    var historyManager: CommandHistoryManager { get }
    var canUndoCommand: Bool { get }
    var canRedoCommand: Bool { get }
    func executeCommand(_ command: ArchiveCommandProtocol) async throws -> CommandResult
    func undoCommand() async throws -> CommandResult?
    func redoCommand() async throws -> CommandResult?
    func undoLastCommand() async throws -> CommandResult?
    func redoLastCommand() async throws -> CommandResult?
    
    // MARK: - 【3.5 状态模式 (State Pattern)】任务状态机生命周期管理
    func createTaskStateMachine(taskName: String, totalBytes: Int64) -> ArchiveTaskStateMachine
    func getTaskStateMachine(id: UUID) -> ArchiveTaskStateMachine?
    func pauseTask(id: UUID) throws
    func resumeTask(id: UUID) throws
    func cancelTask(id: UUID) throws

    // MARK: - 【3.6 模板方法模式 (Template Method Pattern)】算法骨架与格式特化模板工作流
    func performTemplateWorkflow(context: ArchiveTemplateContext) throws -> WorkflowResult
    func performTemplateWorkflowAsync(context: ArchiveTemplateContext) async throws -> WorkflowResult
    func getTemplateEngine(for format: ArchiveCompressionFormat) -> BaseArchiveEngineTemplate
    
    // MARK: - 【桥接模式 & 装饰器模式】Bridge Abstraction & Decorator Integration
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
    
    /// 初始化底层 C 引擎子系统（信号处理、C 结构化日志分发等）
    public static func initializeSubsystems() {
        ttzip_set_log_handler { level, message in
            guard let msg = message else { return }
            let str = String(cString: msg)
            switch level {
            case 0: TTLogger.debug("[C] \(str)")
            case 1: TTLogger.info("[C] \(str)")
            case 2: TTLogger.warning("[C] \(str)")
            default: TTLogger.error("[C] \(str)")
            }
        }
        ttzip_install_signal_handlers()
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
        return try await recoverPassword(archivePath: archivePath, dictionary: dictionary, stateMachine: nil)
    }
    
    public func recoverPassword(archivePath: String, dictionary: [String], stateMachine: ArchiveTaskStateMachine?) async throws -> PasswordRecoveryResult {
        return try await recoverPassword(archivePath: archivePath, dictionary: dictionary)
    }
    
    public func createTaskStateMachine(taskName: String = "ArchiveTask", totalBytes: Int64 = 0) -> ArchiveTaskStateMachine {
        return TTZipEngineFacade.shared.createTaskStateMachine(taskName: taskName, totalBytes: totalBytes)
    }
    
    public func getTaskStateMachine(id: UUID) -> ArchiveTaskStateMachine? {
        return TTZipEngineFacade.shared.getTaskStateMachine(id: id)
    }
    
    public func pauseTask(id: UUID) throws {
        try TTZipEngineFacade.shared.pauseTask(id: id)
    }
    
    public func resumeTask(id: UUID) throws {
        try TTZipEngineFacade.shared.resumeTask(id: id)
    }
    
    public func cancelTask(id: UUID) throws {
        try TTZipEngineFacade.shared.cancelTask(id: id)
    }

    public func performTemplateWorkflow(context: ArchiveTemplateContext) throws -> WorkflowResult {
        return try ArchiveEngineTemplateRegistry.shared.executeWorkflow(context: context)
    }

    public func performTemplateWorkflowAsync(context: ArchiveTemplateContext) async throws -> WorkflowResult {
        return try await ArchiveEngineTemplateRegistry.shared.executeWorkflowAsync(context: context)
    }

    public func getTemplateEngine(for format: ArchiveCompressionFormat) -> BaseArchiveEngineTemplate {
        return ArchiveEngineTemplateRegistry.shared.template(for: format)
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


/// 【2.5 外观模式 (Facade Pattern)】主归档统一门面中心 (`TTZipEngineFacade`)
/// 为解压/打包引擎、密码库、哈希校验、解压预览、安全扫描、分卷切片与修复恢复提供极简单 API 高层接口
public final class TTZipEngineFacade: TTZipEngineFacading, @unchecked Sendable {
    public static let shared = TTZipEngineFacade()
    
    public let historyManager: CommandHistoryManager
    private let pipelineBuilderProvider: @Sendable () -> ArchivePipelineBuilder
    private let reader: ArchiveReading
    private let securityFacade: ArchiveSecurityFacading
    private let passwordVault: PasswordVaultManaging
    private let integrityChecker: ArchiveIntegrityChecking
    private let repairEngine: ArchiveRepairEngine
    private let recoveryEngine: PasswordRecoveryEngine
    private let splitEngine: NativeParallelEncryptedSplitEngine
    
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
    
    // MARK: - 1. 快捷统一压缩门面 (Compress Facade)
    
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
        
        let valCtx = ArchiveValidationContext.forCompress(
            sourcePaths: inputs,
            destinationPath: outputPath,
            format: format,
            level: level,
            password: password,
            splitSize: splitSize,
            options: ArchiveValidationOptions(
                isSplit: splitSize != nil && splitSize! > 0,
                splitVolumeSizeBytes: splitSize,
                isEncrypted: password != nil && !password!.isEmpty,
                compressionLevel: level,
                skipMacJunk: filterOptions.skipMacJunk,
                format: format
            )
        )
        do {
            try ArchiveValidationPipeline.buildDefaultCompressPipeline().validateOrThrow(context: valCtx)
        } catch let valErr as ArchiveValidationError {
            throw valErr.asArchiveError
        }
        
        let combinedProgress: @Sendable (ArchiveProgress) -> Void = { p in
            progress?(p)
            let info = ArchiveProgressInfo(
                state: p.state,
                bytesProcessed: p.bytesProcessed,
                totalBytes: p.totalBytes,
                currentFileName: p.currentFileName,
                throughputMBs: p.throughputMBs,
                estimatedTimeRemaining: ArchiveProgressInfo.calculateETA(bytesProcessed: p.bytesProcessed, totalBytes: p.totalBytes, throughputMBs: p.throughputMBs),
                operationType: .compress
            )
            ArchiveProgressBroadcaster.shared.broadcastProgress(info)
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
            
            let res = ArchiveOperationResult(
                outputPath: outputPath,
                originalBytes: totalOrigBytes,
                compressedBytes: compressedSize,
                durationSeconds: elapsed,
                throughputMBs: rate
            )
            ArchiveEventCenter.shared.postArchiveCompleted(
                archivePath: outputPath,
                operationType: .compress,
                duration: elapsed,
                totalBytes: totalOrigBytes
            )
            return res
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
        
        let res = try await builder.executeCreate()
        ArchiveEventCenter.shared.postArchiveCompleted(
            archivePath: outputPath,
            operationType: .compress,
            duration: res.durationSeconds,
            totalBytes: res.originalBytes
        )
        return res
    }
    
    // MARK: - 2. 快捷统一解压门面 (Extract Facade)
    
    public func quickExtract(
        archivePath: String,
        destinationDir: String,
        password: String? = nil,
        autoVaultUnlock: Bool = true,
        progress: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) async throws -> ExtractResult {
        guard !archivePath.isEmpty, !destinationDir.isEmpty else {
            ArchiveEventCenter.shared.postExtractionFailed(archivePath: archivePath, error: "File not found")
            throw ArchiveError.fileNotFound
        }
        
        let valCtx = ArchiveValidationContext.forExtract(
            archivePath: archivePath,
            destinationDir: destinationDir,
            password: password
        )
        do {
            try ArchiveValidationPipeline.buildDefaultExtractPipeline().validateOrThrow(context: valCtx)
        } catch let valErr as ArchiveValidationError {
            ArchiveEventCenter.shared.postExtractionFailed(archivePath: archivePath, error: valErr.localizedDescription)
            throw valErr.asArchiveError
        }
        
        let combinedProgress: @Sendable (ArchiveProgress) -> Void = { p in
            progress?(p)
            let info = ArchiveProgressInfo(
                state: p.state,
                bytesProcessed: p.bytesProcessed,
                totalBytes: p.totalBytes,
                currentFileName: p.currentFileName,
                throughputMBs: p.throughputMBs,
                estimatedTimeRemaining: ArchiveProgressInfo.calculateETA(bytesProcessed: p.bytesProcessed, totalBytes: p.totalBytes, throughputMBs: p.throughputMBs),
                operationType: .extract
            )
            ArchiveProgressBroadcaster.shared.broadcastProgress(info)
        }
        
        if let explicitPwd = password, !explicitPwd.isEmpty {
            do {
                let elapsed = try await executePipelineExtract(
                    archivePath: archivePath,
                    destinationDir: destinationDir,
                    password: explicitPwd,
                    progress: combinedProgress
                )
                ArchivePasswordStore.shared.setPassword(explicitPwd, for: archivePath)
                let res = ExtractResult(
                    archivePath: archivePath,
                    destinationDir: destinationDir,
                    durationSeconds: elapsed,
                    unlockedPassword: explicitPwd,
                    isVaultUnlocked: false
                )
                ArchiveEventCenter.shared.postArchiveCompleted(
                    archivePath: archivePath,
                    operationType: .extract,
                    duration: elapsed,
                    totalBytes: 0
                )
                return res
            } catch {
                ArchiveEventCenter.shared.postExtractionFailed(archivePath: archivePath, error: error.localizedDescription)
                throw error
            }
        } else {
            do {
                let elapsed = try await executePipelineExtract(
                    archivePath: archivePath,
                    destinationDir: destinationDir,
                    password: nil,
                    progress: combinedProgress
                )
                let res = ExtractResult(
                    archivePath: archivePath,
                    destinationDir: destinationDir,
                    durationSeconds: elapsed,
                    unlockedPassword: nil,
                    isVaultUnlocked: false
                )
                ArchiveEventCenter.shared.postArchiveCompleted(
                    archivePath: archivePath,
                    operationType: .extract,
                    duration: elapsed,
                    totalBytes: 0
                )
                return res
            } catch {
                // 无密码解压失败，进入密码库自动解锁
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
                    ArchiveEventCenter.shared.postPasswordVaultUnlocked(
                        archivePath: archivePath,
                        password: entry.password,
                        isVaultUnlocked: true
                    )
                    ArchiveEventCenter.shared.postArchiveCompleted(
                        archivePath: archivePath,
                        operationType: .extract,
                        duration: elapsed,
                        totalBytes: 0
                    )
                    return ExtractResult(
                        archivePath: archivePath,
                        destinationDir: destinationDir,
                        durationSeconds: elapsed,
                        unlockedPassword: entry.password,
                        isVaultUnlocked: true
                    )
                } catch {
                    // 继续下个口令
                }
            }
        }
        
        ArchiveEventCenter.shared.postExtractionFailed(archivePath: archivePath, error: "Password required")
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
    
    private func executePipelineExtract(
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
        
        return try await builder.executeExtract()
    }
    
    // MARK: - 3. 快捷归档检测与结构探测门面 (Inspect Facade)
    
    public func inspectArchive(
        archivePath: String,
        password: String? = nil,
        autoVaultUnlock: Bool = true
    ) async throws -> ArchiveInspectionResult {
        let valCtx = ArchiveValidationContext.forInspect(
            archivePath: archivePath,
            password: password
        )
        do {
            try ArchiveValidationPipeline.buildDefaultInspectPipeline().validateOrThrow(context: valCtx)
        } catch let valErr as ArchiveValidationError {
            throw valErr.asArchiveError
        }
        
        let explicitPwd = password ?? ArchivePasswordStore.shared.getPassword(for: archivePath)
        
        do {
            let entries = try await reader.inspect(archivePath: archivePath, password: explicitPwd)
            let treeNode = ArchiveComponentTreeBuilder.buildTree(from: entries)
            let securityReport = securityFacade.scanEntries(entries)
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
            // 继续密码库解锁逻辑
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
                    let securityReport = securityFacade.scanEntries(entries)
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
    
    // MARK: - 4. 辅助高阶功能门面 (Integrity, Repair & Password Recovery Facade)
    
    public func verifyIntegrity(archivePath: String) async throws -> HashVerificationResult {
        let crc = integrityChecker.computeCRC32(filePath: archivePath)
        let sha = try await integrityChecker.computeSHA256(filePath: archivePath)
        return HashVerificationResult(filePath: archivePath, crc32: crc, sha256: sha)
    }
    
    public func repairArchive(damagedPath: String, outputPath: String) async throws -> Int {
        let valCtx = ArchiveValidationContext.forRepair(
            damagedPath: damagedPath,
            outputPath: outputPath
        )
        do {
            try ArchiveValidationPipeline.buildDefaultRepairPipeline().validateOrThrow(context: valCtx)
        } catch let valErr as ArchiveValidationError {
            throw valErr.asArchiveError
        }
        return try await repairEngine.repairArchive(damagedArchivePath: damagedPath, repairedOutputPath: outputPath)
    }
    
    public func recoverPassword(
        archivePath: String,
        dictionary: [String],
        stateMachine: ArchiveTaskStateMachine? = nil
    ) async throws -> PasswordRecoveryResult {
        return try await recoveryEngine.recoverPassword(archivePath: archivePath, dictionary: dictionary, stateMachine: stateMachine)
    }

    // MARK: - 【3.6 模板方法模式 (Template Method Pattern)】算法骨架与格式特化模板工作流实现

    public func performTemplateWorkflow(context: ArchiveTemplateContext) throws -> WorkflowResult {
        return try ArchiveEngineTemplateRegistry.shared.executeWorkflow(context: context)
    }

    public func performTemplateWorkflowAsync(context: ArchiveTemplateContext) async throws -> WorkflowResult {
        return try await ArchiveEngineTemplateRegistry.shared.executeWorkflowAsync(context: context)
    }

    public func getTemplateEngine(for format: ArchiveCompressionFormat) -> BaseArchiveEngineTemplate {
        return ArchiveEngineTemplateRegistry.shared.template(for: format)
    }
}

// MARK: - 【2.7 代理模式 (Proxy Pattern)】代理通道集成

extension TTZipEngineFacade {
    /// 开启安全保护代理 (Protection Proxy) 进行极速压缩/解压校验
    public var protected: SecurityProtectionProxy {
        SecurityProtectionProxy.shared
    }
    
    /// 开启热缓存代理 (Cache Proxy) 查询归档条目与结构
    public var cached: ArchiveInspectionCacheProxy {
        ArchiveInspectionCacheProxy.shared
    }
    
    /// 开启智能日志与并发审计代理 (Smart Logging Proxy)
    public var logged: SmartLoggingProxy {
        SmartLoggingProxy.shared
    }
    
    /// 热数据缓存版 inspectArchive API
    public func inspectArchiveCached(
        archivePath: String,
        password: String? = nil,
        autoVaultUnlock: Bool = true
    ) async throws -> ArchiveInspectionResult {
        return try await ArchiveInspectionCacheProxy.shared.inspectArchive(
            archivePath: archivePath,
            password: password,
            autoVaultUnlock: autoVaultUnlock
        )
    }
}

