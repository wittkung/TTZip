import Foundation

/// 高频事件与进度通知节流调度器
/// 基于单调时钟时间戳门控 (Monotonic Timestamp Gate)，对每秒成千上万次的高频引擎事件进行刷新率对齐节流
public final class ThrottledProgressPublisher: @unchecked Sendable {
    public let intervalNanoseconds: UInt64
    private let lock = NSLock()
    private var lastEmittedTimestamp: UInt64 = 0
    
    /// 初始化节流器
    /// - Parameter maxFrequencyHz: 最大允许发射频率 (Hz)，默认 60.0Hz (约 16.6ms 间隔)
    public init(maxFrequencyHz: Double = 60.0) {
        let clampedHz = max(1.0, min(120.0, maxFrequencyHz))
        self.intervalNanoseconds = UInt64(1_000_000_000.0 / clampedHz)
    }
    
    /// 评估当前时钟是否允许发射新一帧 UI 更新
    /// - Parameter now: 当前单调时间戳 (纳秒)，默认当前 uptime
    /// - Returns: true 表示允许放行并记录当前时间戳；false 表示被节流丢弃
    public func shouldEmit(now: UInt64 = DispatchTime.now().uptimeNanoseconds) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        if lastEmittedTimestamp == 0 || (now >= lastEmittedTimestamp && (now - lastEmittedTimestamp) >= intervalNanoseconds) {
            lastEmittedTimestamp = now
            return true
        }
        return false
    }
    
    /// 强制更新时钟放行（常用于任务完成、错误或首尾帧事件）
    public func forceEmit(now: UInt64 = DispatchTime.now().uptimeNanoseconds) {
        lock.lock()
        defer { lock.unlock() }
        lastEmittedTimestamp = now
    }
    
    /// 重置节流状态
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        lastEmittedTimestamp = 0
    }
}
