import Foundation

/// 密码恢复策略上下文与参数封装
public struct PasswordRecoveryContext: Sendable {
    public let archivePath: String
    public let dictionary: [String]
    public let charset: String
    public let maxBruteForceLength: Int
    
    public init(
        archivePath: String,
        dictionary: [String] = [],
        charset: String = "0123456789abcdefghijklmnopqrstuvwxyz",
        maxBruteForceLength: Int = 4
    ) {
        self.archivePath = archivePath
        self.dictionary = dictionary
        self.charset = charset
        self.maxBruteForceLength = maxBruteForceLength
    }
}

/// 【3.1 策略模式】密码恢复策略统一抽象接口协议
public protocol PasswordRecoveryStrategyProtocol: Sendable {
    /// 策略可读名称
    var strategyName: String { get }
    
    /// 判断在给定 Context 下是否具备执行条件
    func canExecute(context: PasswordRecoveryContext) -> Bool
    
    /// 执行密码比对策略，并在找到正确密码时返回
    func recover(
        context: PasswordRecoveryContext,
        verifier: @Sendable @escaping (String) async -> Bool
    ) async throws -> (foundPassword: String?, attempts: Int64)
}

// MARK: - 具体密码恢复策略实现 (Concrete Password Recovery Strategies)

/// 1. 密码保险库历史优先尝试策略 (`PasswordVaultHistoryStrategy`)
public final class PasswordVaultHistoryStrategy: PasswordRecoveryStrategyProtocol {
    public let strategyName: String = "密码保险库历史匹配策略"
    private let vaultProvider: @Sendable () -> PasswordVaultManaging
    
    public init(vaultProvider: @Sendable @escaping () -> PasswordVaultManaging = { PasswordVaultManager.shared }) {
        self.vaultProvider = vaultProvider
    }
    
    public func canExecute(context: PasswordRecoveryContext) -> Bool {
        return !vaultProvider().getEntries().isEmpty
    }
    
    public func recover(
        context: PasswordRecoveryContext,
        verifier: @Sendable @escaping (String) async -> Bool
    ) async throws -> (foundPassword: String?, attempts: Int64) {
        let entries = vaultProvider().getEntries()
        var attempts: Int64 = 0
        
        for entry in entries {
            attempts += 1
            if await verifier(entry.password) {
                vaultProvider().recordUsage(id: entry.id)
                return (entry.password, attempts)
            }
        }
        
        return (nil, attempts)
    }
}

/// 2. 多核并发字典匹配恢复策略 (`DictionaryRecoveryStrategy`)
public final class DictionaryRecoveryStrategy: PasswordRecoveryStrategyProtocol {
    public let strategyName: String = "多核并行字典破解策略"
    
    public init() {}
    
    public func canExecute(context: PasswordRecoveryContext) -> Bool {
        return !context.dictionary.isEmpty
    }
    
    public func recover(
        context: PasswordRecoveryContext,
        verifier: @Sendable @escaping (String) async -> Bool
    ) async throws -> (foundPassword: String?, attempts: Int64) {
        let dict = context.dictionary
        
        // 小字典无需 TaskGroup 开销，同步单线程快速验证
        if dict.count <= 100 {
            var attempts: Int64 = 0
            for pwd in dict {
                attempts += 1
                if await verifier(pwd) {
                    return (pwd, attempts)
                }
            }
            return (nil, attempts)
        }
        
        // 大字典多核并行验证
        let threads = AppleSiliconTuner.shared.topology.totalCores
        let chunkSize = max(1, dict.count / threads)
        
        var attempts: Int64 = 0
        var found: String? = nil
        
        await withTaskGroup(of: (String?, Int64).self) { group in
            for i in 0..<threads {
                let startIdx = i * chunkSize
                let endIdx = (i == threads - 1) ? dict.count : min(dict.count, (i + 1) * chunkSize)
                if startIdx >= dict.count { continue }
                
                let subDict = Array(dict[startIdx..<endIdx])
                group.addTask {
                    var localAttempts: Int64 = 0
                    for pwd in subDict {
                        if Task.isCancelled { return (nil, localAttempts) }
                        localAttempts += 1
                        if await verifier(pwd) {
                            return (pwd, localAttempts)
                        }
                    }
                    return (nil, localAttempts)
                }
            }
            
            for await (resultPwd, count) in group {
                attempts += count
                if let resultPwd = resultPwd {
                    found = resultPwd
                    group.cancelAll()
                }
                if Task.isCancelled {
                    group.cancelAll()
                }
            }
        }
        
        return (found, attempts)
    }
}

/// 3. 组合字符集多核并发暴力穷举策略 (`BruteForceRecoveryStrategy`)
public final class BruteForceRecoveryStrategy: PasswordRecoveryStrategyProtocol {
    public let strategyName: String = "字符集多核并行暴力穷举策略"
    
    public init() {}
    
    public func canExecute(context: PasswordRecoveryContext) -> Bool {
        // 当提供了有效字符集与穷举长度限制，且 (未提供字典 或 显式指定短穷举) 时执行
        return !context.charset.isEmpty && context.maxBruteForceLength > 0 && (context.dictionary.isEmpty || context.maxBruteForceLength <= 3)
    }
    
