// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Persistence and management coordinator for compression presets.
public final class PresetManager: @unchecked Sendable {
    public static let shared = PresetManager()
    
    private let userDefaults: UserDefaults
    private let storageKey: String
    private var cachedPresets: [CompressionPreset] = []
    private let lock = NSLock()
    
    public init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "TTZip_User_Compression_Presets_v3"
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        loadPresets()
    }
    
    public var presets: [CompressionPreset] {
        lock.withLock {
            cachedPresets
        }
    }
    
    public func preset(for id: UUID) -> CompressionPreset? {
        lock.withLock {
            cachedPresets.first(where: { $0.id == id })
        }
    }
    
    public func loadPresets() {
        lock.withLock {
            if let data = userDefaults.data(forKey: storageKey),
               let list = try? JSONDecoder().decode([CompressionPreset].self, from: data),
               !list.isEmpty {
                self.cachedPresets = list
            } else {
                self.cachedPresets = PresetManager.defaultBuiltInPresets
                saveToStorageLocked()
            }
        }
    }
    
    public func savePreset(_ preset: CompressionPreset) {
        lock.withLock {
            if let index = cachedPresets.firstIndex(where: { $0.id == preset.id }) {
                cachedPresets[index] = preset
            } else {
                cachedPresets.append(preset)
            }
            saveToStorageLocked()
        }
    }
    
    public func deletePreset(id: UUID) {
        lock.withLock {
            cachedPresets.removeAll(where: { $0.id == id })
            saveToStorageLocked()
        }
    }
    
    /// Duplicates an existing preset using Prototype Pattern.
    @discardableResult
    public func duplicatePreset(id: UUID, newName: String? = nil) -> CompressionPreset? {
        return lock.withLock {
            guard let source = cachedPresets.first(where: { $0.id == id }) else { return nil }
            let defaultName = newName ?? "\(source.name) Copy"
            let item = source.clone(newId: UUID(), newName: defaultName)
            cachedPresets.append(item)
            saveToStorageLocked()
            return item
        }
    }
    
    /// Derives and saves a new preset from a prototype model.
    @discardableResult
    public func createPresetFromPrototype(_ prototype: CompressionPreset, newName: String? = nil) -> CompressionPreset {
        let cloned = lock.withLock { () -> CompressionPreset in
            let item = prototype.clone(newId: UUID(), newName: newName)
            cachedPresets.append(item)
            saveToStorageLocked()
            return item
        }
        return cloned
    }
    
    public func resetToDefaults() {
        lock.withLock {
            cachedPresets = PresetManager.defaultBuiltInPresets
            saveToStorageLocked()
        }
    }
    
    private func saveToStorageLocked() {
        if let encoded = try? JSONEncoder().encode(cachedPresets) {
            userDefaults.set(encoded, forKey: storageKey)
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
                name: "7Z Source Package",
                format: .sevenZip,
                level: .normal,
                defaultPassword: nil,
                skipMacJunk: true,
                skipGitDirectory: true
            ),
            CompressionPreset(
                name: "TAR.ZST Fast",
                format: .tarZst,
                level: .ultra,
                defaultPassword: nil,
                skipMacJunk: true
            )
        ]
    }
}
