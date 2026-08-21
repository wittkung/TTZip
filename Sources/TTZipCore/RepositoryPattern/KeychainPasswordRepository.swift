// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import Security

// MARK: - KeychainPasswordRepository

/// Concrete repository managing encrypted credentials via macOS Keychain services.
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
