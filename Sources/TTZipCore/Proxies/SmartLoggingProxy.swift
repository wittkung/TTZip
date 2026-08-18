// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Audit log record for tracked proxy operations.
public struct SmartLogRecord: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let operationName: String
    public let durationMs: Double
    public let success: Bool
    public let details: String
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        operationName: String,
        durationMs: Double,
        success: Bool,
        details: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.operationName = operationName
        self.durationMs = durationMs
        self.success = success
        self.details = details
    }
}

/// Smart reference counting and timing audit proxy (Smart Proxy Pattern).
///
/// Tracks concurrent active operations and logs detailed latency metrics without mutating underlying engine implementations.
public final class SmartLoggingProxy: TTZipEngineFacading, @unchecked Sendable {
    public static let shared = SmartLoggingProxy()
    
    private let targetEngine: TTZipEngineFacading
    private let lock = NSLock()
    
    private var _activeOperationCount: Int = 0
    private var _peakConcurrentOperations: Int = 0
    private var _totalOperationCount: Int = 0
    private var _logs: [SmartLogRecord] = []
    
    public var activeOperationCount: Int {
        lock.withLock { _activeOperationCount }
    }
    
    public var peakConcurrentOperations: Int {
        lock.withLock { _peakConcurrentOperations }
    }
    
    public var totalOperationCount: Int {
        lock.withLock { _totalOperationCount }
    }
    
    public var logs: [SmartLogRecord] {
        lock.withLock { _logs }
    }
    
    private convenience init() {
        self.init(targetEngine: TTZipEngineFacade.shared)
    }
    
    internal init(targetEngine: TTZipEngineFacading = TTZipEngineFacade.shared) {
        self.targetEngine = targetEngine
    }
    
    // MARK: - Smart Execution Wrapper
    
    public func execute<T: Sendable>(operationName: String, action: () async throws -> T) async rethrows -> T {
        startOperation()
        let start = CFAbsoluteTimeGetCurrent()
        var success = true
        var detailMsg = "OK"
        
        defer {
            let elapsedMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
            endOperation(name: operationName, durationMs: elapsedMs, success: success, details: detailMsg)
        }
        
        do {
            let result = try await action()
            return result
        } catch {
            success = false
            detailMsg = "Error: \(error.localizedDescription)"
            throw error
        }
    }
    
    public func executeSync<T>(operationName: String, action: () throws -> T) rethrows -> T {
        startOperation()
        let start = CFAbsoluteTimeGetCurrent()
        var success = true
        var detailMsg = "OK"
        
        defer {
            let elapsedMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
            endOperation(name: operationName, durationMs: elapsedMs, success: success, details: detailMsg)
        }
        
        do {
            let result = try action()
            return result
        } catch {
            success = false
            detailMsg = "Error: \(error.localizedDescription)"
            throw error
        }
    }
    
    private func startOperation() {
        lock.withLock {
            _activeOperationCount += 1
            _totalOperationCount += 1
            if _activeOperationCount > _peakConcurrentOperations {
                _peakConcurrentOperations = _activeOperationCount
            }
        }
    }
    
    private func endOperation(name: String, durationMs: Double, success: Bool, details: String) {
        lock.withLock {
            _activeOperationCount = max(0, _activeOperationCount - 1)
            let record = SmartLogRecord(
                operationName: name,
                durationMs: durationMs,
                success: success,
                details: details
            )
            _logs.append(record)
            if _logs.count > 600 {
                _logs.removeFirst(_logs.count - 500)
            }
        }
    }
    
    public func clearLogs() {
        lock.withLock {
            _logs.removeAll()
            _activeOperationCount = 0
            _peakConcurrentOperations = 0
            _totalOperationCount = 0
        }
    }
    
    // MARK: - Engine Delegation
    
    public func quickCompress(
        inputs: [String],
        outputPath: String,
        format: ArchiveCompressionFormat = .zip,
        level: ArchiveCompressionLevel = .normal,
        password: String? = nil,
        splitSize: Int64? = nil,
        filterOptions: ArchiveFilterOptions = .defaultClean,
        advancedOptions: ArchiveAdvancedOptions? = nil,
        progress: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) async throws -> ArchiveOperationResult {
        return try await execute(operationName: "quickCompress(\(outputPath))") {
            try await targetEngine.quickCompress(
                inputs: inputs,
                outputPath: outputPath,
                format: format,
                level: level,
                password: password,
                splitSize: splitSize,
                filterOptions: filterOptions,
                advancedOptions: advancedOptions,
                progress: progress
            )
        }
    }
    
    public func quickExtract(
        archivePath: String,
        destinationDir: String,
        password: String? = nil,
        autoVaultUnlock: Bool = true,
        progress: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) async throws -> ExtractResult {
        return try await execute(operationName: "quickExtract(\(archivePath))") {
            try await targetEngine.quickExtract(
                archivePath: archivePath,
                destinationDir: destinationDir,
                password: password,
                autoVaultUnlock: autoVaultUnlock,
                progress: progress
            )
        }
    }
    
    public func extractSingleEntry(
        archivePath: String,
        entryPath: String,
        destinationDir: String,
        password: String? = nil
    ) async throws {
        try await execute(operationName: "extractSingleEntry(\(entryPath))") {
            try await targetEngine.extractSingleEntry(
                archivePath: archivePath,
                entryPath: entryPath,
                destinationDir: destinationDir,
                password: password
            )
        }
    }
    
    public func inspectArchive(
        archivePath: String,
        password: String? = nil,
        autoVaultUnlock: Bool = true
    ) async throws -> ArchiveInspectionResult {
        return try await execute(operationName: "inspectArchive(\(archivePath))") {
            try await targetEngine.inspectArchive(
                archivePath: archivePath,
                password: password,
                autoVaultUnlock: autoVaultUnlock
            )
        }
    }
    
    public func verifyIntegrity(archivePath: String) async throws -> HashVerificationResult {
        return try await execute(operationName: "verifyIntegrity(\(archivePath))") {
            try await targetEngine.verifyIntegrity(archivePath: archivePath)
        }
    }
    
    public func repairArchive(damagedPath: String, outputPath: String) async throws -> Int {
        return try await execute(operationName: "repairArchive(\(damagedPath))") {
            try await targetEngine.repairArchive(damagedPath: damagedPath, outputPath: outputPath)
        }
    }
    
    public func recoverPassword(archivePath: String, dictionary: [String]) async throws -> PasswordRecoveryResult {
        return try await execute(operationName: "recoverPassword(\(archivePath))") {
            try await targetEngine.recoverPassword(archivePath: archivePath, dictionary: dictionary)
        }
    }
}
