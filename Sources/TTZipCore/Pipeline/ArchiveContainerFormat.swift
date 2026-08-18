// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Archive container format defining directory structures and metadata headers.
public enum ArchiveContainerFormat: String, Sendable, CaseIterable, Codable {
    case zip
    case sevenZip = "7z"
    case tar
    case cpio
    case ar
    case iso
    case wim
    case raw
    
    /// Default primary file extension.
    public var defaultExtension: String {
        switch self {
        case .zip: return "zip"
        case .sevenZip: return "7z"
        case .tar: return "tar"
        case .cpio: return "cpio"
        case .ar: return "a"
        case .iso: return "iso"
        case .wim: return "wim"
        case .raw: return "raw"
        }
    }
}

/// Stream compression and encoding filter.
public enum ArchiveStreamFilter: String, Sendable, CaseIterable, Codable {
    case none
    case gzip
    case bzip2
    case xz
    case zstd
    case lz4
    case brotli
    case lzip
    case lrzip
    
    /// File extension associated with stream filter.
    public var filterExtension: String? {
        switch self {
        case .none: return nil
        case .gzip: return "gz"
        case .bzip2: return "bz2"
        case .xz: return "xz"
        case .zstd: return "zst"
        case .lz4: return "lz4"
        case .brotli: return "br"
        case .lzip: return "lz"
        case .lrzip: return "lrz"
        }
    }
}

/// Orthogonal combination of container format and stream filter.
public struct ArchivePipelineComposition: Sendable, Codable, Equatable {
    public let container: ArchiveContainerFormat
    public let filter: ArchiveStreamFilter
    public let supportsFastPathBypass: Bool
    public let displayName: String
    public let primaryFileExtension: String
    
    public init(
        container: ArchiveContainerFormat,
        filter: ArchiveStreamFilter,
        supportsFastPathBypass: Bool,
        displayName: String,
        primaryFileExtension: String
    ) {
        self.container = container
        self.filter = filter
        self.supportsFastPathBypass = supportsFastPathBypass
        self.displayName = displayName
        self.primaryFileExtension = primaryFileExtension
    }
}
