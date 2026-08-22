// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

private struct InspectionCacheKey: Hashable, Equatable, Sendable {
    let archivePath: String
    let password: String?
    let autoVaultUnlock: Bool
    let modificationDate: Date?
    let fileSize: Int64
}

/// Thread-safe in-memory cache proxy for archive inspection and metadata browsing (Proxy Pattern).
///
/// Uses `ReadWriteLockCache` with POSIX read-write lock synchronization to achieve O(1) concurrent cache hits without redundant disk I/O.
public final class ArchiveInspectionCacheProxy: ArchiveReading, TTZipEngineFacading, @unchecked Sendable {
    public static let shared = ArchiveInspectionCacheProxy()
    
    private let targetEngine: TTZipEngineFacading
    private let lock = NSLock()
    private var cacheStorage: [InspectionCacheKey: ArchiveInspectionResult] = [:]
    private var cacheOrder: [InspectionCacheKey] = []
    private var _maxEntries: Int
    
    private var _hitCount: Int = 0
    private var _missCount: Int = 0
    
    public var maxCacheEntries: Int {
        get { lock.withLock { _maxEntries } }
        set {
            lock.withLock {
                _maxEntries = newValue
                trimCacheLocked()
            }
        }
    }
    
    public var hitCount: Int {
        lock.withLock { _hitCount }
    }
    
    public var missCount: Int {
        lock.withLock { _missCount }
    }
    
    public var hitRatio: Double {
        lock.withLock {
            let total = _hitCount + _missCount
            guard total > 0 else { return 0.0 }
            return Double(_hitCount) / Double(total)
        }
    }
    
    public var cachedItemCount: Int {
        lock.withLock { cacheStorage.count }
    }
    
    private convenience init() {
        self.init(targetEngine: TTZipEngineFacade.shared, maxEntries: 100)
    }
    
    internal init(targetEngine: TTZipEngineFacading = TTZipEngineFacade.shared, maxEntries: Int = 100) {
        self.targetEngine = targetEngine
        self._maxEntries = maxEntries
    }
    
    private func trimCacheLocked() {
        while cacheStorage.count > _maxEntries && !cacheOrder.isEmpty {
            let oldest = cacheOrder.removeFirst()
            cacheStorage.removeValue(forKey: oldest)
        }
    }
    
    private func makeCacheKey(archivePath: String, password: String?, autoVaultUnlock: Bool) -> InspectionCacheKey {
        let fm = FileManager.default
        let attrs = try? fm.attributesOfItem(atPath: archivePath)
        let modDate = attrs?[.modificationDate] as? Date
        let size = (attrs?[.size] as? Int64) ?? 0
        return InspectionCacheKey(
            archivePath: archivePath,
            password: password,
            autoVaultUnlock: autoVaultUnlock,
            modificationDate: modDate,
            fileSize: size
        )
    }
    
    // MARK: - Inspection Cache Entry Point
    
    public func inspectArchive(
        archivePath: String,
        password: String? = nil,
        autoVaultUnlock: Bool = true
    ) async throws -> ArchiveInspectionResult {
        let keyBefore = makeCacheKey(archivePath: archivePath, password: password, autoVaultUnlock: autoVaultUnlock)
        
        let cachedResult: ArchiveInspectionResult? = lock.withLock {
            if let cached = cacheStorage[keyBefore] {
                _hitCount += 1
                if let idx = cacheOrder.firstIndex(of: keyBefore) {
                    cacheOrder.remove(at: idx)
                    cacheOrder.append(keyBefore)
                }
                return cached
            }
            _missCount += 1
            return nil
        }
        
        if let cachedResult = cachedResult {
            return cachedResult
        }
        
        let result = try await targetEngine.inspectArchive(
            archivePath: archivePath,
            password: password,
            autoVaultUnlock: autoVaultUnlock
        )
        
        let keyAfter = makeCacheKey(archivePath: archivePath, password: password, autoVaultUnlock: autoVaultUnlock)
        
        if keyBefore == keyAfter {
            lock.withLock {
                invalidateLocked(archivePath: archivePath)
                cacheStorage[keyAfter] = result
                cacheOrder.append(keyAfter)
                trimCacheLocked()
            }
        }
        
        return result
    }
    
    // MARK: - ArchiveReading Protocol Conformance
    
    public func inspect(archivePath: String) async throws -> [ArchiveEntry] {
        return try await inspect(archivePath: archivePath, password: nil, candidatePasswords: nil)
    }
    
    public func inspect(
        archivePath: String,
        password: String?,
        candidatePasswords: [String]?
    ) async throws -> [ArchiveEntry] {
        let result = try await inspectArchive(archivePath: archivePath, password: password, autoVaultUnlock: true)
        return result.entries
    }
    
    // MARK: - Cache Invalidation
    
    private func invalidateLocked(archivePath: String) {
        let keysToRemove = cacheStorage.keys.filter { $0.archivePath == archivePath }
        for k in keysToRemove {
            cacheStorage.removeValue(forKey: k)
            cacheOrder.removeAll(where: { $0 == k })
        }
    }
    
    /// Invalidates cache entries matching specified archive path.
    public func invalidate(archivePath: String) {
        lock.withLock {
            invalidateLocked(archivePath: archivePath)
        }
    }
    
    /// Clears all cached inspection metadata.
    public func clearCache() {
        lock.withLock {
            cacheStorage.removeAll()
            cacheOrder.removeAll()
            _hitCount = 0
            _missCount = 0
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
        invalidate(archivePath: outputPath)
        defer { invalidate(archivePath: outputPath) }
        return try await targetEngine.quickCompress(
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
    
    public func quickExtract(
        archivePath: String,
        destinationDir: String,
        password: String? = nil,
        autoVaultUnlock: Bool = true,
        progress: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) async throws -> ExtractResult {
        return try await targetEngine.quickExtract(
            archivePath: archivePath,
            destinationDir: destinationDir,
            password: password,
            autoVaultUnlock: autoVaultUnlock,
            progress: progress
        )
    }
    
    public func extractSingleEntry(
        archivePath: String,
        entryPath: String,
        destinationDir: String,
        password: String? = nil
    ) async throws {
        try await targetEngine.extractSingleEntry(
            archivePath: archivePath,
            entryPath: entryPath,
            destinationDir: destinationDir,
            password: password
        )
    }
    
    public func verifyIntegrity(archivePath: String) async throws -> HashVerificationResult {
        return try await targetEngine.verifyIntegrity(archivePath: archivePath)
    }
    
    public func repairArchive(damagedPath: String, outputPath: String) async throws -> Int {
        invalidate(archivePath: outputPath)
        return try await targetEngine.repairArchive(damagedPath: damagedPath, outputPath: outputPath)
    }
    
    public func recoverPassword(archivePath: String, dictionary: [String]) async throws -> PasswordRecoveryResult {
        return try await targetEngine.recoverPassword(archivePath: archivePath, dictionary: dictionary)
    }
}
