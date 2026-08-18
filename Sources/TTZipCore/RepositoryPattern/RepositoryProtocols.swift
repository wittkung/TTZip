// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Archive task history record domain entity model.
public struct ArchiveTaskRecord: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var commandName: String
    public var archivePath: String
    public var targetPath: String
    public var isSuccess: Bool
    public var timestamp: Date
    public var fileSizeByte: Int64
    
    public init(
        id: UUID = UUID(),
        commandName: String,
        archivePath: String,
        targetPath: String,
        isSuccess: Bool,
        timestamp: Date = Date(),
        fileSizeByte: Int64 = 0
    ) {
        self.id = id
        self.commandName = commandName
        self.archivePath = archivePath
        self.targetPath = targetPath
        self.isSuccess = isSuccess
        self.timestamp = timestamp
        self.fileSizeByte = fileSizeByte
    }
}

/// Type alias for vault password entry domain entity.
public typealias VaultPasswordEntry = PasswordVaultEntry

/// Generic repository interface protocol (Repository Pattern).
///
/// Decouples business logic and domain entities from persistence engines and DTO schemas.
public protocol ArchiveRepositoryProtocol<DomainModel>: Sendable where DomainModel: Identifiable, DomainModel: Sendable {
    associatedtype DomainModel
    
    /// Fetches single domain entity by identifier.
    func fetch(id: DomainModel.ID) throws -> DomainModel?
    
    /// Fetches all domain entities.
    func fetchAll() throws -> [DomainModel]
    
    /// Saves or updates domain entity.
    func save(_ entity: DomainModel) throws
    
    /// Deletes domain entity by identifier.
    func delete(id: DomainModel.ID) throws
    
    /// Deletes all domain entities.
    func deleteAll() throws
}

/// Specialized repository protocol for compression presets.
public protocol ArchivePresetRepositoryProtocol: ArchiveRepositoryProtocol where DomainModel == CompressionPreset {
    /// Queries preset by name.
    func fetchByName(_ name: String) throws -> CompressionPreset?
    
    /// Resets presets to built-in system defaults.
    func resetToDefaults() throws
    
    /// Duplicates an existing preset.
    func duplicate(id: UUID, newName: String?) throws -> CompressionPreset?
}

/// Specialized repository protocol for password vault credentials.
public protocol PasswordVaultRepositoryProtocol: ArchiveRepositoryProtocol where DomainModel == PasswordVaultEntry {
    /// Queries password entries matching category.
    func search(category: String) throws -> [PasswordVaultEntry]
    
    /// Records usage timestamp and counter for credential entry.
    func recordUsage(id: UUID) throws
    
    /// Whether vault is currently unlocked.
    var isUnlocked: Bool { get }
    
    /// Unlocks vault using master credential.
    func unlock(masterPassword: String) throws -> Bool
    
    /// Locks vault and wipes plaintext secrets from memory.
    func lock()
}

/// Specialized repository protocol for execution history records.
public protocol ArchiveHistoryRepositoryProtocol: ArchiveRepositoryProtocol where DomainModel == ArchiveTaskRecord {
    /// Fetches recent records ordered by timestamp descending.
    func fetchRecent(limit: Int) throws -> [ArchiveTaskRecord]
    
    /// Filters history records by success flag.
    func fetchByStatus(isSuccess: Bool) throws -> [ArchiveTaskRecord]
}
