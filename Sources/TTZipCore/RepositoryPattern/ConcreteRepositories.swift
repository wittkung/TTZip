import Foundation
import Security

// MARK: - 1. UserDefaultsPresetRepository

/// 基于 UserDefaults + PresetDataMapper 的预设仓储具体实现
public final class UserDefaultsPresetRepository: ArchivePresetRepositoryProtocol, @unchecked Sendable {
    public typealias DomainModel = CompressionPreset
    
    private let userDefaults: UserDefaults
    private let storageKey: String
    private let mapper: PresetDataMapper
    private let rwLock = POSIXReadWriteLock()
    private var cachedDTOs: [PresetStorageDTO] = []
    
    public init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "TTZip_User_Compression_Presets_v3",
        mapper: PresetDataMapper = PresetDataMapper()
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        self.mapper = mapper
        loadFromStorageLocked()
    }
    
    private func loadFromStorageLocked() {
        rwLock.withWriteLock {
            guard let data = userDefaults.data(forKey: storageKey) else {
                // 初次加载或无缓存：使用默认预设转换为 DTO 存盘
                let defaults = PresetManager.defaultBuiltInPresets.map { mapper.toStorage(domain: $0) }
                self.cachedDTOs = defaults
                saveToStorageLocked()
                return
            }
            
            do {
                let decoded = try JSONDecoder().decode([PresetStorageDTO].self, from: data)
                if decoded.isEmpty {
                    let defaults = PresetManager.defaultBuiltInPresets.map { mapper.toStorage(domain: $0) }
                    self.cachedDTOs = defaults
                    saveToStorageLocked()
                } else {
                    self.cachedDTOs = decoded
                }
            } catch {
                // Safe Fallback: 存储损坏容错降级
                TTLogger.warning("⚠️ [UserDefaultsPresetRepository] 预设存储损坏，启用 Safe Fallback 恢复默认预设")
                let defaults = PresetManager.defaultBuiltInPresets.map { mapper.toStorage(domain: $0) }
                self.cachedDTOs = defaults
                saveToStorageLocked()
            }
        }
    }
    
    private func saveToStorageLocked() {
        if let encoded = try? JSONEncoder().encode(cachedDTOs) {
            userDefaults.set(encoded, forKey: storageKey)
        }
    }
    
    public func fetch(id: UUID) throws -> CompressionPreset? {
        return rwLock.withReadLock {
            guard let dto = cachedDTOs.first(where: { $0.presetId == id.uuidString }) else { return nil }
            return mapper.toDomain(storage: dto)
        }
    }
    
    public func fetchAll() throws -> [CompressionPreset] {
        return rwLock.withReadLock {
            cachedDTOs.map { mapper.toDomain(storage: $0) }
        }
    }
    
    public func save(_ entity: CompressionPreset) throws {
        rwLock.withWriteLock {
            let dto = mapper.toStorage(domain: entity)
            if let index = cachedDTOs.firstIndex(where: { $0.presetId == dto.presetId }) {
                cachedDTOs[index] = dto
            } else {
                cachedDTOs.append(dto)
            }
            saveToStorageLocked()
        }
    }
    
    public func delete(id: UUID) throws {
        rwLock.withWriteLock {
            cachedDTOs.removeAll { $0.presetId == id.uuidString }
            saveToStorageLocked()
        }
    }
    
    public func deleteAll() throws {
        rwLock.withWriteLock {
            cachedDTOs.removeAll()
            userDefaults.removeObject(forKey: storageKey)
        }
    }
    
    public func fetchByName(_ name: String) throws -> CompressionPreset? {
        return rwLock.withReadLock {
            guard let dto = cachedDTOs.first(where: { $0.titleName == name }) else { return nil }
            return mapper.toDomain(storage: dto)
        }
    }
    
    public func resetToDefaults() throws {
        rwLock.withWriteLock {
            let defaults = PresetManager.defaultBuiltInPresets.map { mapper.toStorage(domain: $0) }
            self.cachedDTOs = defaults
            saveToStorageLocked()
        }
    }
    
    public func duplicate(id: UUID, newName: String?) throws -> CompressionPreset? {
        return rwLock.withWriteLock { () -> CompressionPreset? in
            guard let targetIndex = cachedDTOs.firstIndex(where: { $0.presetId == id.uuidString }) else {
                return nil
            }
            let targetDomain = mapper.toDomain(storage: cachedDTOs[targetIndex])
            let defaultName = newName ?? "\(targetDomain.name) 副本"
            let clonedDomain = targetDomain.clone(newId: UUID(), newName: defaultName)
            
            let clonedDTO = mapper.toStorage(domain: clonedDomain)
            cachedDTOs.append(clonedDTO)
            saveToStorageLocked()
            
            return clonedDomain
        }
    }
}

