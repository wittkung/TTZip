// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - Archive Compression Level

/// Compression level scale (-5 to 22).
public enum ArchiveCompressionLevel: Int, Sendable, CaseIterable, Identifiable, Codable {
    case fast5 = -5, fast4 = -4, fast3 = -3, fast2 = -2, fast1 = -1
    case store = 0
    case level1 = 1, level2 = 2, level3 = 3, level4 = 4, level5 = 5
    case level6 = 6, level7 = 7, level8 = 8, level9 = 9, level10 = 10
    case level11 = 11, level12 = 12, level13 = 13, level14 = 14, level15 = 15
    case level16 = 16, level17 = 17, level18 = 18, level19 = 19, level20 = 20
    case level21 = 21, level22 = 22
    
    // Convenience presets
    public static var fastest: ArchiveCompressionLevel { .level1 }
    public static var fast: ArchiveCompressionLevel { .level3 }
    public static var medium: ArchiveCompressionLevel { .level5 }
    public static var normal: ArchiveCompressionLevel { .level6 }
    public static var maximum: ArchiveCompressionLevel { .level7 }
    public static var ultra: ArchiveCompressionLevel { .level9 }
    
    public var id: Int { rawValue }
    
    public var title: String {
        switch self {
        case .fast5: return "⚡ Fastest (-5)"
        case .fast4: return "⚡ Fastest (-4)"
        case .fast3: return "⚡ Fast (-3)"
        case .fast2: return "⚡ Fast (-2)"
        case .fast1: return "⚡ Fast (-1)"
        case .store: return "📦 Store (0)"
        case .level1: return "⚡ Fast (1)"
        case .level2: return "⚡ Fast+ (2)"
        case .level3: return "🚀 Fast (3)"
        case .level4: return "🚀 Fast+ (4)"
        case .level5: return "⚖️ Balanced (5)"
        case .level6: return "⚖️ Standard (6)"
        case .level7: return "💎 High (7)"
        case .level8: return "💎 Maximum (8)"
        case .level9: return "✨ Ultra (9)"
        case .level10, .level11, .level12, .level13, .level14, .level15: return "✨ Ultra+ (\(rawValue))"
        case .level16, .level17, .level18, .level19: return "🔥 Extreme (\(rawValue))"
        case .level20, .level21, .level22: return "🔥 Ultra-Extreme (\(rawValue))"
        }
    }
    
    public var isQuickPreset: Bool {
        return self == .store || self == .level1 || self == .level6 || self == .level9
    }
    
    public var detailDescription: String {
        switch self {
        case .fast5, .fast4, .fast3, .fast2, .fast1: return "Ultra-high throughput streaming compression"
        case .store: return "Store without compression, maximum I/O throughput"
        case .level1: return "Maximum multi-threaded throughput with lightweight matching"
        case .level2: return "Lightweight LZ77 level 2"
        case .level3: return "Fast dictionary matching balancing speed and ratio"
        case .level4: return "Medium-fast dictionary matching"
        case .level5: return "Balanced compression ratio and CPU utilization"
        case .level6: return "Standard balanced profile for general workloads"
        case .level7: return "Deep dictionary pattern matching"
        case .level8: return "High compression ratio profile"
        case .level9: return "Maximum dictionary search depth for minimal archive size"
        case .level10, .level11, .level12, .level13, .level14, .level15: return "Extended dictionary search depth"
        case .level16, .level17, .level18, .level19: return "High-memory table matching for minimal disk footprint"
        case .level20, .level21, .level22: return "Exhaustive search compression (Zstandard only)"
        }
    }
    
    public init(levelInt: Int) {
        let clamped = max(-5, min(22, levelInt))
        self = ArchiveCompressionLevel(rawValue: clamped) ?? .level6
    }
    
