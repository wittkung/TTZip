import Foundation

/// 批量压缩任务参数包装
public struct BatchCompressTask: Identifiable, Sendable {
    public let id: UUID
    public let inputs: [String]
    public let outputPath: String
    public let format: ArchiveCompressionFormat
    public let level: ArchiveCompressionLevel
    public let password: String?
    public let splitSize: Int64?
    
    public init(
        id: UUID = UUID(),
        inputs: [String],
        outputPath: String,
        format: ArchiveCompressionFormat = .zip,
        level: ArchiveCompressionLevel = .normal,
        password: String? = nil,
        splitSize: Int64? = nil
    ) {
        self.id = id
        self.inputs = inputs
        self.outputPath = outputPath
        self.format = format
        self.level = level
        self.password = password
        self.splitSize = splitSize
    }
}

/// 批量解压任务参数包装
public struct BatchExtractTask: Identifiable, Sendable {
    public let id: UUID
    public let archivePath: String
    public let destinationDir: String
    public let password: String?
    
    public init(
        id: UUID = UUID(),
        archivePath: String,
        destinationDir: String,
        password: String? = nil
    ) {
        self.id = id
        self.archivePath = archivePath
        self.destinationDir = destinationDir
        self.password = password
    }
}

/// 批量任务执行统一结果
public struct BatchTaskResult: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let success: Bool
    public let targetPath: String
    public let durationSeconds: Double
    public let errorMessage: String?
    
    public init(
        id: UUID,
        success: Bool,
        targetPath: String,
        durationSeconds: Double,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.success = success
        self.targetPath = targetPath
        self.durationSeconds = durationSeconds
        self.errorMessage = errorMessage
    }
}

/// 批处理外观接口协议
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
    
    // MARK: - 【3.4 命令模式 (Command Pattern)】基于 MacroArchiveCommand 的批处理与自动回滚支持
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
    
    // MARK: - 【3.5 状态模式 (State Pattern)】批处理状态机管理与批量控制 API
    func getTaskStateMachine(id: UUID) -> ArchiveTaskStateMachine?
    func pauseAllTasks()
    func resumeAllTasks()
    func cancelAllTasks()
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
    
    public func getTaskStateMachine(id: UUID) -> ArchiveTaskStateMachine? {
        return ArchiveBatchFacade.shared.getTaskStateMachine(id: id)
    }
    
    public func pauseAllTasks() {
        ArchiveBatchFacade.shared.pauseAllTasks()
    }
    
    public func resumeAllTasks() {
        ArchiveBatchFacade.shared.resumeAllTasks()
    }
    
    public func cancelAllTasks() {
        ArchiveBatchFacade.shared.cancelAllTasks()
    }
}


/// 【2.5 外观模式 (Facade Pattern)】批处理与并行任务调度门面 (`ArchiveBatchFacade`)
/// 屏蔽 UI 拖拽多文件归档、批量解压并发控制与 TaskGroup 并行调度的复杂编排
public final class ArchiveBatchFacade: ArchiveBatchFacading, @unchecked Sendable {
    public static let shared = ArchiveBatchFacade()
    
    private let engineFacade: TTZipEngineFacading
    private var activeStateMachines: [UUID: ArchiveTaskStateMachine] = [:]
    private let batchLock = NSLock()
    
    private convenience init() {
        self.init(engineFacade: TTZipEngineFacade.shared)
    }
    
    internal init(engineFacade: TTZipEngineFacading = TTZipEngineFacade.shared) {
        self.engineFacade = engineFacade
    }
    
    // MARK: - 【3.5 状态模式 (State Pattern)】批处理状态机与批量控制 API
    
    public func getTaskStateMachine(id: UUID) -> ArchiveTaskStateMachine? {
        batchLock.lock()
        defer { batchLock.unlock() }
        return activeStateMachines[id]
    }
    
    public func pauseAllTasks() {
        batchLock.lock()
        let sms = Array(activeStateMachines.values)
        batchLock.unlock()
        for sm in sms where sm.canPause {
            try? sm.pause()
        }
    }
    
    public func resumeAllTasks() {
        batchLock.lock()
        let sms = Array(activeStateMachines.values)
        batchLock.unlock()
        for sm in sms where sm.canResume {
            try? sm.resume()
        }
    }
    
    public func cancelAllTasks() {
        batchLock.lock()
        let sms = Array(activeStateMachines.values)
        batchLock.unlock()
        for sm in sms where sm.canCancel {
            try? sm.cancel()
        }
    }
    
    @discardableResult
    public func registerStateMachine(id: UUID, taskName: String) -> ArchiveTaskStateMachine {
        let sm = ArchiveTaskStateMachine(id: id, taskName: taskName)
        batchLock.lock()
        activeStateMachines[id] = sm
        batchLock.unlock()
        return sm
    }
    
    // MARK: - 1. 批量并行归档压缩 (Batch Compress API)
    
    public func batchCompress(
        tasks: [BatchCompressTask],
        maxConcurrent: Int = 4,
        progress: (@Sendable (Int, Int) -> Void)? = nil
    ) async -> [BatchTaskResult] {
        guard !tasks.isEmpty else { return [] }
        
        let total = tasks.count
        let concurrency = max(1, min(maxConcurrent, 16))
        
        return await withTaskGroup(of: BatchTaskResult.self) { group in
            var results: [BatchTaskResult] = []
            var submitted = 0
            var completed = 0
            
            // 初始化首批并发任务
            for _ in 0..<min(concurrency, total) {
                if Task.isCancelled { break }
                let task = tasks[submitted]
                submitted += 1
                group.addTask {
                    await self.executeSingleCompressTask(task)
                }
            }
            
            for await res in group {
                results.append(res)
                completed += 1
                progress?(completed, total)
                ArchiveProgressBroadcaster.shared.broadcastBatchProgress(BatchProgressInfo(
                    completedTasks: completed,
                    totalTasks: total,
                    currentTaskPath: res.targetPath,
                    totalBytesProcessed: Int64(completed),
                    totalBytesCount: Int64(total),
                    throughputMBs: 0.0,
                    estimatedTimeRemaining: nil
                ))
                
                if Task.isCancelled {
                    group.cancelAll()
                    break
                }
                
                if submitted < total {
                    let nextTask = tasks[submitted]
                    submitted += 1
                    group.addTask {
                        await self.executeSingleCompressTask(nextTask)
                    }
                }
            }
            
            return results
        }
    }
    
