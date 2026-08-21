// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Value type representing a secure credential entry within the password vault.
public struct PasswordVaultEntry: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var label: String
    public var password: String
    public var category: String
    public var createdAt: Date
    public var useCount: Int
    public var lastUsedAt: Date?
    
    public init(
        id: UUID = UUID(),
        label: String,
        password: String,
        category: String = "General",
        createdAt: Date = Date(),
        useCount: Int = 0,
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.label = label
        self.password = password
        self.category = category
        self.createdAt = createdAt
        self.useCount = useCount
        self.lastUsedAt = lastUsedAt
    }
}

/// Backup envelope structure storing serialized vault entries and historical master hash.
public struct VaultBackupData: Codable {
    public let oldMasterHash: String
    public let entries: [PasswordVaultEntry]
    public let backupDate: Date
    
    public init(oldMasterHash: String, entries: [PasswordVaultEntry], backupDate: Date) {
        self.oldMasterHash = oldMasterHash
        self.entries = entries
        self.backupDate = backupDate
    }
}

/// Protocol abstraction for password vault management and candidate querying.
public protocol PasswordVaultManaging: Sendable {
    var autoUnlockArchives: Bool { get }
    func getEntries() -> [PasswordVaultEntry]
    func recordUsage(id: UUID)
}
