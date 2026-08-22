// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Repository and persistence manager for compression presets.
public final class PresetManager: @unchecked Sendable {
    public static let shared = PresetManager()
    
    private var repository: any ArchivePresetRepositoryProtocol
    private var cachedPresets: [CompressionPreset] = []
    private let lock = NSLock()
    
    private init() {
        self.repository = UserDefaultsPresetRepository()
        loadPresets()
    }
    
    internal init(repository: any ArchivePresetRepositoryProtocol) {
        self.repository = repository
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
            if let list = try? repository.fetchAll(), !list.isEmpty {
                self.cachedPresets = list
            } else {
                self.cachedPresets = PresetManager.defaultBuiltInPresets
                syncRepositoryLocked()
            }
        }
    }
    
    public func savePreset(_ preset: CompressionPreset) {
        let _ = lock.withLock { () -> String? in
            let old = cachedPresets.first(where: { $0.id == preset.id })?.name
            if let index = cachedPresets.firstIndex(where: { $0.id == preset.id }) {
                cachedPresets[index] = preset
            } else {
                cachedPresets.append(preset)
            }
            try? repository.save(preset)
            return old
        }
    }
    
    public func deletePreset(id: UUID) {
        lock.withLock {
            cachedPresets.removeAll(where: { $0.id == id })
            try? repository.delete(id: id)
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
            try? repository.save(item)
            return item
        }
    }
    
    /// Derives and saves a new preset from a prototype model.
    @discardableResult
    public func createPresetFromPrototype(_ prototype: CompressionPreset, newName: String? = nil) -> CompressionPreset {
        let cloned = lock.withLock { () -> CompressionPreset in
            let item = prototype.clone(newId: UUID(), newName: newName)
            cachedPresets.append(item)
            try? repository.save(item)
            return item
        }
        return cloned
    }
    
    public func resetToDefaults() {
        lock.withLock {
            cachedPresets = PresetManager.defaultBuiltInPresets
            try? repository.resetToDefaults()
        }
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
