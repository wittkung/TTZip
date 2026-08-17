import Foundation

/// 对标 libarchive `failure()` 的延迟失败上下文注入中枢
///
/// 在断言执行前注入意图描述。在断言通过时零字符串格式化与 I/O 开销；
/// 仅在断言失败时被消费并输出到诊断报告中。
public enum DiagnosticContext: Sendable {
    
    @TaskLocal
    private static var taskLocalPendingMessage: String?
    
    private static let lock = NSLock()
    nonisolated(unsafe) private static var threadLocalPendingMessages: [UInt64: String] = [:]

    
    /// 注册一条延迟失败消息。如果下一次断言失败，该消息将作为失败描述输出；若断言通过，则在下次断言时被无害丢弃。
    public static func failure(_ message: String) {
        if taskLocalPendingMessage != nil {
            // TaskLocal active in current async context
            return
        }
        var tid: UInt64 = 0
        pthread_threadid_np(nil, &tid)
        lock.lock()
        threadLocalPendingMessages[tid] = message
        lock.unlock()
    }
    
    /// 在异步闭包作用域内绑定延迟失败消息
    public static func withFailureMessage<R>(_ message: String, operation: () throws -> R) rethrows -> R {
        try $taskLocalPendingMessage.withValue(message) {
            try operation()
        }
    }
    
    /// 异步作用域绑定
    public static func withFailureMessage<R>(_ message: String, operation: () async throws -> R) async rethrows -> R {
        try await $taskLocalPendingMessage.withValue(message) {
            try await operation()
        }
    }
    
    /// 消费并清空当前线程/Task 挂起的延迟失败消息
    public static func consumePendingMessage() -> String? {
        if let msg = taskLocalPendingMessage {
            return msg
        }
        var tid: UInt64 = 0
        pthread_threadid_np(nil, &tid)
        lock.lock()
        defer { lock.unlock() }
        return threadLocalPendingMessages.removeValue(forKey: tid)
    }
    
    /// 清空挂起消息
    public static func clear() {
        var tid: UInt64 = 0
        pthread_threadid_np(nil, &tid)
        lock.lock()
        threadLocalPendingMessages.removeValue(forKey: tid)
        lock.unlock()
    }
}
