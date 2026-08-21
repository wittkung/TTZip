// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Supported archive compression and container formats.
public enum ArchiveCompressionFormat: String, Sendable, CaseIterable, Codable {
    case sevenZip = "7z"
    case zip = "zip"
    case tar = "tar"
    case zst = "zst"
    case gz = "gz"
    case bz2 = "bz2"
    case xz = "xz"
    case lzip = "lzip"
    case lz4 = "lz4"
    case brotli = "brotli"
    case lrzip = "lrzip"
    case aar = "aar"
    case snappy = "snappy"
    case wim = "wim"
    case dmg = "dmg"
    case iso = "iso"
    
    // Composite aliases
    case tarGz = "tar.gz"
    case tarZst = "tar.zst"
    case tarBz2 = "tar.bz2"
    case tarXz = "tar.xz"
    
    public var displayName: String {
        switch self {
        case .sevenZip: return "7Z"
        case .zip: return "ZIP"
        case .tar: return "TAR"
        case .zst, .tarZst: return "ZSTD"
        case .gz, .tarGz: return "GZIP"
        case .bz2, .tarBz2: return "BZIP2"
        case .xz, .tarXz: return "XZ"
        case .lzip: return "LZIP"
        case .lz4: return "LZ4"
        case .brotli: return "BROTLI"
        case .lrzip: return "LRZIP"
        case .aar: return "AAR"
        case .snappy: return "SNAPPY"
        case .wim: return "WIM"
        case .dmg: return "DMG"
        case .iso: return "ISO"
        }
    }
    
    public var fileExtension: String {
        switch self {
        case .sevenZip: return ".7z"
        case .zip: return ".zip"
        case .tar: return ".tar"
        case .zst: return ".zst"
        case .gz: return ".gz"
        case .bz2: return ".bz2"
        case .xz: return ".xz"
        case .lzip: return ".lz"
        case .lz4: return ".lz4"
        case .brotli: return ".br"
        case .lrzip: return ".lrz"
        case .aar: return ".aar"
        case .snappy: return ".sz"
        case .wim: return ".wim"
        case .dmg: return ".dmg"
        case .iso: return ".iso"
        case .tarGz: return ".tar.gz"
        case .tarZst: return ".tar.zst"
        case .tarBz2: return ".tar.bz2"
        case .tarXz: return ".tar.xz"
        }
    }

    /// 7Z / DMG / ISO / Split Volume (.001) compatible extensions set.
    public static let sevenZipFamilyExtensions: Set<String> = [
        ".7z", ".cb7", ".dmg", ".iso", ".001"
    ]

    /// TAR derivative and libarchive compatible extensions set.
    public static let tarFamilyExtensions: Set<String> = [
        ".tar", ".tar.gz", ".tgz", ".tar.zst", ".tzst",
        ".tar.xz", ".txz", ".tar.bz2", ".tbz2", ".tar.lz",
        ".tlz", ".gz", ".bz2", ".xz", ".lz", ".lzip", ".zst",
        ".lz4", ".br", ".brotli", ".lrz", ".lrzip", ".sz", ".snappy",
        ".aar", ".wim", ".dmg", ".iso", ".rar", ".cbr"
    ]

    /// Determines whether a filename or path represents a known archive format.
    public static func isArchiveExtension(_ ext: String, path: String = "") -> Bool {
        let lowerExt = ext.lowercased()
        if ArchiveCompressionFormat(rawValue: lowerExt) != nil {
            return true
        }
        let dotExt = ".\(lowerExt)"
        if sevenZipFamilyExtensions.contains(dotExt) || tarFamilyExtensions.contains(dotExt) {
            return true
        }
        let archiveExtraExts: Set<String> = ["zipx", "rar", "cab", "001", "002", "003", "zst", "iso", "wim"]
        if archiveExtraExts.contains(lowerExt) {
            return true
        }
        let lowerPath = path.lowercased()
        if lowerExt.range(of: #"^\d{3}$"#, options: .regularExpression) != nil || lowerPath.contains(".7z.") || lowerPath.contains(".zip.") || lowerPath.contains(".rar.") {
            return true
        }
        return false
    }

