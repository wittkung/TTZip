import Foundation

/// 任务优先级枚举 (Task Priority Level)
/// 遵循 Comparable 协议，优先级顺序：.critical > .userInitiated > .utility > .background
public enum TaskPriorityLevel: Int, Comparable, Sendable, CaseIterable, Hashable, Codable {
    case background = 1
    case utility = 2
    case userInitiated = 3
    case critical = 4

    public static func < (lhs: TaskPriorityLevel, rhs: TaskPriorityLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// 归档并发任务单元规范接口
public protocol ArchiveWorkItemProtocol: Sendable {
    /// 任务唯一标识符
    var itemID: String { get }
    /// 任务优先级
    var priority: TaskPriorityLevel { get }
    /// 执行任务主体
    func execute() async throws -> any Sendable
}

/// 标准可执行任务单元结构体
public struct ArchiveWorkItem: ArchiveWorkItemProtocol {
    public let itemID: String
    public let priority: TaskPriorityLevel
    private let taskBlock: @Sendable () async throws -> any Sendable

    public init(
        itemID: String = UUID().uuidString,
        priority: TaskPriorityLevel = .userInitiated,
        block: @escaping @Sendable () async throws -> any Sendable
    ) {
        self.itemID = itemID
        self.priority = priority
        self.taskBlock = block
    }

    public func execute() async throws -> any Sendable {
        return try await taskBlock()
    }
}

/// 线程池与调度器生命周期状态
public enum WorkerPoolState: String, Sendable, Equatable, Hashable, Codable {
    case idle
    case running
    case paused
    case draining
    case shutdown
}
