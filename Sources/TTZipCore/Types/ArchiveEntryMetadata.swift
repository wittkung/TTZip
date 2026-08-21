// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Comprehensive structured metadata describing an archive entry or filesystem entity.
public struct ArchiveEntryMetadata: Identifiable, Sendable, Equatable, Codable {
    public var id: String { path }
    
    /// Path of the entry inside the archive hierarchy.
    public var path: String
    
    /// Uncompressed size in bytes.
    public var uncompressedSize: Int64
    
    /// Compressed physical payload size in bytes, if available.
    public var compressedSize: Int64?
    
    /// Entry CRC-32 checksum, if recorded.
    public var crc32: UInt32?
    
    /// Modification timestamp.
    public var modificationDate: Date?
    
    /// POSIX file system permissions / mode bits.
    public var posixPermissions: UInt32?
    
    /// Indicates whether entry is a container directory.
    public var isDirectory: Bool
    
    /// Indicates whether entry is a symbolic link.
    public var isSymlink: Bool
    
    /// Target destination path if entry is a symlink.
    public var symlinkTarget: String?
    
    /// Whether the entry payload or header is encrypted.
    public var isEncrypted: Bool
    
    /// Specific encryption algorithm / cipher name (e.g. "AES-256", "ZipCrypto").
    public var encryptionMethod: String?
    
    /// Detected text encoding for file path / names (default: "UTF-8").
    public var detectedEncoding: String
    
    /// MIME content type inferred from extension or content.
    public var mimeType: String
    
    public init(
        path: String,
        uncompressedSize: Int64 = 0,
        compressedSize: Int64? = nil,
        crc32: UInt32? = nil,
        modificationDate: Date? = nil,
        posixPermissions: UInt32? = nil,
        isDirectory: Bool = false,
        isSymlink: Bool = false,
        symlinkTarget: String? = nil,
        isEncrypted: Bool = false,
        encryptionMethod: String? = nil,
        detectedEncoding: String = "UTF-8",
        mimeType: String = "application/octet-stream"
    ) {
        self.path = path
        self.uncompressedSize = uncompressedSize
        self.compressedSize = compressedSize
        self.crc32 = crc32
        self.modificationDate = modificationDate
        self.posixPermissions = posixPermissions
        self.isDirectory = isDirectory
        self.isSymlink = isSymlink
        self.symlinkTarget = symlinkTarget
        self.isEncrypted = isEncrypted
        self.encryptionMethod = encryptionMethod
        self.detectedEncoding = detectedEncoding
        self.mimeType = mimeType
    }
    
    /// Constructs metadata from a runtime `ArchiveEntry`.
    public init(entry: ArchiveEntry) {
        self.path = entry.path
        self.uncompressedSize = entry.uncompressedSize
        self.compressedSize = nil
        self.crc32 = nil
        self.modificationDate = entry.modificationDate
        self.posixPermissions = nil
        self.isDirectory = entry.isDirectory
        self.isSymlink = false
        self.symlinkTarget = nil
        self.isEncrypted = entry.isEncrypted
        self.encryptionMethod = entry.encryptionMethod
        self.detectedEncoding = entry.detectedEncoding
        self.mimeType = entry.mimeType
    }
}