    /// 将通用压缩级别透明映射至底层 Deflate 引擎的原生物理等级
    public var effectiveZipRawLevel: Int32 {
        switch self {
        case .fast5, .fast4, .fast3, .fast2, .fast1:
            return 1
        case .store:
            return 0
        case .level1, .level2:
            return 1
        case .level3, .level4:
            return 3
        case .level5:
            return 5
        case .level6:
            return 6
        case .level7, .level8:
            return 7
        case .level9, .level10, .level11, .level12, .level13, .level14, .level15:
            return 9
        case .level16, .level17, .level18, .level19, .level20, .level21, .level22:
            return 12
        }
    }
    
    /// Measured relative throughput percentage (100% is peak).
    public func relativeSpeedPercentage(for format: ArchiveCompressionFormat? = nil) -> Int {
        switch self {
        case .fast5, .fast4, .fast3, .fast2, .fast1: return 99
        case .store: return 100
        case .fastest, .level1: return 95
        case .fast, .level2, .level3: return 85
        case .normal, .level4, .level5, .level6: return 65
        case .maximum, .level7, .level8: return 40
        case .ultra, .level9, .level10, .level11, .level12: return 20
        case .level13, .level14, .level15, .level16, .level17, .level18, .level19, .level20, .level21, .level22: return 10
        }
    }
    
    /// Speed badge label.
    public func speedBadge(for format: ArchiveCompressionFormat? = nil) -> String {
        return "\(relativeSpeedPercentage(for: format))% Speed"
    }
    
    /// Compression ratio percentage.
    public func compressionRatioPercent(for format: ArchiveCompressionFormat? = nil) -> Double {
        switch self {
        case .fast5, .fast4, .fast3, .fast2, .fast1: return 65.0
        case .store: return 100.0
        case .fastest, .level1: return 60.0
        case .fast, .level2, .level3: return 52.0
        case .normal, .level4, .level5, .level6: return 45.0
        case .maximum, .level7, .level8: return 40.0
        case .ultra, .level9, .level10, .level11, .level12: return 35.0
        case .level13, .level14, .level15, .level16, .level17, .level18, .level19, .level20, .level21, .level22: return 32.0
        }
    }
    
    /// Ratio badge label.
    public func ratioBadge(for format: ArchiveCompressionFormat? = nil) -> String {
        return String(format: "%.0f%% Ratio", compressionRatioPercent(for: format))
    }
}

// MARK: - Format-Specific Options

/// Advanced configuration options specific to ZIP format.
public struct ZipFormatOptions: Sendable, Equatable, Codable {
    public var zipEncryptionMethod: String // AES-256 / AES-128 / ZipCrypto
    public var zipEncodingUTF8: Bool // UTF-8 language encoding flag
    public var preservePosixAttributes: Bool // Preserve POSIX permissions and extended attributes
    public var zip64Mode: String // Auto / Always / Never
    public var enableZeroCopy: Bool // APFS physical zero-copy clone
    
    public init(
        zipEncryptionMethod: String = "AES-256",
        zipEncodingUTF8: Bool = true,
        preservePosixAttributes: Bool = true,
        zip64Mode: String = "Auto",
        enableZeroCopy: Bool = true
    ) {
        self.zipEncryptionMethod = zipEncryptionMethod
        self.zipEncodingUTF8 = zipEncodingUTF8
        self.preservePosixAttributes = preservePosixAttributes
        self.zip64Mode = zip64Mode
        self.enableZeroCopy = enableZeroCopy
    }
}

/// Advanced configuration options specific to 7Z format.
public struct SevenZipFormatOptions: Sendable, Equatable, Codable {
    public var algorithm: String // LZMA2 / LZMA / PPMd / BZip2
    public var dictionarySizeMB: Int // 16MB / 32MB / 64MB / 128MB / 256MB / 512MB
    public var enableSolidArchive: Bool // Solid archiving
    public var encryptFileNames: Bool // Encrypted headers (mhe=on)
    public var matchFinder: String // HC4 / BT4
    public var numFastBytes: Int // 5..273
    