// MARK: - 2. KeychainPasswordRepository

/// 基于 macOS Keychain C API + KeychainDataMapper 的密码库安全仓储具体实现
public final class KeychainPasswordRepository: PasswordVaultRepositoryProtocol, @unchecked Sendable {
    public typealias DomainModel = PasswordVaultEntry
    
    public static let shared = KeychainPasswordRepository()
    
    private let vaultManager: PasswordVaultManager
    private let mapper: KeychainDataMapper
    private let nsLock = NSLock()
    
    internal init(
        vaultManager: PasswordVaultManager = .shared,
        mapper: KeychainDataMapper = KeychainDataMapper()
    ) {
        self.vaultManager = vaultManager
        self.mapper = mapper
    }
    
    public var isUnlocked: Bool {
        return vaultManager.isUnlocked
    }
    
    public func unlock(masterPassword: String) throws -> Bool {
        return vaultManager.unlockVault(with: masterPassword)
    }
    
    public func lock() {
        vaultManager.lockVault()
    }
    
    public func fetch(id: UUID) throws -> PasswordVaultEntry? {
        return nsLock.withLock {
            let entries = vaultManager.getEntries()
            guard let entry = entries.first(where: { $0.id == id }) else { return nil }
            let dto = mapper.toStorage(domain: entry)
            return mapper.toDomain(storage: dto)
        }
    }
    
    public func fetchAll() throws -> [PasswordVaultEntry] {
        return nsLock.withLock {
            let entries = vaultManager.getEntries()
            return entries.map { entry in
                let dto = mapper.toStorage(domain: entry)
                return mapper.toDomain(storage: dto)
            }
        }
    }
    
    public func save(_ entity: PasswordVaultEntry) throws {
        nsLock.withLock {
            vaultManager.addEntry(id: entity.id, label: entity.label, password: entity.password, category: entity.category)
        }
    }
    
    public func delete(id: UUID) throws {
        nsLock.withLock {
            vaultManager.removeEntry(id: id)
        }
    }
    
    public func deleteAll() throws {
        nsLock.withLock {
            let all = vaultManager.getEntries()
            for item in all {
                vaultManager.removeEntry(id: item.id)
            }
        }
    }
    
    public func search(category: String) throws -> [PasswordVaultEntry] {
        return nsLock.withLock {
            let all = vaultManager.getEntries()
            let filtered = all.filter { $0.category == category }
            return filtered.map { mapper.toDomain(storage: mapper.toStorage(domain: $0)) }
        }
    }
    
    public func recordUsage(id: UUID) throws {
        nsLock.withLock {
            vaultManager.recordUsage(id: id)
        }
    }
}

// MARK: - 3. JSONFileArchiveHistoryRepository

/// 基于 ~/Library/Caches/TTZip/History/history.json + ArchiveHistoryDataMapper 的归档历史记录仓储
public final class JSONFileArchiveHistoryRepository: ArchiveHistoryRepositoryProtocol, @unchecked Sendable {
    public typealias DomainModel = ArchiveTaskRecord
    
