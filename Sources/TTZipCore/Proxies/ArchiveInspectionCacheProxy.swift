import Foundation

/// 归档元数据缓存键结构
private struct InspectionCacheKey: Hashable, Equatable, Sendable {
    let archivePath: String
    let password: String?
    let autoVaultUnlock: Bool
    let modificationDate: Date?
    let fileSize: Int64
}

/// 【2.7 代理模式 (Proxy Pattern)】缓存代理 (Cache Proxy)
/// `ArchiveInspectionCacheProxy` 为高频调用的 `inspectArchive` 与目录树扫描建立热内存缓存代理
/// 结合 ReadWriteLockCache 实现 POSIX 读写锁保护的高并发 O(1) LRU 缓存，避免重复读盘与 C 库重解析
public final class ArchiveInspectionCacheProxy: ArchiveReading, TTZipEngineFacading, @unchecked Sendable {
    public static let shared = ArchiveInspectionCacheProxy()
    
    private let targetEngine: TTZipEngineFacading
    private let cache: ReadWriteLockCache<InspectionCacheKey, ArchiveInspectionResult>
    private let statsLock = POSIXReadWriteLock()
    
    private var _hitCount: Int = 0
    private var _missCount: Int = 0
    
    public var maxCacheEntries: Int {
        get { cache.maxEntries ?? 100 }
        set { cache.maxEntries = newValue }
    }
    
    public var hitCount: Int {
        statsLock.withReadLock { _hitCount }
    }
    
    public var missCount: Int {
        statsLock.withReadLock { _missCount }
    }
    
    public var hitRatio: Double {
        statsLock.withReadLock {
            let total = _hitCount + _missCount
            guard total > 0 else { return 0.0 }
            return Double(_hitCount) / Double(total)
        }
    }
    
    public var cachedItemCount: Int {
        cache.count
    }
    
    private convenience init() {
        self.init(targetEngine: TTZipEngineFacade.shared, maxEntries: 100)
    }
    
    internal init(targetEngine: TTZipEngineFacading = TTZipEngineFacade.shared, maxEntries: Int = 100) {
        self.targetEngine = targetEngine
        self.cache = ReadWriteLockCache(policy: .lru(maxEntries: maxEntries))
    }
    
    // MARK: - 辅助：构建磁盘文件特征 Cache Key
    
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
    
    // MARK: - 1. 缓存代理主入口 inspectArchive (Cache Proxy Entrance)
    
    public func inspectArchive(
        archivePath: String,
        password: String? = nil,
        autoVaultUnlock: Bool = true
    ) async throws -> ArchiveInspectionResult {
        let keyBefore = makeCacheKey(archivePath: archivePath, password: password, autoVaultUnlock: autoVaultUnlock)
        
        if let cached = cache.value(forKey: keyBefore) {
            statsLock.withWriteLock { _hitCount += 1 }
            return cached
        }
        
        statsLock.withWriteLock { _missCount += 1 }
        
        // 缓存未命中，调用真实目标引擎解析
        let result = try await targetEngine.inspectArchive(
            archivePath: archivePath,
            password: password,
            autoVaultUnlock: autoVaultUnlock
        )
        
        // 乐观并发校验：在调用 targetEngine.inspectArchive 期间，磁盘文件是否被并发 Task 修改
        let keyAfter = makeCacheKey(archivePath: archivePath, password: password, autoVaultUnlock: autoVaultUnlock)
        
        if keyBefore == keyAfter {
            invalidate(archivePath: archivePath)
            cache.setValue(result, forKey: keyAfter)
        }
        
        return result
    }
    
    // MARK: - 2. ArchiveReading 协议适配 (Protocol Conformance)
    
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
    
    // MARK: - 3. 缓存失效与清理 API
    
    /// 手动清空指定路径的缓存记录 (文件修改/删除时使用)
    public func invalidate(archivePath: String) {
        cache.removeAll { $0.archivePath == archivePath }
    }
    
    /// 清空全部热内存缓存
    public func clearCache() {
        cache.removeAll()
        statsLock.withWriteLock {
            _hitCount = 0
            _missCount = 0
        }
    }
    
    // MARK: - 4. 其他门面透传方法
    
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
        // 压缩生成新文件可能覆盖旧输出包，操作前后双重失效相关缓存，杜绝并发竞争残留脏数据
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