    public init(
        algorithm: String = "LZMA2",
        dictionarySizeMB: Int = 64,
        enableSolidArchive: Bool = true,
        encryptFileNames: Bool = false,
        matchFinder: String = "BT4",
        numFastBytes: Int = 32
    ) {
        self.algorithm = algorithm
        self.dictionarySizeMB = dictionarySizeMB
        self.enableSolidArchive = enableSolidArchive
        self.encryptFileNames = encryptFileNames
        self.matchFinder = matchFinder
        self.numFastBytes = numFastBytes
    }
}

/// Advanced configuration options specific to Zstandard (zst) format.
public struct ZstdFormatOptions: Sendable, Equatable, Codable {
    public var zstdLevel: Int // 1..22
    public var zstdEnableLDM: Bool // Long Distance Matching
    public var zstdJobSizeMB: Int // 1MB..512MB multi-threaded chunk size
    public var zstdWindowLog: Int // 10..31 sliding window log2
    public var zstdChecksum: Bool // XXHash64 frame checksum
    public var zstdDictPath: String? // External training dictionary file path
    
    public init(
        zstdLevel: Int = 3,
        zstdEnableLDM: Bool = false,
        zstdJobSizeMB: Int = 64,
        zstdWindowLog: Int = 27,
        zstdChecksum: Bool = true,
        zstdDictPath: String? = nil
    ) {
        self.zstdLevel = zstdLevel
        self.zstdEnableLDM = zstdEnableLDM
        self.zstdJobSizeMB = zstdJobSizeMB
        self.zstdWindowLog = zstdWindowLog
        self.zstdChecksum = zstdChecksum
        self.zstdDictPath = zstdDictPath
    }
}

/// Advanced configuration options specific to TAR family.
public struct TarFormatOptions: Sendable, Equatable, Codable {
    public var preservePosixPermissions: Bool
    public var usePaxHeader: Bool
    public var numericOwner: Bool
    
    public init(preservePosixPermissions: Bool = true, usePaxHeader: Bool = true, numericOwner: Bool = false) {
        self.preservePosixPermissions = preservePosixPermissions
        self.usePaxHeader = usePaxHeader
        self.numericOwner = numericOwner
    }
}

/// Advanced configuration options specific to Apple Archive (.aar).
public struct AppleArchiveFormatOptions: Sendable, Equatable, Codable {
    public var compressionAlgorithm: String // LZFSE / LZ4 / ZSTD / LZMA
    public var preserveExtendedAttributes: Bool
    public var preserveAccessControlLists: Bool
    
    public init(compressionAlgorithm: String = "LZFSE", preserveExtendedAttributes: Bool = true, preserveAccessControlLists: Bool = true) {
        self.compressionAlgorithm = compressionAlgorithm
        self.preserveExtendedAttributes = preserveExtendedAttributes
        self.preserveAccessControlLists = preserveAccessControlLists
    }
}

/// Advanced configuration options specific to DMG / ISO disk images.
public struct DiskImageFormatOptions: Sendable, Equatable, Codable {
    public var volumeName: String
    public var enableJolietExtension: Bool
    public var enableRockRidgeExtension: Bool
    
    public init(volumeName: String = "TTZipDiskImage", enableJolietExtension: Bool = true, enableRockRidgeExtension: Bool = true) {
        self.volumeName = volumeName
        self.enableJolietExtension = enableJolietExtension
        self.enableRockRidgeExtension = enableRockRidgeExtension
    }
}

/// Advanced configuration options specific to WIM image archives.
public struct WimFormatOptions: Sendable, Equatable, Codable {
    public var compressionType: String // LZX / XPRESS / NONE
    public var imageName: String
    public var imageDescription: String
    
    public init(compressionType: String = "LZX", imageName: String = "TTZipWimImage", imageDescription: String = "Created by TTZip Native C Bridge") {
        self.compressionType = compressionType
        self.imageName = imageName
        self.imageDescription = imageDescription
    }
}

