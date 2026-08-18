// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import TTZipCore

public struct DiskItemInfo: Identifiable, Hashable, Equatable, Sendable {
    public var id: String { path }
    public let path: String
    public let name: String
    public let isDirectory: Bool
    public let isArchive: Bool
    public let sizeText: String
    public let rawSizeBytes: Int64
    public let creationDate: Date?
    public let modificationDate: Date?
    public let kindText: String
    
    public static func == (lhs: DiskItemInfo, rhs: DiskItemInfo) -> Bool {
        return lhs.path == rhs.path && lhs.rawSizeBytes == rhs.rawSizeBytes && lhs.modificationDate == rhs.modificationDate
    }
    
    public init(url: URL) {
        let factory = ArchiveEntryFlyweightFactory.shared
        self.path = factory.internPath(url.path)
        self.name = factory.internPath(url.lastPathComponent)
        
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
            self.isDirectory = isDir.boolValue
        } else {
            self.isDirectory = false
        }
        
        let rawExt = url.pathExtension.lowercased()
        let ext = factory.internExtension(rawExt)
        let isArch = ArchiveCompressionFormat.isArchiveExtension(ext, path: url.path)
        self.isArchive = isArch
        
        let attr = try? FileManager.default.attributesOfItem(atPath: url.path)
        self.creationDate = attr?[.creationDate] as? Date
        self.modificationDate = attr?[.modificationDate] as? Date
        
        if !self.isDirectory {
            let bytes = (attr?[.size] as? Int64) ?? 0
            self.rawSizeBytes = bytes
            self.sizeText = ByteCountFormatterFlyweight.shared.string(fromByteCount: bytes)
            
            let rawKind = ArchiveCompressionFormat.kindDescription(forExtension: ext, isArchive: isArch, path: url.path)
            self.kindText = factory.internPath(rawKind)
        } else {
            self.rawSizeBytes = 0
            let folderText = "Folder"
            self.sizeText = factory.internPath(folderText)
            self.kindText = factory.internPath(folderText)
        }
    }
    
    public init(
        virtualName: String,
        virtualURL: URL,
        isDirectory: Bool,
        isArchive: Bool,
        sizeText: String,
        rawSizeBytes: Int64,
        kindText: String,
        modificationDate: Date? = nil
    ) {
        let factory = ArchiveEntryFlyweightFactory.shared
        self.path = factory.internPath(virtualURL.absoluteString)
        self.name = factory.internPath(virtualName)
        self.isDirectory = isDirectory
        self.isArchive = isArchive
        self.sizeText = factory.internPath(sizeText)
        self.rawSizeBytes = rawSizeBytes
        self.creationDate = nil
        self.modificationDate = modificationDate
        self.kindText = factory.internPath(kindText)
    }
}
