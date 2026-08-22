// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Password recovery execution parameters and context.
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

/// Abstract password recovery strategy interface (Strategy Pattern).
public protocol PasswordRecoveryStrategyProtocol: Sendable {
    var strategyName: String { get }
    func canExecute(context: PasswordRecoveryContext) -> Bool
    func recover(
        context: PasswordRecoveryContext,
        verifier: @Sendable @escaping (String) async -> Bool
    ) async throws -> (foundPassword: String?, attempts: Int64)
}

// MARK: - Concrete Password Recovery Strategies

/// 1. Password vault history candidate matching strategy (`PasswordVaultHistoryStrategy`).
public final class PasswordVaultHistoryStrategy: PasswordRecoveryStrategyProtocol {
    public let strategyName: String = "Password Vault History Strategy"
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

/// 2. Multi-core parallel dictionary recovery strategy (`DictionaryRecoveryStrategy`).
public final class DictionaryRecoveryStrategy: PasswordRecoveryStrategyProtocol {
    public let strategyName: String = "Parallel Dictionary Recovery Strategy"
    
    public init() {}
    
    public func canExecute(context: PasswordRecoveryContext) -> Bool {
        return !context.dictionary.isEmpty
    }
    
    public func recover(
        context: PasswordRecoveryContext,
        verifier: @Sendable @escaping (String) async -> Bool
    ) async throws -> (foundPassword: String?, attempts: Int64) {
        let dict = context.dictionary
        if FileManager.default.fileExists(atPath: context.archivePath) {
            if let rustFound = PasswordRecoveryEngine.recoverFastInMemory(passwords: dict, archivePath: context.archivePath) {
                let attempts = Int64(dict.firstIndex(of: rustFound).map { $0 + 1 } ?? dict.count)
                return (rustFound, attempts)
            }
        }
        
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
        
        let threads = max(1, AppleSiliconTuner.shared.topology.totalCores)
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

/// 3. Multi-core combinatoric brute force search strategy (`BruteForceRecoveryStrategy`).
public final class BruteForceRecoveryStrategy: PasswordRecoveryStrategyProtocol {
    public let strategyName: String = "Parallel Brute Force Search Strategy"
    
    public init() {}
    
    public func canExecute(context: PasswordRecoveryContext) -> Bool {
        return !context.charset.isEmpty && context.maxBruteForceLength > 0 && (context.dictionary.isEmpty || context.maxBruteForceLength <= 3)
    }
    
    public func recover(
        context: PasswordRecoveryContext,
        verifier: @Sendable @escaping (String) async -> Bool
    ) async throws -> (foundPassword: String?, attempts: Int64) {
        let charset = Array(context.charset)
        guard !charset.isEmpty && context.maxBruteForceLength > 0 else { return (nil, 0) }
        
        if FileManager.default.fileExists(atPath: context.archivePath) {
            var outFound = [CChar](repeating: 0, count: 256)
            var rustAttempts: UInt64 = 0
            let status = CUnsafeBufferAdapter.withCString(context.archivePath) { cPath in
                CUnsafeBufferAdapter.withCString(context.charset) { cCharset in
                    guard let cPath = cPath, let cCharset = cCharset else { return TTZIP_STATUS_ERR_INVALID_PARAM }
                    return ttzip_rust_password_recovery_start_brute_force(
                        cPath,
                        cCharset,
                        1,
                        min(context.maxBruteForceLength, 4),
                        nil,
                        &outFound,
                        outFound.count,
                        &rustAttempts
                    )
                }
            }
            if status == TTZIP_STATUS_OK {
                let foundStr = outFound.withUnsafeBufferPointer { ptr in
                    ptr.baseAddress.map { String(cString: $0) }
                }
                return (foundStr, Int64(rustAttempts))
            }
        }
        
        var totalAttempts: Int64 = 0
        let maxLen = min(context.maxBruteForceLength, 4)
        let threads = max(1, AppleSiliconTuner.shared.topology.totalCores)
        
        for len in 1...maxLen {
            if Task.isCancelled { break }
            
            if len == 1 || charset.count < threads {
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

// MARK: - Strategy Executor

/// Coordinator executing password recovery strategies in prioritized sequence.
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
