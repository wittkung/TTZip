import Foundation

/// 【3.5 状态模式 (State Pattern)】归档任务状态异常定义
public enum ArchiveStateError: Error, LocalizedError, Equatable {
    case invalidTransition(from: String, action: String)
    case taskAlreadyCompleted
    case taskAlreadyFailed(reason: String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidTransition(let from, let action):
            return "非法状态转换: 无法在 '\(from)' 状态下执行 '\(action)' 操作"
        case .taskAlreadyCompleted:
            return "任务已处于完成终态，无法重置或修改"
        case .taskAlreadyFailed(let reason):
            return "任务已处于失败终态 (\(reason))，无法重置或修改"
        }
    }
}

/// 归档任务运行指标与统计数据
public struct TaskMetrics: Sendable, Equatable {
    public var startTime: Date?
    public var endTime: Date?
    public var pauseDuration: TimeInterval
    public var processedBytes: Int64
    public var totalBytes: Int64
    public var throughputMBs: Double
    
    public var durationSeconds: TimeInterval {
        guard let start = startTime else { return 0 }
        let end = endTime ?? Date()
        let cleanPause = max(0, pauseDuration)
        return max(0, end.timeIntervalSince(start) - cleanPause)
    }
    
    /// 进度完成比例 (0.0 ... 1.0)，防除零及超越保护
    public var progressFraction: Double {
        guard totalBytes > 0 else { return 0.0 }
        let raw = Double(processedBytes) / Double(totalBytes)
        return min(1.0, max(0.0, raw))
    }
    
    public init(
        startTime: Date? = nil,
        endTime: Date? = nil,
        pauseDuration: TimeInterval = 0,
        processedBytes: Int64 = 0,
        totalBytes: Int64 = 0,
        throughputMBs: Double = 0.0
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.pauseDuration = max(0, pauseDuration)
        self.processedBytes = max(0, processedBytes)
        self.totalBytes = max(0, totalBytes)
        self.throughputMBs = max(0.0, throughputMBs)
    }
}

/// 【3.5 状态模式 (State Pattern)】归档任务状态抽象接口
public protocol ArchiveTaskStateProtocol: Sendable {
    /// 状态名称描述
    var stateName: String { get }
    
    /// 当前状态下是否可暂停
    var canPause: Bool { get }
    
    /// 当前状态下是否可恢复/续传
    var canResume: Bool { get }
    
    /// 当前状态下是否可取消
    var canCancel: Bool { get }
    
    /// 触发暂停操作
    func pause(context: ArchiveTaskContext) throws
    
    /// 触发恢复操作
    func resume(context: ArchiveTaskContext) throws
    
    /// 触发取消操作
    func cancel(context: ArchiveTaskContext) throws
    
    /// 触发失败终止操作
    func fail(context: ArchiveTaskContext, error: Error) throws
    
    /// 触发完成终态操作
    func complete(context: ArchiveTaskContext) throws
}
