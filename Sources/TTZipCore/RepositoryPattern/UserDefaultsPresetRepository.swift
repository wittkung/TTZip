// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - UserDefaultsPresetRepository

/// Concrete repository managing compression presets via UserDefaults storage.
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
            let defaultName = newName ?? "\(targetDomain.name) Copy"
            let clonedDomain = targetDomain.clone(newId: UUID(), newName: defaultName)
            
            let clonedDTO = mapper.toStorage(domain: clonedDomain)
            cachedDTOs.append(clonedDTO)
            saveToStorageLocked()
            
            return clonedDomain
        }
    }
}
