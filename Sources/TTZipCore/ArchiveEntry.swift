// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Value type representing a single item (file, directory, or symlink) inside an archive.
///
/// Integrates Flyweight Pattern interning for path strings, extensions, and MIME types
/// to reduce memory footprint by 70%+ across huge archive hierarchies.
public struct ArchiveEntry: Identifiable, Sendable, Equatable {
    public var id: String { path }
    public let path: String
    public let name: String
    public let uncompressedSize: Int64
    public let isDirectory: Bool
    public let detectedEncoding: String
    public let modificationDate: Date?
    
    // 3-Tier Encryption Introspection Metadata
    public let isEncrypted: Bool
    public let isDataEncrypted: Bool
    public let isMetadataEncrypted: Bool
    public let encryptionMethod: String?
    
    // Flyweight Attributes
    public var extensionName: String {
        ArchiveEntryFlyweightFactory.shared.internExtension((name as NSString).pathExtension)
    }
    
    public var mimeType: String {
        ArchiveEntryFlyweightFactory.shared.detectMimeType(forPath: path)
    }
    
    public var directoryPrefix: String {
        ArchiveEntryFlyweightFactory.shared.extractAndInternDirectoryPrefix(fromPath: path)
    }
    
    public var formattedSize: String {
        ByteCountFormatterFlyweight.shared.string(fromByteCount: uncompressedSize)
    }
    
    public init(
        path: String,
        uncompressedSize: Int64,
        isDirectory: Bool,
        detectedEncoding: String = "UTF-8",
        modificationDate: Date? = nil,
        isEncrypted: Bool = false,
        isDataEncrypted: Bool = false,
        isMetadataEncrypted: Bool = false,
        encryptionMethod: String? = nil
    ) {
        let factory = ArchiveEntryFlyweightFactory.shared
        self.path = factory.internPath(path)
        let rawName = (path as NSString).lastPathComponent
        self.name = factory.internPath(rawName)
        self.uncompressedSize = uncompressedSize
        self.isDirectory = isDirectory
        self.detectedEncoding = factory.internPath(detectedEncoding)
        self.modificationDate = modificationDate
        self.isEncrypted = isEncrypted || isDataEncrypted || isMetadataEncrypted
        self.isDataEncrypted = isDataEncrypted || (isEncrypted && !isMetadataEncrypted)
        self.isMetadataEncrypted = isMetadataEncrypted
        self.encryptionMethod = encryptionMethod
    }
}