    private func executeSingleCompressTask(_ task: BatchCompressTask) async -> BatchTaskResult {
        let sm = registerStateMachine(id: task.id, taskName: "BatchCompress:\(task.outputPath)")
        if Task.isCancelled {
            try? sm.cancel()
            return BatchTaskResult(
                id: task.id,
                success: false,
                targetPath: task.outputPath,
                durationSeconds: 0,
                errorMessage: "Task cancelled"
            )
        }
        let start = Date()
        do {
            try sm.start()
            let res = try await engineFacade.quickCompress(
                inputs: task.inputs,
                outputPath: task.outputPath,
                format: task.format,
                level: task.level,
                password: task.password,
                splitSize: task.splitSize,
                progress: nil
            )
            try sm.complete()
            return BatchTaskResult(
                id: task.id,
                success: true,
                targetPath: res.outputPath,
                durationSeconds: res.durationSeconds,
                errorMessage: nil
            )
        } catch {
            try? sm.fail(error: error)
            let elapsed = Date().timeIntervalSince(start)
            return BatchTaskResult(
                id: task.id,
                success: false,
                targetPath: task.outputPath,
                durationSeconds: elapsed,
                errorMessage: error.localizedDescription
            )
        }
    }
    
    // MARK: - 2. 批量并行归档解压 (Batch Extract API)
    
    public func batchExtract(
        tasks: [BatchExtractTask],
        maxConcurrent: Int = 4,
        autoVaultUnlock: Bool = true,
        progress: (@Sendable (Int, Int) -> Void)? = nil
    ) async -> [BatchTaskResult] {
        guard !tasks.isEmpty else { return [] }
        
        let total = tasks.count
        let concurrency = max(1, min(maxConcurrent, 16))
        
        return await withTaskGroup(of: BatchTaskResult.self) { group in
            var results: [BatchTaskResult] = []
            var submitted = 0
            var completed = 0
            
            for _ in 0..<min(concurrency, total) {
                if Task.isCancelled { break }
                let task = tasks[submitted]
                submitted += 1
                group.addTask {
                    await self.executeSingleExtractTask(task, autoVaultUnlock: autoVaultUnlock)
                }
            }
            
            for await res in group {
                results.append(res)
                completed += 1
                progress?(completed, total)
                ArchiveProgressBroadcaster.shared.broadcastBatchProgress(BatchProgressInfo(
                    completedTasks: completed,
                    totalTasks: total,
                    currentTaskPath: res.targetPath,
                    totalBytesProcessed: Int64(completed),
                    totalBytesCount: Int64(total),
                    throughputMBs: 0.0,
                    estimatedTimeRemaining: nil
                ))
                
                if Task.isCancelled {
                    group.cancelAll()
                    break
                }
                
                if submitted < total {
                    let nextTask = tasks[submitted]
                    submitted += 1
                    group.addTask {
                        await self.executeSingleExtractTask(nextTask, autoVaultUnlock: autoVaultUnlock)
                    }
                }
            }
            
            return results
        }
    }
    
    private func executeSingleExtractTask(_ task: BatchExtractTask, autoVaultUnlock: Bool) async -> BatchTaskResult {
        let sm = registerStateMachine(id: task.id, taskName: "BatchExtract:\(task.archivePath)")
        if Task.isCancelled {
            try? sm.cancel()
            return BatchTaskResult(
                id: task.id,
                success: false,
                targetPath: task.destinationDir,
                durationSeconds: 0,
                errorMessage: "Task cancelled"
            )
        }
        let start = Date()
        do {
            try sm.start()
            let res = try await engineFacade.quickExtract(
                archivePath: task.archivePath,
                destinationDir: task.destinationDir,
                password: task.password,
                autoVaultUnlock: autoVaultUnlock,
                progress: nil
            )
            try sm.complete()
            return BatchTaskResult(
                id: task.id,
                success: true,
                targetPath: res.destinationDir,
                durationSeconds: res.durationSeconds,
                errorMessage: nil
            )
        } catch {
            try? sm.fail(error: error)
            let elapsed = Date().timeIntervalSince(start)
            return BatchTaskResult(
                id: task.id,
                success: false,
                targetPath: task.destinationDir,
                durationSeconds: elapsed,
                errorMessage: error.localizedDescription
            )
        }
    }
    
    // MARK: - 【3.4 命令模式 (Command Pattern)】事务型宏命令批处理
    
    public func batchExecuteMacro(
        commands: [ArchiveCommandProtocol],
        description: String? = nil
    ) async throws -> CommandResult {
        let macro = MacroArchiveCommand(
            description: description ?? "事务型批量任务 (包含 \(commands.count) 个子步骤)",
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
        return try await batchExecuteMacro(commands: commands, description: "事务型批量打包压缩 (\(tasks.count) 个任务)")
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
        return try await batchExecuteMacro(commands: commands, description: "事务型批量解压缩 (\(tasks.count) 个任务)")
    }
}

