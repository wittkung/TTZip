import Foundation

/// 单个测试用例执行结果记录
public struct TestCaseRecord: Sendable, Codable {
    public let name: String
    public let className: String
    public let tier: Int
    public let durationSeconds: Double
    public let passed: Bool
    public let failureMessage: String?
    
    public init(
        name: String,
        className: String,
        tier: Int,
        durationSeconds: Double,
        passed: Bool,
        failureMessage: String? = nil
    ) {
        self.name = name
        self.className = className
        self.tier = tier
        self.durationSeconds = durationSeconds
        self.passed = passed
        self.failureMessage = failureMessage
    }
}

/// 完整测试执行会话报告模型
public struct TestSessionReport: Sendable, Codable {
    public let timestamp: TimeInterval
    public let totalTests: Int
    public let passedTests: Int
    public let failedTests: Int
    public let totalDurationSeconds: Double
    public let testCases: [TestCaseRecord]
    
    public init(
        timestamp: TimeInterval = Date().timeIntervalSince1970,
        testCases: [TestCaseRecord] = []
    ) {
        self.timestamp = timestamp
        self.testCases = testCases
        self.totalTests = testCases.count
        self.passedTests = testCases.filter(\.passed).count
        self.failedTests = testCases.filter { !$0.passed }.count
        self.totalDurationSeconds = testCases.reduce(0.0) { $0 + $1.durationSeconds }
    }
    
    public func toJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(self), let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }
}
