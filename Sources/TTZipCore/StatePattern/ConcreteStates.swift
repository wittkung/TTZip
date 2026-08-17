import Foundation

// MARK: - 1. IdleState (初始空闲准备状态)
public struct IdleState: ArchiveTaskStateProtocol {
    public let stateName = "Idle"
    public let canPause = false
    public let canResume = false
    public let canCancel = false
    
    public init() {}
    
    public func pause(context: ArchiveTaskContext) throws {
        throw ArchiveError.invalidState
    }
    
    public func resume(context: ArchiveTaskContext) throws {
        throw ArchiveError.invalidState
    }
    
    public func cancel(context: ArchiveTaskContext) throws {
        throw ArchiveError.invalidState
    }
    
    public func fail(context: ArchiveTaskContext, error: Error) throws {
        context.cleanupTempFiles()
        context.setLastError(error)
        context.transitionTo(FailedState(error: error))
    }
    
    public func complete(context: ArchiveTaskContext) throws {
        throw ArchiveStateError.invalidTransition(from: stateName, action: "complete")
    }
}

// MARK: - 2. PreparingState (前置校验与资源分配状态)
public struct PreparingState: ArchiveTaskStateProtocol {
    public let stateName = "Preparing"
    public let canPause = false
    public let canResume = false
    public let canCancel = true
    
    public init() {}
    
    public func pause(context: ArchiveTaskContext) throws {
        throw ArchiveError.invalidState
    }
    
    public func resume(context: ArchiveTaskContext) throws {
        throw ArchiveError.invalidState
    }
    
    public func cancel(context: ArchiveTaskContext) throws {
        guard context.transitionTo(CancellingState()) else {
            throw ArchiveError.invalidState
        }
        context.cleanupTempFiles()
        let cancelError = CommandError.executionFailed(reason: "任务在准备阶段被取消")
        context.setLastError(cancelError)
        context.transitionTo(FailedState(error: cancelError))
    }
    
    public func fail(context: ArchiveTaskContext, error: Error) throws {
        context.cleanupTempFiles()
        context.setLastError(error)
        context.transitionTo(FailedState(error: error))
    }
    
    public func complete(context: ArchiveTaskContext) throws {
        context.transitionTo(CompletedState())
    }
}

// MARK: - 3. RunningState (流式压缩/解压运行中状态)
public struct RunningState: ArchiveTaskStateProtocol {
    public let stateName = "Running"
    public let canPause = true
    public let canResume = false
    public let canCancel = true
    
    public init() {}
    
    public func pause(context: ArchiveTaskContext) throws {
        context.setCheckpointOffset(context.processedBytes)
        guard context.transitionTo(PausedState()) else {
            throw ArchiveError.invalidState
        }
    }
    
    public func resume(context: ArchiveTaskContext) throws {
        throw ArchiveError.invalidState
    }
    
    public func cancel(context: ArchiveTaskContext) throws {
        guard context.transitionTo(CancellingState()) else {
            throw ArchiveError.invalidState
        }
        context.cleanupTempFiles()
        let cancelError = CommandError.executionFailed(reason: "任务运行中被取消")
        context.setLastError(cancelError)
        context.transitionTo(FailedState(error: cancelError))
    }
    
    public func fail(context: ArchiveTaskContext, error: Error) throws {
        context.cleanupTempFiles()
        context.setLastError(error)
        context.transitionTo(FailedState(error: error))
    }
    
    public func complete(context: ArchiveTaskContext) throws {
        context.updateProgress(processedBytes: max(context.processedBytes, context.totalBytes))
        context.transitionTo(CompletedState())
    }
}

// MARK: - 4. PausedState (暂停挂起状态: 冻结 I/O 流，保存 Checkpoint 断点)
public struct PausedState: ArchiveTaskStateProtocol {
    public let stateName = "Paused"
    public let canPause = false
    public let canResume = true
    public let canCancel = true
    
    public init() {}
    
