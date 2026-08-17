import Foundation

/// 归档命令抽象接口协议（命令模式 Command Interface）
/// 统一约束所有归档相关可执行与可撤销原子指令
public protocol ArchiveCommandProtocol: Sendable {
    /// 命令全局唯一标识符 UUID
    var commandId: String { get }
    
    /// 命令可读描述信息（用于 Undo/Redo 菜单及日志）
    var description: String { get }
    
    /// 是否支持撤销 Undo 操作
    var isUndoable: Bool { get }
    
    /// 执行命令逻辑
    /// - Returns: 执行产物状态 CommandResult
    func execute() async throws -> CommandResult
    
    /// 撤销命令逻辑
    /// - Throws: CommandError
    func undo() async throws
    
    /// 清理命令持有的磁盘备份文件/临时资源（当命令从历史栈中丢弃或主动清空时触发）
    func purgeBackupResources()
}

public extension ArchiveCommandProtocol {
    func purgeBackupResources() {
        // 默认空实现：无需备份文件的命令无视此操作
    }
}

