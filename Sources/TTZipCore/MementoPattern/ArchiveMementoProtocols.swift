import Foundation

/// 归档备忘录模式核心接口 (Memento Protocol)
public protocol ArchiveMementoProtocol: Sendable {
    var id: UUID { get }
    var timestamp: Date { get }
}

/// 归档发起人接口 (Originator Protocol)
public protocol ArchiveOriginatorProtocol {
    associatedtype Memento: ArchiveMementoProtocol
    
    /// 创建当前状态的快照备忘录
    func createMemento() -> Memento
    
    /// 从给定的备忘录快照中恢复状态
    func restoreMemento(_ memento: Memento)
}

/// 归档管理者接口 (Caretaker Protocol)
public protocol ArchiveCaretakerProtocol {
    associatedtype Memento: ArchiveMementoProtocol
    
    /// 保存新的状态快照备忘录
    func saveMemento(_ memento: Memento)
    
    /// 撤销并返回上一个快照备忘录
    func undo() -> Memento?
    
    /// 重做并返回下一个快照备忘录
    func redo() -> Memento?
    
    /// 是否可撤销
    var canUndo: Bool { get }
    
    /// 是否可重做
    var canRedo: Bool { get }
}