    private let historyFileURL: URL
    private let mapper: ArchiveHistoryDataMapper
    private let rwLock = POSIXReadWriteLock()
    private var memoryCacheDTOs: [HistoryJSONDTO] = []
    
    public init(
        customFileURL: URL? = nil,
        mapper: ArchiveHistoryDataMapper = ArchiveHistoryDataMapper()
    ) {
        if let custom = customFileURL {
            self.historyFileURL = custom
        } else {
            let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            let historyDir = cachesDir.appendingPathComponent("TTZip/History", isDirectory: true)
            try? FileManager.default.createDirectory(at: historyDir, withIntermediateDirectories: true)
            self.historyFileURL = historyDir.appendingPathComponent("history.json")
        }
        self.mapper = mapper
        loadFromDiskLocked()
    }
    
    private func loadFromDiskLocked() {
        rwLock.withWriteLock {
            guard FileManager.default.fileExists(atPath: historyFileURL.path) else {
                self.memoryCacheDTOs = []
                return
            }
            
            do {
                let data = try Data(contentsOf: historyFileURL)
                let decoded = try JSONDecoder().decode([HistoryJSONDTO].self, from: data)
                self.memoryCacheDTOs = decoded
            } catch {
                // Safe Fallback: 历史记录文件损坏容错处理
                TTLogger.warning("⚠️ [JSONFileArchiveHistoryRepository] 历史记录文件损坏，启动 Safe Fallback 保护并归零内存缓存")
                self.memoryCacheDTOs = []
            }
        }
    }
    
    private func saveToDiskLocked() {
        do {
            let parentDir = historyFileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(memoryCacheDTOs)
            try data.write(to: historyFileURL, options: .atomic)
        } catch {
            TTLogger.error("❌ [JSONFileArchiveHistoryRepository] 保存历史记录到磁盘失败: \(error.localizedDescription)")
        }
    }
    
    public func fetch(id: UUID) throws -> ArchiveTaskRecord? {
        return rwLock.withReadLock {
            guard let dto = memoryCacheDTOs.first(where: { $0.recordId == id.uuidString }) else { return nil }
            return mapper.toDomain(storage: dto)
        }
    }
    
    public func fetchAll() throws -> [ArchiveTaskRecord] {
        return rwLock.withReadLock {
            memoryCacheDTOs.map { mapper.toDomain(storage: $0) }
        }
    }
    
    public func save(_ entity: ArchiveTaskRecord) throws {
        rwLock.withWriteLock {
            let dto = mapper.toStorage(domain: entity)
            if let idx = memoryCacheDTOs.firstIndex(where: { $0.recordId == dto.recordId }) {
                memoryCacheDTOs[idx] = dto
            } else {
                memoryCacheDTOs.append(dto)
            }
            saveToDiskLocked()
        }
    }
    
    public func delete(id: UUID) throws {
        rwLock.withWriteLock {
            memoryCacheDTOs.removeAll { $0.recordId == id.uuidString }
            saveToDiskLocked()
        }
    }
    
    public func deleteAll() throws {
        rwLock.withWriteLock {
            memoryCacheDTOs.removeAll()
            try? FileManager.default.removeItem(at: historyFileURL)
        }
    }
    
    public func fetchRecent(limit: Int) throws -> [ArchiveTaskRecord] {
        return rwLock.withReadLock {
            let sorted = memoryCacheDTOs.sorted { $0.dateEpoch > $1.dateEpoch }
            let prefix = Array(sorted.prefix(limit))
            return prefix.map { mapper.toDomain(storage: $0) }
        }
    }
    
    public func fetchByStatus(isSuccess: Bool) throws -> [ArchiveTaskRecord] {
        return rwLock.withReadLock {
            let targetFlag = isSuccess ? "SUCCESS" : "FAILURE"
            let filtered = memoryCacheDTOs.filter { $0.statusFlag.uppercased() == targetFlag }
            return filtered.map { mapper.toDomain(storage: $0) }
        }
    }
}
