// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Generic data mapper protocol transforming domain entities to persistence DTOs (Data Mapper Pattern).
public protocol DataMapperProtocol: Sendable {
    associatedtype DomainModel: Sendable
    associatedtype StorageDTO: Sendable
    
    /// Maps domain entity into storage DTO.
    func toStorage(domain: DomainModel) -> StorageDTO
    
    /// Maps storage DTO into domain entity.
    func toDomain(storage: StorageDTO) -> DomainModel
}

// MARK: - 1. CompressionPreset ↔ PresetStorageDTO Data Mapper

/// Preset storage DTO supporting versioned migration.
public struct PresetStorageDTO: Codable, Sendable, Equatable {
    public var schemaVersion: Int
    public var presetId: String
    public var titleName: String
    public var compressionFormatRaw: String
    public var compressionLevelRaw: Int
    public var volumeSplitBytes: Int64?
    public var embeddedPassword: String?
    public var omitMacJunkFiles: Bool
    public var omitGitDirFiles: Bool
    public var legacyFormatName: String?
    
    public init(
        schemaVersion: Int = 3,
        presetId: String,
        titleName: String,
        compressionFormatRaw: String,
        compressionLevelRaw: Int,
        volumeSplitBytes: Int64? = nil,
        embeddedPassword: String? = nil,
        omitMacJunkFiles: Bool = true,
        omitGitDirFiles: Bool = false,
        legacyFormatName: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.presetId = presetId
        self.titleName = titleName
        self.compressionFormatRaw = compressionFormatRaw
        self.compressionLevelRaw = compressionLevelRaw
        self.volumeSplitBytes = volumeSplitBytes
        self.embeddedPassword = embeddedPassword
        self.omitMacJunkFiles = omitMacJunkFiles
        self.omitGitDirFiles = omitGitDirFiles
        self.legacyFormatName = legacyFormatName
    }
}

/// Data mapper converting `CompressionPreset` to `PresetStorageDTO`.
public final class PresetDataMapper: DataMapperProtocol, @unchecked Sendable {
    public typealias DomainModel = CompressionPreset
    public typealias StorageDTO = PresetStorageDTO
    
    public init() {}
    
    public func toStorage(domain: CompressionPreset) -> PresetStorageDTO {
        return PresetStorageDTO(
            schemaVersion: 3,
            presetId: domain.id.uuidString,
            titleName: domain.name,
            compressionFormatRaw: domain.format.rawValue,
            compressionLevelRaw: domain.level.rawValue,
            volumeSplitBytes: domain.splitVolumeSizeBytes,
            embeddedPassword: domain.defaultPassword,
            omitMacJunkFiles: domain.skipMacJunk,
            omitGitDirFiles: domain.skipGitDirectory,
            legacyFormatName: nil
        )
    }
    
    public func toDomain(storage: PresetStorageDTO) -> CompressionPreset {
        let uuid = UUID(uuidString: storage.presetId) ?? UUID()
        
        let formatString = storage.legacyFormatName ?? storage.compressionFormatRaw
        let format: ArchiveCompressionFormat
        if let direct = ArchiveCompressionFormat(rawValue: formatString) {
            format = direct
        } else {
            switch formatString.lowercased() {
            case "7z", "sevenzip": format = .sevenZip
            case "zip": format = .zip
            case "tar.zst", "zstd", "tarzst": format = .tarZst
            case "tar.gz", "gzip", "targz": format = .tarGz
            case "tar.bz2", "bzip2", "tarbz2": format = .tarBz2
            case "rar": format = .sevenZip
            default: format = .zip
            }
        }
        
        let level = ArchiveCompressionLevel(rawValue: storage.compressionLevelRaw) ?? .normal
        
        return CompressionPreset(
            id: uuid,
            name: storage.titleName,
            format: format,
            level: level,
            splitVolumeSizeBytes: storage.volumeSplitBytes,
            defaultPassword: storage.embeddedPassword,
            skipMacJunk: storage.omitMacJunkFiles,
            skipGitDirectory: storage.omitGitDirFiles
        )
    }
}

// MARK: - 2. VaultPasswordEntry ↔ KeychainStorageDTO Data Mapper

/// Keychain persistence DTO payload.
public struct KeychainStorageDTO: Codable, Sendable, Equatable {
    public var entryUUIDString: String
    public var itemLabel: String
    public var passwordData: Data
    public var itemCategory: String
    public var createdTimestamp: Double
    public var usageCount: Int
    public var lastUsedTimestamp: Double?
    
