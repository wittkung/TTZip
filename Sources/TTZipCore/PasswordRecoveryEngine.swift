import Foundation

public struct PasswordRecoveryResult: Sendable {
    public let foundPassword: String?
    public let totalAttempts: Int64
    public let durationSeconds: Double
    
    public var attemptsPerSecond: Double {
        return durationSeconds > 0 ? Double(totalAttempts) / durationSeconds : 0
    }
}

/// 【3.5 状态模式 (State Pattern)】多核并行归档密码校验与恢复引擎
/// 贯穿支持 ArchiveTaskStateMachine 状态机生命周期控制（Pause/Resume/Cancel/Checkpoint 断点续传）
public final class PasswordRecoveryEngine: @unchecked Sendable {
    public let checkpointCaretaker: TaskCheckpointCaretaker
    
    public init(checkpointCaretaker: TaskCheckpointCaretaker = TaskCheckpointCaretaker()) {
        self.checkpointCaretaker = checkpointCaretaker
    }
    
    /// 针对受密码保护的归档文件执行策略链比对与标头校验，支持 ArchiveTaskStateMachine 状态控制
    public func recoverPassword(
        archivePath: String,
        dictionary: [String],
        stateMachine: ArchiveTaskStateMachine? = nil
    ) async throws -> PasswordRecoveryResult {
        if let sm = stateMachine {
            if sm.currentState is CompletedState {
                throw ArchiveStateError.taskAlreadyCompleted
            } else if sm.currentState is FailedState {
                throw ArchiveStateError.taskAlreadyFailed(reason: sm.lastError?.localizedDescription ?? "Task already failed")
            }
        }
        
        guard FileManager.default.fileExists(atPath: archivePath) else {
            let err = ArchiveError.fileNotFound
            try? stateMachine?.fail(error: err)
            throw err
        }
        
        
        let sm = stateMachine ?? ArchiveTaskStateMachine(
            taskName: "PasswordRecovery:\((archivePath as NSString).lastPathComponent)",
            totalBytes: Int64(dictionary.count)
        )
        if sm.currentState is IdleState {
            try? sm.start()
        }
        
        if sm.checkpointOffset == 0, let loaded = checkpointCaretaker.loadCheckpoint(taskID: sm.id) {
            sm.setCheckpointOffset(loaded.dictionaryOffset)
        }
        
        let startIndex = min(max(0, Int(sm.checkpointOffset)), dictionary.count)
        let totalCount = dictionary.count
        
        var attempts: Int64 = Int64(startIndex)
        var foundPassword: String? = nil
        let start = Date()
        
        for i in startIndex..<totalCount {
            // 响应 PausedState 挂起状态
            while sm.currentState is PausedState {
                let pauseMemento = TaskCheckpointMemento(
                    taskID: sm.id,
                    taskName: sm.taskName,
                    stateName: sm.stateName,
                    processedBytes: attempts,
                    totalBytes: Int64(totalCount),
                    dictionaryOffset: attempts,
                    throughputTPS: Double(attempts) / max(0.001, Date().timeIntervalSince(start)),
                    checksum: "PAUSE-\(attempts)"
                )
                checkpointCaretaker.saveCheckpoint(pauseMemento)
                
                try await Task.sleep(nanoseconds: 50_000_000) // 50ms
                if Task.isCancelled || sm.currentState is CancellingState || sm.currentState is FailedState {
                    break
                }
            }
            
            // 响应 CancellingState 善后终止状态
            if Task.isCancelled || sm.currentState is CancellingState {
                if !(sm.currentState is FailedState) {
                    try? sm.cancel()
                }
                throw CommandError.executionFailed(reason: "密码破解任务已被中断取消")
            }
            
            let pwd = dictionary[i]
            attempts += 1
            sm.updateProgress(processedBytes: attempts, totalBytes: Int64(totalCount))
            sm.setCheckpointOffset(attempts)
            
            if attempts % 10 == 0 || i == totalCount - 1 {
                let memento = TaskCheckpointMemento(
                    taskID: sm.id,
                    taskName: sm.taskName,
                    stateName: sm.stateName,
                    processedBytes: attempts,
                    totalBytes: Int64(totalCount),
                    dictionaryOffset: attempts,
                    throughputTPS: Double(attempts) / max(0.001, Date().timeIntervalSince(start)),
                    checksum: "CHK-\(attempts)"
                )
                checkpointCaretaker.saveCheckpoint(memento)
            }
            
            let isCorrect = await Self.testArchivePassword(archivePath: archivePath, password: pwd)
            if isCorrect {
                foundPassword = pwd
                break
            }
        }
        
        let duration = max(0.001, Date().timeIntervalSince(start))
        let result = PasswordRecoveryResult(
            foundPassword: foundPassword,
            totalAttempts: attempts,
            durationSeconds: duration
        )
        
        if let pwd = result.foundPassword {
            ArchiveEventCenter.shared.postPasswordVaultUnlocked(archivePath: archivePath, password: pwd, isVaultUnlocked: false)
            try? sm.complete()
        } else {
            let failErr = ArchiveError.readFailed(code: -404)
            try? sm.fail(error: failErr)
        }
        
        ArchiveProgressBroadcaster.shared.broadcastProgress(ArchiveProgressInfo(
            state: result.foundPassword != nil ? .completed : .failed(error: "Password not found"),
            bytesProcessed: result.totalAttempts,
            totalBytes: Int64(dictionary.count),
            currentFileName: (archivePath as NSString).lastPathComponent,
            throughputMBs: result.attemptsPerSecond,
            estimatedTimeRemaining: 0,
            operationType: .recover
        ))
        
        return result
    }
    
    /// 深度校验给出的密码能否正确解开归档标头或内容 (100% 进程内纯 C 引擎快速微提取探测)
    private static func testArchivePassword(archivePath: String, password: String) async -> Bool {
        let tempDir = (NSTemporaryDirectory() as NSString).appendingPathComponent("TTZip_PwdTest_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }
        
        let ext = (archivePath as NSString).pathExtension.lowercased()
        if ext == "zip" {
            return ttzip_extract_zip_c_parallel(archivePath, tempDir, false, password) == 0
        } else if ext == "7z" || ext == "cb7" {
            return ttzip_extract_7z_native_c(archivePath, tempDir, password) == 0
        } else {
            return ttzip_extract_archive_advanced(archivePath, tempDir, false, password) == 0
        }
    }

    /// 【3.6 模板方法模式 (Template Method Pattern)】使用密码恢复骨架模板执行破解与恢复
    public func recoverPasswordViaTemplate(
        archivePath: String,
        dictionary: [String],
        stateMachine: ArchiveTaskStateMachine? = nil
    ) async throws -> PasswordRecoveryResult {
        let context = ArchiveTemplateContext(
            operation: .recover,
            archivePath: archivePath,
            dictionary: dictionary,
            stateMachine: stateMachine
        )
        let template = PasswordRecoveryEngineTemplate()
        let result = try await template.performWorkflowAsync(context: context)
        return PasswordRecoveryResult(
            foundPassword: result.unlockedPassword,
            totalAttempts: result.processedBytes,
            durationSeconds: result.durationSeconds
        )
    }
}
