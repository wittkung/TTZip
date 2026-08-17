import Foundation

/// 命令模式统一产物封装，传递命令执行/撤销的状态、受影响的文件及元数据
public struct CommandResult: Sendable, Equatable {
    /// 命令唯一标识符
    public let commandId: String
    
    /// 执行是否成功
    public let success: Bool
    
    /// 状态描述或结果摘要
    public let message: String
    
    /// 命令执行过程中创建的产物文件路径列表（例如生成的压缩包、解压产生的文件等）
    public let artifactsCreated: [String]
    
    /// 备份路径映射表 (原始文件路径 -> 备份文件路径)
    public let backupPaths: [String: String]
    
    /// 执行耗时（秒）
    public let executionDuration: Double
    
    /// 拓展元数据字典
    public let metadata: [String: String]
    
    public init(
        commandId: String,
        success: Bool,
        message: String,
        artifactsCreated: [String] = [],
        backupPaths: [String: String] = [:],
        executionDuration: Double = 0.0,
        metadata: [String: String] = [:]
    ) {
        self.commandId = commandId
        self.success = success
        self.message = message
        self.artifactsCreated = artifactsCreated
        self.backupPaths = backupPaths
        self.executionDuration = executionDuration
        self.metadata = metadata
    }
}

/// 命令模式异常类型枚举
public enum CommandError: Error, LocalizedError, Equatable {
    case notUndoable(commandId: String)
    case executionFailed(reason: String)
    case undoFailed(reason: String)
    case macroExecutionFailed(failedIndex: Int, underlyingError: String, rollbackErrors: [String])
    case invalidState(reason: String)
    
    public var errorDescription: String? {
        switch self {
        case .notUndoable(let id):
            return "命令不可撤销: \(id)"
        case .executionFailed(let reason):
            return "命令执行失败: \(reason)"
        case .undoFailed(let reason):
            return "命令撤销失败: \(reason)"
        case .macroExecutionFailed(let idx, let err, let rollbacks):
            return "宏命令在索引 [\(idx)] 执行失败: \(err)。逆序 Rollback 状态: \(rollbacks.isEmpty ? "成功" : "部分撤销异常(\(rollbacks.joined(separator: "; ")))")"
        case .invalidState(let reason):
            return "命令非法状态: \(reason)"
        }
    }
}
