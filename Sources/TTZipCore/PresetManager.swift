import Foundation

/// 自定义压缩预设持久化管理单例（集成 Pattern 4.4 仓储与数据映射模式）
public final class PresetManager: @unchecked Sendable {
    public static let shared = PresetManager()
    
    private var repository: any ArchivePresetRepositoryProtocol
    private var cachedPresets: [CompressionPreset] = []
    private let rwLock = POSIXReadWriteLock()
    private let presetCache = ReadWriteLockCache<UUID, CompressionPreset>(policy: .lru(maxEntries: 100))
    
    private init() {
        self.repository = UserDefaultsPresetRepository()
        loadPresets()
    }
    
    internal init(repository: any ArchivePresetRepositoryProtocol) {
        self.repository = repository
        loadPresets()
    }
    
    public var presets: [CompressionPreset] {
        rwLock.withReadLock {
            cachedPresets
        }
    }
    
    public func preset(for id: UUID) -> CompressionPreset? {
        if let cached = presetCache.value(forKey: id) {
            return cached
        }
        return rwLock.withReadLock {
            guard let found = cachedPresets.first(where: { $0.id == id }) else { return nil }
            presetCache.setValue(found, forKey: id)
            return found
        }
    }
    
    public func loadPresets() {
        rwLock.withWriteLock {
            presetCache.removeAll()
            if let list = try? repository.fetchAll(), !list.isEmpty {
                self.cachedPresets = list
            } else {
                self.cachedPresets = PresetManager.defaultBuiltInPresets
                syncRepositoryLocked()
            }
        }
    }
    
    public func savePreset(_ preset: CompressionPreset) {
        let oldName = rwLock.withWriteLock { () -> String? in
            presetCache.removeAll()
            let old = cachedPresets.first(where: { $0.id == preset.id })?.name
            if let index = cachedPresets.firstIndex(where: { $0.id == preset.id }) {
                cachedPresets[index] = preset
            } else {
                cachedPresets.append(preset)
            }
            try? repository.save(preset)
            return old
        }
        ArchiveEventCenter.shared.postPresetChanged(oldPresetName: oldName, newPresetName: preset.name)
    }
    
    public func deletePreset(id: UUID) {
        let deletedName = rwLock.withWriteLock { () -> String? in
            presetCache.removeAll()
            let deleted = cachedPresets.first(where: { $0.id == id })
            cachedPresets.removeAll(where: { $0.id == id })
            try? repository.delete(id: id)
            return deleted?.name
        }
        if let name = deletedName {
            ArchiveEventCenter.shared.postPresetChanged(oldPresetName: name, newPresetName: "<Deleted>")
        }
    }
    
    /// 基于原型模式 (Prototype Pattern) 克隆/衍生预设方案
    @discardableResult
    public func duplicatePreset(id: UUID, newName: String? = nil) -> CompressionPreset? {
        let result: (String, CompressionPreset)? = rwLock.withWriteLock {
            presetCache.removeAll()
            guard let source = cachedPresets.first(where: { $0.id == id }) else { return nil }
            let defaultName = newName ?? "\(source.name) 副本"
            let item = source.clone(newId: UUID(), newName: defaultName)
            cachedPresets.append(item)
            try? repository.save(item)
            return (source.name, item)
        }
        if let (src, item) = result {
            ArchiveEventCenter.shared.postPresetChanged(oldPresetName: src, newPresetName: item.name)
            return item
        }
        return nil
    }
    
    /// 基于指定原型配置衍生全新预设并保存
    @discardableResult
    public func createPresetFromPrototype(_ prototype: CompressionPreset, newName: String? = nil) -> CompressionPreset {
        let cloned = rwLock.withWriteLock { () -> CompressionPreset in
            presetCache.removeAll()
            let item = prototype.clone(newId: UUID(), newName: newName)
            cachedPresets.append(item)
            try? repository.save(item)
            return item
        }
        ArchiveEventCenter.shared.postPresetChanged(oldPresetName: prototype.name, newPresetName: cloned.name)
        return cloned
    }
    
    public func resetToDefaults() {
        rwLock.withWriteLock {
            presetCache.removeAll()
            cachedPresets = PresetManager.defaultBuiltInPresets
            try? repository.resetToDefaults()
        }
        ArchiveEventCenter.shared.postPresetChanged(oldPresetName: "Custom", newPresetName: "Defaults")
    }
    
    private func syncRepositoryLocked() {
        for preset in cachedPresets {
            try? repository.save(preset)
        }
    }
    
    public static var defaultBuiltInPresets: [CompressionPreset] {
        return [
            CompressionPreset(
                name: "7Z 20GB",
                format: .sevenZip,
                level: .store,
                splitVolumeSizeBytes: 20 * 1024 * 1024 * 1024,
                defaultPassword: nil,
                skipMacJunk: true
            ),
            CompressionPreset(
                name: "ZIP 25MB",
                format: .zip,
                level: .normal,
                splitVolumeSizeBytes: 25 * 1024 * 1024,
                defaultPassword: nil,
                skipMacJunk: true
            ),
            CompressionPreset(
                name: "7Z 开发包",
                format: .sevenZip,
                level: .normal,
                defaultPassword: nil,
                skipMacJunk: true,
                skipGitDirectory: true
            ),
            CompressionPreset(
                name: "TAR.ZST 极速",
                format: .tarZst,
                level: .ultra,
                defaultPassword: nil,
                skipMacJunk: true
            )
        ]
    }
}