    public init(
        entryUUIDString: String,
        itemLabel: String,
        passwordData: Data,
        itemCategory: String,
        createdTimestamp: Double,
        usageCount: Int,
        lastUsedTimestamp: Double? = nil
    ) {
        self.entryUUIDString = entryUUIDString
        self.itemLabel = itemLabel
        self.passwordData = passwordData
        self.itemCategory = itemCategory
        self.createdTimestamp = createdTimestamp
        self.usageCount = usageCount
        self.lastUsedTimestamp = lastUsedTimestamp
    }
}

/// Data mapper converting `VaultPasswordEntry` to `KeychainStorageDTO`.
public final class KeychainDataMapper: DataMapperProtocol, @unchecked Sendable {
    public typealias DomainModel = VaultPasswordEntry
    public typealias StorageDTO = KeychainStorageDTO
    
    public init() {}
    
    public func toStorage(domain: VaultPasswordEntry) -> KeychainStorageDTO {
        let pwdData = Data(domain.password.utf8)
        return KeychainStorageDTO(
            entryUUIDString: domain.id.uuidString,
            itemLabel: domain.label,
            passwordData: pwdData,
            itemCategory: domain.category,
            createdTimestamp: domain.createdAt.timeIntervalSince1970,
            usageCount: domain.useCount,
            lastUsedTimestamp: domain.lastUsedAt?.timeIntervalSince1970
        )
    }
    
    public func toDomain(storage: KeychainStorageDTO) -> VaultPasswordEntry {
        let uuid = UUID(uuidString: storage.entryUUIDString) ?? UUID()
        let pwdString = String(data: storage.passwordData, encoding: .utf8) ?? ""
        let created = Date(timeIntervalSince1970: storage.createdTimestamp)
        let lastUsed = storage.lastUsedTimestamp.map { Date(timeIntervalSince1970: $0) }
        
        return PasswordVaultEntry(
            id: uuid,
            label: storage.itemLabel,
            password: pwdString,
            category: storage.itemCategory,
            createdAt: created,
            useCount: storage.usageCount,
            lastUsedAt: lastUsed
        )
    }
}

// MARK: - 3. ArchiveTaskRecord ↔ HistoryJSONDTO Data Mapper

/// History record JSON persistence DTO.
public struct HistoryJSONDTO: Codable, Sendable, Equatable {
    public var recordId: String
    public var taskType: String
    public var sourceFile: String
    public var destinationFile: String
    public var statusFlag: String
    public var dateEpoch: Double
    public var bytesProcessed: Int64
    
    public init(
        recordId: String,
        taskType: String,
        sourceFile: String,
        destinationFile: String,
        statusFlag: String,
        dateEpoch: Double,
        bytesProcessed: Int64
    ) {
        self.recordId = recordId
        self.taskType = taskType
        self.sourceFile = sourceFile
        self.destinationFile = destinationFile
        self.statusFlag = statusFlag
        self.dateEpoch = dateEpoch
        self.bytesProcessed = bytesProcessed
    }
}

/// Data mapper converting `ArchiveTaskRecord` to `HistoryJSONDTO`.
public final class ArchiveHistoryDataMapper: DataMapperProtocol, @unchecked Sendable {
    public typealias DomainModel = ArchiveTaskRecord
    public typealias StorageDTO = HistoryJSONDTO
    
    public init() {}
    
    public func toStorage(domain: ArchiveTaskRecord) -> HistoryJSONDTO {
        return HistoryJSONDTO(
            recordId: domain.id.uuidString,
            taskType: domain.commandName,
            sourceFile: domain.archivePath,
            destinationFile: domain.targetPath,
            statusFlag: domain.isSuccess ? "SUCCESS" : "FAILURE",
            dateEpoch: domain.timestamp.timeIntervalSince1970,
            bytesProcessed: domain.fileSizeByte
        )
    }
    
    public func toDomain(storage: HistoryJSONDTO) -> ArchiveTaskRecord {
        let uuid = UUID(uuidString: storage.recordId) ?? UUID()
        let isSuccess = storage.statusFlag.uppercased() == "SUCCESS"
        let timestamp = Date(timeIntervalSince1970: storage.dateEpoch)
        
        return ArchiveTaskRecord(
            id: uuid,
            commandName: storage.taskType,
            archivePath: storage.sourceFile,
            targetPath: storage.destinationFile,
            isSuccess: isSuccess,
            timestamp: timestamp,
            fileSizeByte: storage.bytesProcessed
        )
    }
}