    public func recover(
        context: PasswordRecoveryContext,
        verifier: @Sendable @escaping (String) async -> Bool
    ) async throws -> (foundPassword: String?, attempts: Int64) {
        let charset = Array(context.charset)
        guard !charset.isEmpty && context.maxBruteForceLength > 0 else { return (nil, 0) }
        
        var totalAttempts: Int64 = 0
        let maxLen = min(context.maxBruteForceLength, 4)
        let threads = max(1, AppleSiliconTuner.shared.topology.totalCores)
        
        for len in 1...maxLen {
            if Task.isCancelled { break }
            
            if len == 1 || charset.count < threads {
                // 短单字符极小空间快速处理
                var indices = Array(repeating: 0, count: len)
                while true {
                    if Task.isCancelled { break }
                    totalAttempts += 1
                    let candidate = String(indices.map { charset[$0] })
                    if await verifier(candidate) {
                        return (candidate, totalAttempts)
                    }
                    
                    var pos = len - 1
                    while pos >= 0 {
                        indices[pos] += 1
                        if indices[pos] < charset.count { break }
                        indices[pos] = 0
                        pos -= 1
                    }
                    if pos < 0 { break }
                }
            } else {
                // 多核 TaskGroup 空间分片并行穷举
                let chunkSize = max(1, charset.count / threads)
                var foundPwd: String? = nil
                
                await withTaskGroup(of: (String?, Int64).self) { group in
                    for t in 0..<threads {
                        let startFirstIdx = t * chunkSize
                        let endFirstIdx = (t == threads - 1) ? charset.count : min(charset.count, (t + 1) * chunkSize)
                        if startFirstIdx >= charset.count { continue }
                        
                        group.addTask {
                            var localAttempts: Int64 = 0
                            for firstIdx in startFirstIdx..<endFirstIdx {
                                if Task.isCancelled { return (nil, localAttempts) }
                                var indices = Array(repeating: 0, count: len)
                                indices[0] = firstIdx
                                
                                while true {
                                    if Task.isCancelled { return (nil, localAttempts) }
                                    localAttempts += 1
                                    let candidate = String(indices.map { charset[$0] })
                                    if await verifier(candidate) {
                                        return (candidate, localAttempts)
                                    }
                                    
                                    var pos = len - 1
                                    while pos >= 1 {
                                        indices[pos] += 1
                                        if indices[pos] < charset.count { break }
                                        indices[pos] = 0
                                        pos -= 1
                                    }
                                    if pos < 1 { break }
                                }
                            }
                            return (nil, localAttempts)
                        }
                    }
                    
                    for await (pwd, count) in group {
                        totalAttempts += count
                        if let pwd = pwd {
                            foundPwd = pwd
                            group.cancelAll()
                        }
                        if Task.isCancelled {
                            group.cancelAll()
                        }
                    }
                }
                
                if let foundPwd = foundPwd {
                    return (foundPwd, totalAttempts)
                }
            }
        }
        
        return (nil, totalAttempts)
    }
}

// MARK: - Strategy Executor & Context (密码恢复策略链执行器)

/// 密码恢复策略调配执行器 (`PasswordRecoveryStrategyExecutor`)
public final class PasswordRecoveryStrategyExecutor: @unchecked Sendable {
    public static let shared = PasswordRecoveryStrategyExecutor()
    private let lock = NSLock()
    private var strategies: [PasswordRecoveryStrategyProtocol] = []
    
    private convenience init() {
        self.init(registerDefaults: true)
    }

    internal init(registerDefaults: Bool = true) {
        if registerDefaults {
            registerDefaultStrategies()
        }
    }
    
    private func registerDefaultStrategies() {
        strategies = [
            PasswordVaultHistoryStrategy(),
            DictionaryRecoveryStrategy(),
            BruteForceRecoveryStrategy()
        ]
    }
    
    public func register(strategy: PasswordRecoveryStrategyProtocol) {
        lock.lock()
        defer { lock.unlock() }
        strategies.append(strategy)
    }
    
    private func getStrategies() -> [PasswordRecoveryStrategyProtocol] {
        lock.lock()
        defer { lock.unlock() }
        return strategies
    }
    
    /// 按策略链优先级依次执行密码破解与恢复
    public func recoverPassword(
        context: PasswordRecoveryContext,
        verifier: @Sendable @escaping (String) async -> Bool
    ) async throws -> PasswordRecoveryResult {
        let startTime = Date()
        var accumulatedAttempts: Int64 = 0
        
        let currentStrategies = getStrategies()
        
        for strategy in currentStrategies {
            guard strategy.canExecute(context: context) else { continue }
            let (foundPwd, attempts) = try await strategy.recover(context: context, verifier: verifier)
            accumulatedAttempts += attempts
            
            if let pwd = foundPwd {
                let duration = max(0.001, Date().timeIntervalSince(startTime))
                return PasswordRecoveryResult(
                    foundPassword: pwd,
                    totalAttempts: accumulatedAttempts,
                    durationSeconds: duration
                )
            }
        }
        
        let duration = max(0.001, Date().timeIntervalSince(startTime))
        return PasswordRecoveryResult(
            foundPassword: nil,
            totalAttempts: accumulatedAttempts,
            durationSeconds: duration
        )
    }
}