    /// Resolves compression format from extension or name string.
    public static func from(extensionOrName: String) -> ArchiveCompressionFormat? {
        let cleaned = extensionOrName.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        if let direct = ArchiveCompressionFormat(rawValue: cleaned) {
            return direct
        }
        for format in allCases {
            if format.rawValue.lowercased() == cleaned || format.displayName.lowercased() == cleaned {
                return format
            }
        }
        switch cleaned {
        case "7zip", "sevenzip", "cb7": return .sevenZip
        case "tgz": return .tarGz
        case "tbz", "tbz2": return .tarBz2
        case "txz": return .tarXz
        case "tzst": return .tarZst
        case "tlz": return .lzip
        case "lz": return .lzip
        case "br": return .brotli
        case "lrz": return .lrzip
        case "sz": return .snappy
        default: return nil
        }
    }

    /// Resolves descriptive kind string for an item.
    public static func kindDescription(forExtension ext: String, isArchive: Bool, path: String = "") -> String {
        let lowerExt = ext.lowercased()
        if isArchive {
            return "Archive Package"
        }
        if let format = ArchiveCompressionFormat(rawValue: lowerExt) {
            return "\(format.displayName) Archive"
        }
        
        switch lowerExt {
        case "jpg", "jpeg": return "JPEG Image"
        case "png": return "PNG Image"
        case "gif": return "GIF Animation"
        case "webp": return "WebP Image"
        case "heic": return "HEIC Image"
        case "pdf": return "PDF Document"
        case "mp4", "mov": return "MPEG-4 Video"
        case "mp3", "wav", "m4a": return "Audio File"
        case "txt", "md": return "Text Document"
        case "swift", "py", "json": return "Source Code"
        default: return "\(ext.uppercased()) File"
        }
    }
    
    public var shortcutBadge: String {
        switch self {
        case .sevenZip: return "⌥⇧7"
        case .zip: return "⌥⇧Z"
        case .tar: return "⌥⇧T"
        case .zst, .tarZst: return "⌥⇧S"
        case .gz, .tarGz: return "⌥⇧G"
        case .bz2, .tarBz2: return "⌥⇧B"
        case .xz, .tarXz: return "⌥⇧X"
        case .lzip: return "⌥⇧L"
        case .lz4: return "⌥⇧4"
        case .brotli: return "⌥⇧R"
        case .lrzip: return "⌥⇧P"
        case .aar: return "⌥⇧A"
        case .snappy: return "⌥⇧N"
        case .wim: return "⌥⇧W"
        case .dmg: return "⌥⇧D"
        case .iso: return "⌥⇧I"
        }
    }
    
    public var shortcutCharacter: Character {
        switch self {
        case .sevenZip: return "7"
        case .zip: return "z"
        case .tar: return "t"
        case .zst, .tarZst: return "s"
        case .gz, .tarGz: return "g"
        case .bz2, .tarBz2: return "b"
        case .xz, .tarXz: return "x"
        case .lzip: return "l"
        case .lz4: return "4"
        case .brotli: return "r"
        case .lrzip: return "p"
        case .aar: return "a"
        case .snappy: return "n"
        case .wim: return "w"
        case .dmg: return "d"
        case .iso: return "i"
        }
    }
    
    public var supportsPasswordEncryption: Bool {
        return self == .sevenZip || self == .zip || self == .wim || self == .dmg
    }
    
    public var supportsSplitVolume: Bool {
        return self == .sevenZip || self == .zip
    }
    
    /// Supported compression levels for format.
    public var supportedLevels: [ArchiveCompressionLevel] {
        switch self {
        case .tar, .dmg, .iso, .aar:
            return [.store]
        case .zip:
            return [.store, .level1, .level2, .level3, .level4, .level5, .level6, .level7]
        case .sevenZip, .zst, .tarZst, .gz, .tarGz, .bz2, .tarBz2, .xz, .tarXz, .lzip, .lz4, .brotli, .lrzip, .snappy, .wim:
            return [.store, .level1, .level6, .level9]
        }
    }
}
