import Foundation
import os

/// 线程安全的测试日志收集器与 POSIX 原子刷新中枢 (Atomic Chunk Flush)
///
/// 在测试执行期间将日志捕获于内存会话中。
/// - 成功用例：内存静默清空，终端 0 噪音；
/// - 失败用例：单次原子输出完整证据链，100% 杜绝多线程测试输出交织。
public final class TestLogCollector: @unchecked Sendable {
    public static let shared = TestLogCollector()
    
    private var lock = os_unfair_lock_s()
    private var sessionBuffers: [String: [String]] = [:]
    
    @TaskLocal
    public static var currentSessionID: String?
    
    private init() {}
    
    /// 向指定会话追加日志
    public func record(sessionID: String, message: String) {
        os_unfair_lock_lock(&lock)
        sessionBuffers[sessionID, default: []].append(message)
        os_unfair_lock_unlock(&lock)
    }
    
    /// 向当前 TaskLocal 会话追加日志（若有）
    public func recordCurrent(message: String) {
        guard let sid = Self.currentSessionID else { return }
        record(sessionID: sid, message: message)
    }
    
    /// 测试通过时静默清空会话内存
    public func clear(sessionID: String) {
        os_unfair_lock_lock(&lock)
        sessionBuffers.removeValue(forKey: sessionID)
        os_unfair_lock_unlock(&lock)
    }
    
    /// 测试失败时原子化刷新完整诊断报告到标准输出
    public func flushOnFailure(sessionID: String, failureHeader: String) {
        os_unfair_lock_lock(&lock)
        let logs = sessionBuffers.removeValue(forKey: sessionID) ?? []
        os_unfair_lock_unlock(&lock)
        
        var output = "\n"
        output += "==========================================================================================\n"
        output += "🚨 \u{001B}[1;31m[TEST FAILURE REPORT]\u{001B}[0m Session: \(sessionID)\n"
        output += "------------------------------------------------------------------------------------------\n"
        output += failureHeader + "\n"
        
        if !logs.isEmpty {
            output += "------------------------------------- Captured Logs --------------------------------------\n"
            for log in logs {
                output += "  " + log + "\n"
            }
        }
        output += "==========================================================================================\n\n"
        
        // POSIX 原子文件锁刷新，杜绝多线程日志撕裂
        flockfile(stdout)
        fputs(output, stdout)
        fflush(stdout)
        funlockfile(stdout)
    }
    
    /// 获取当前缓冲区日志快照（供生成 Markdown / JSON 报告使用）
    public func getCapturedLogs(sessionID: String) -> [String] {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return sessionBuffers[sessionID] ?? []
    }
}