    public func pause(context: ArchiveTaskContext) throws {
        throw ArchiveError.invalidState
    }
    
    public func resume(context: ArchiveTaskContext) throws {
        // 从 context.checkpointOffset 恢复运行
        context.updateProgress(processedBytes: context.checkpointOffset)
        guard context.transitionTo(RunningState()) else {
            throw ArchiveError.invalidState
        }
    }
    
    public func cancel(context: ArchiveTaskContext) throws {
        guard context.transitionTo(CancellingState()) else {
            throw ArchiveError.invalidState
        }
        context.cleanupTempFiles()
        let cancelError = CommandError.executionFailed(reason: "暂停状态下的任务被取消")
        context.setLastError(cancelError)
        context.transitionTo(FailedState(error: cancelError))
    }
    
    public func fail(context: ArchiveTaskContext, error: Error) throws {
        context.cleanupTempFiles()
        context.setLastError(error)
        context.transitionTo(FailedState(error: error))
    }
    
    public func complete(context: ArchiveTaskContext) throws {
        throw ArchiveStateError.invalidTransition(from: stateName, action: "complete")
    }
}

// MARK: - 5. CancellingState (正在取消善后状态: 终止 Task/子进程，彻底清除半成品)
public struct CancellingState: ArchiveTaskStateProtocol {
    public let stateName = "Cancelling"
    public let canPause = false
    public let canResume = false
    public let canCancel = false
    
    public init() {}
    
    public func pause(context: ArchiveTaskContext) throws {
        throw ArchiveError.invalidState
    }
    
    public func resume(context: ArchiveTaskContext) throws {
        throw ArchiveError.invalidState
    }
    
    public func cancel(context: ArchiveTaskContext) throws {
        throw ArchiveError.invalidState
    }
    
    public func fail(context: ArchiveTaskContext, error: Error) throws {
        context.cleanupTempFiles()
        context.setLastError(error)
        context.transitionTo(FailedState(error: error))
    }
    
    public func complete(context: ArchiveTaskContext) throws {
        throw ArchiveStateError.invalidTransition(from: stateName, action: "complete")
    }
}

// MARK: - 6. CompletedState (终态成功完成)
public struct CompletedState: ArchiveTaskStateProtocol {
    public let stateName = "Completed"
    public let canPause = false
    public let canResume = false
    public let canCancel = false
    
    public init() {}
    
    public func pause(context: ArchiveTaskContext) throws {
        throw ArchiveError.invalidState
    }
    
    public func resume(context: ArchiveTaskContext) throws {
        throw ArchiveError.invalidState
    }
    
    public func cancel(context: ArchiveTaskContext) throws {
        throw ArchiveError.invalidState
    }
    
    public func fail(context: ArchiveTaskContext, error: Error) throws {
        throw ArchiveStateError.taskAlreadyCompleted
    }
    
    public func complete(context: ArchiveTaskContext) throws {
        throw ArchiveStateError.taskAlreadyCompleted
    }
}

// MARK: - 7. FailedState (终态失败: 记录异常信息)
public struct FailedState: ArchiveTaskStateProtocol {
    public let stateName = "Failed"
    public let canPause = false
    public let canResume = false
    public let canCancel = false
    
    public let error: Error
    
    public init(error: Error) {
        self.error = error
    }
    
    public func pause(context: ArchiveTaskContext) throws {
        throw ArchiveError.invalidState
    }
    
    public func resume(context: ArchiveTaskContext) throws {
        throw ArchiveError.invalidState
    }
    
    public func cancel(context: ArchiveTaskContext) throws {
        throw ArchiveError.invalidState
    }
    
    public func fail(context: ArchiveTaskContext, error: Error) throws {
        throw ArchiveStateError.taskAlreadyFailed(reason: self.error.localizedDescription)
    }
    
    public func complete(context: ArchiveTaskContext) throws {
        throw ArchiveStateError.taskAlreadyFailed(reason: error.localizedDescription)
    }
}
