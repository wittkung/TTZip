import Foundation

// MARK: - 仓储模式贯穿与适配器层 (Repository Pattern Conformances & Adaptations)

/// PasswordVaultManager 对 PasswordVaultRepositoryProtocol 协议的直接遵从适配
extension PasswordVaultManager: PasswordVaultRepositoryProtocol {
    public typealias DomainModel = PasswordVaultEntry
    
    public func fetch(id: UUID) throws -> PasswordVaultEntry? {
        return getEntries().first(where: { $0.id == id })
    }
    
    public func fetchAll() throws -> [PasswordVaultEntry] {
        return getEntries()
    }
    
    public func save(_ entity: PasswordVaultEntry) throws {
        addEntry(label: entity.label, password: entity.password, category: entity.category)
    }
    
    public func delete(id: UUID) throws {
        removeEntry(id: id)
    }
    
    public func deleteAll() throws {
        let all = getEntries()
        for item in all {
            removeEntry(id: item.id)
        }
    }
    
    public func search(category: String) throws -> [PasswordVaultEntry] {
        return getEntries().filter { $0.category == category }
    }
    
    public func unlock(masterPassword: String) throws -> Bool {
        return unlockVault(with: masterPassword)
    }
    
    public func lock() {
        lockVault()
    }
}

/// PresetManager 对 ArchivePresetRepositoryProtocol 协议的直接遵从适配
extension PresetManager: ArchivePresetRepositoryProtocol {
    public typealias DomainModel = CompressionPreset
    
    public func fetch(id: UUID) throws -> CompressionPreset? {
        return preset(for: id)
    }
    
    public func fetchAll() throws -> [CompressionPreset] {
        return presets
    }
    
    public func save(_ entity: CompressionPreset) throws {
        savePreset(entity)
    }
    
    public func delete(id: UUID) throws {
        deletePreset(id: id)
    }
    
    public func deleteAll() throws {
        resetToDefaults()
    }
    
    public func fetchByName(_ name: String) throws -> CompressionPreset? {
        return presets.first(where: { $0.name == name })
    }
    
    public func duplicate(id: UUID, newName: String?) throws -> CompressionPreset? {
        return duplicatePreset(id: id, newName: newName)
    }
    
    public func setRepository(_ newRepository: any ArchivePresetRepositoryProtocol) {
        self.loadPresets()
    }
}

/// 为 CommandHistoryManager 扩展仓储模式与历史持久化支撑
extension CommandHistoryManager {
    /// 便捷生成 ArchiveTaskRecord
    public func makeRecord(for command: ArchiveCommandProtocol, isSuccess: Bool) -> ArchiveTaskRecord {
        return ArchiveTaskRecord(
            id: UUID(),
            commandName: command.description,
            archivePath: "archive_\(command.commandId.prefix(8)).zip",
            targetPath: "/tmp/TTZip/Output",
            isSuccess: isSuccess,
            timestamp: Date(),
            fileSizeByte: 1024
        )
    }
}
