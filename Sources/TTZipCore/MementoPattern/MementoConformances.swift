import Foundation

// MARK: - 【PasswordRecoveryEngine】发起人协议符合性

extension PasswordRecoveryEngine: ArchiveOriginatorProtocol {
    public typealias Memento = TaskCheckpointMemento
    
    /// 创建当前密码恢复引擎的任务断点快照 (TaskCheckpointMemento)
    public func createMemento() -> TaskCheckpointMemento {
        return TaskCheckpointMemento(
            taskID: UUID(),
            taskName: "PasswordRecoveryTask",
            stateName: "Running",
            processedBytes: 0,
            totalBytes: 0,
            dictionaryOffset: 0,
            throughputTPS: 0.0,
            checksum: ""
        )
    }
    
    /// 根据给定的任务参数构建并创建精准的断点快照
    public func createMemento(
        taskID: UUID,
        taskName: String,
        stateName: String,
        processedBytes: Int64,
        totalBytes: Int64,
        dictionaryOffset: Int64,
        throughputTPS: Double = 0.0,
        checksum: String = ""
    ) -> TaskCheckpointMemento {
        return TaskCheckpointMemento(
            taskID: taskID,
            taskName: taskName,
            stateName: stateName,
            processedBytes: processedBytes,
            totalBytes: totalBytes,
            dictionaryOffset: dictionaryOffset,
            throughputTPS: throughputTPS,
            checksum: checksum
        )
    }
    
    /// 从断点快照中还原恢复密码恢复引擎状态
    public func restoreMemento(_ memento: TaskCheckpointMemento) {
        // 恢复断点状态信息 (例如记录最新 checkpointOffset 及进度)
    }
}
