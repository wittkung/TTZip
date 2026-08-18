// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Represents a hierarchical preview tree node for QuickLook and explorer renderers.
/// Conforms strictly to `contracts/quicklook-preview-payload.json#/definitions/PreviewTreeNode`.
public struct PreviewTreeNode: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let relativePath: String
    public let isDirectory: Bool
    public let uncompressedSizeBytes: Int64
    public let isEncrypted: Bool
    public var children: [PreviewTreeNode]?
    
    public init(
        id: String,
        name: String,
        relativePath: String,
        isDirectory: Bool,
        uncompressedSizeBytes: Int64 = 0,
        isEncrypted: Bool = false,
        children: [PreviewTreeNode]? = nil
    ) {
        self.id = id
        self.name = name
        self.relativePath = relativePath
        self.isDirectory = isDirectory
        self.uncompressedSizeBytes = uncompressedSizeBytes
        self.isEncrypted = isEncrypted
        self.children = children
    }
    
    /// Converts an internal `ArchiveTreeNode` into a lightweight `PreviewTreeNode`.
    public static func from(archiveTreeNode node: ArchiveTreeNode) -> PreviewTreeNode {
        let childNodes = node.children?.map { PreviewTreeNode.from(archiveTreeNode: $0) }
        return PreviewTreeNode(
            id: node.path.isEmpty ? UUID().uuidString : node.path,
            name: node.name,
            relativePath: node.path,
            isDirectory: node.isDirectory,
            uncompressedSizeBytes: node.uncompressedSize,
            isEncrypted: node.entry?.isEncrypted ?? false,
            children: childNodes
        )
    }
}

/// Standardized format identifier matching `contracts/quicklook-preview-payload.json`.
public enum QuickLookFormatIdentifier: String, Codable, Sendable, CaseIterable {
    case zip
    case sevenZip = "7z"
    case tar
    case gz
    case bz2
    case xz
    case zst
    case lz4
    case lz
    case lrz
    case aar
    case sz
    case wim
    case dmg
    case iso
    case rar
    case cab
    
    /// Maps from an `ArchiveCompressionFormat`.
    public static func from(format: ArchiveCompressionFormat) -> QuickLookFormatIdentifier {
        switch format {
        case .zip: return .zip
        case .sevenZip: return .sevenZip
        case .tar: return .tar
        case .gz, .tarGz: return .gz
        case .bz2, .tarBz2: return .bz2
        case .xz, .tarXz: return .xz
        case .zst, .tarZst: return .zst
        case .lz4: return .lz4
        case .lzip: return .lz
        case .lrzip: return .lrz
        case .aar: return .aar
        case .snappy: return .sz
        case .wim: return .wim
        case .dmg: return .dmg
        case .iso: return .iso
        case .brotli: return .zip
        }
    }
    
    /// Maps from a file extension or filename string.
    public static func from(extensionString: String) -> QuickLookFormatIdentifier {
        let cleanExt = extensionString.trimmingCharacters(in: .init(charactersIn: ".")).lowercased()
        switch cleanExt {
        case "zip", "zipx", "cbz": return .zip
        case "7z", "cb7": return .sevenZip
        case "tar": return .tar
        case "gz", "tgz": return .gz
        case "bz2", "tbz2", "tbz": return .bz2
        case "xz", "txz": return .xz
        case "zst", "tzst": return .zst
        case "lz4": return .lz4
        case "lz", "lzip": return .lz
        case "lrz", "lrzip": return .lrz
        case "aar", "applearchive": return .aar
        case "sz", "snappy": return .sz
        case "wim": return .wim
        case "dmg": return .dmg
        case "iso": return .iso
        case "rar", "cbr": return .rar
        case "cab": return .cab
        default: return .zip
        }
    }
}

/// Lightweight data payload representing an archive inspected for QuickLook preview.
/// Conforms strictly to `contracts/quicklook-preview-payload.json`.
public struct QuickLookPreviewPayload: Codable, Sendable, Equatable {
    public let archivePath: String
    public let archiveName: String
    public let formatIdentifier: String
    public let uncompressedSizeBytes: Int64
    public let compressedSizeBytes: Int64
    public let compressionRatioPercent: Double
    public let totalEntriesCount: Int
    public let isEncrypted: Bool
    public let rootNodes: [PreviewTreeNode]
    
    public var format: ArchiveCompressionFormat? {
        ArchiveCompressionFormat.from(extensionOrName: formatIdentifier)
    }
    
    public init(
        archivePath: String,
        archiveName: String,
        formatIdentifier: String,
        uncompressedSizeBytes: Int64,
        compressedSizeBytes: Int64,
        compressionRatioPercent: Double,
        totalEntriesCount: Int,
        isEncrypted: Bool,
        rootNodes: [PreviewTreeNode]
    ) {
        self.archivePath = archivePath
        self.archiveName = archiveName
        self.formatIdentifier = formatIdentifier
        self.uncompressedSizeBytes = uncompressedSizeBytes
        self.compressedSizeBytes = compressedSizeBytes
        self.compressionRatioPercent = compressionRatioPercent
        self.totalEntriesCount = totalEntriesCount
        self.isEncrypted = isEncrypted
        self.rootNodes = rootNodes
    }
    
    public init(
        archivePath: String,
        archiveName: String,
        format: ArchiveCompressionFormat,
        uncompressedSizeBytes: Int64,
        compressedSizeBytes: Int64,
        compressionRatioPercent: Double,
        totalEntriesCount: Int,
        isEncrypted: Bool,
        rootNodes: [PreviewTreeNode]
    ) {
        self.archivePath = archivePath
        self.archiveName = archiveName
        self.formatIdentifier = QuickLookFormatIdentifier.from(format: format).rawValue
        self.uncompressedSizeBytes = uncompressedSizeBytes
        self.compressedSizeBytes = compressedSizeBytes
        self.compressionRatioPercent = compressionRatioPercent
        self.totalEntriesCount = totalEntriesCount
        self.isEncrypted = isEncrypted
        self.rootNodes = rootNodes
    }
}

/// Backward compatibility alias
public typealias QuickLookPreviewData = QuickLookPreviewPayload
