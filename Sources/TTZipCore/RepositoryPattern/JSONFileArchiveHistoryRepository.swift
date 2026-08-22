// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - JSONFileArchiveHistoryRepository

/// Concrete repository managing execution history records via atomic JSON files.
public final class JSONFileArchiveHistoryRepository: ArchiveHistoryRepositoryProtocol, @unchecked Sendable {
    public typealias DomainModel = ArchiveTaskRecord
    
    private let historyFileURL: URL
    private let mapper: ArchiveHistoryDataMapper
    private let lock = NSLock()
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
        lock.withLock {
            guard FileManager.default.fileExists(atPath: historyFileURL.path) else {
                self.memoryCacheDTOs = []
                return
            }
            
            do {
                let data = try Data(contentsOf: historyFileURL)
                let decoded = try JSONDecoder().decode([HistoryJSONDTO].self, from: data)
                self.memoryCacheDTOs = decoded
            } catch {
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
            // Best effort persistence write
        }
    }
    
    public func fetch(id: UUID) throws -> ArchiveTaskRecord? {
        return lock.withLock {
            guard let dto = memoryCacheDTOs.first(where: { $0.recordId == id.uuidString }) else { return nil }
            return mapper.toDomain(storage: dto)
        }
    }
    
    public func fetchAll() throws -> [ArchiveTaskRecord] {
        return lock.withLock {
            memoryCacheDTOs.map { mapper.toDomain(storage: $0) }
        }
    }
    
    public func save(_ entity: ArchiveTaskRecord) throws {
        lock.withLock {
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
        lock.withLock {
            memoryCacheDTOs.removeAll { $0.recordId == id.uuidString }
            saveToDiskLocked()
        }
    }
    
    public func deleteAll() throws {
        lock.withLock {
            memoryCacheDTOs.removeAll()
            try? FileManager.default.removeItem(at: historyFileURL)
        }
    }
    
    public func fetchRecent(limit: Int) throws -> [ArchiveTaskRecord] {
        return lock.withLock {
            let sorted = memoryCacheDTOs.sorted { $0.dateEpoch > $1.dateEpoch }
            let prefix = Array(sorted.prefix(limit))
            return prefix.map { mapper.toDomain(storage: $0) }
        }
    }
    
    public func fetchByStatus(isSuccess: Bool) throws -> [ArchiveTaskRecord] {
        return lock.withLock {
            let targetFlag = isSuccess ? "SUCCESS" : "FAILURE"
            let filtered = memoryCacheDTOs.filter { $0.statusFlag.uppercased() == targetFlag }
            return filtered.map { mapper.toDomain(storage: $0) }
        }
    }
}
