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

/// Compression level scale (-5 to 22).
public enum ArchiveCompressionLevel: Int, Sendable, CaseIterable, Identifiable, Codable {
    case fast5 = -5
    case fast4 = -4
    case fast3 = -3
    case fast2 = -2
    case fast1 = -1
    case store = 0
    case level1 = 1
    case level2 = 2
    case level3 = 3
    case level4 = 4
    case level5 = 5
    case level6 = 6
    case level7 = 7
    case level8 = 8
    case level9 = 9
    case level10 = 10
    case level11 = 11
    case level12 = 12
    case level13 = 13
    case level14 = 14
    case level15 = 15
    case level16 = 16
    case level17 = 17
    case level18 = 18
    case level19 = 19
    case level20 = 20
    case level21 = 21
    case level22 = 22
    
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
    
    /// 获取该压缩级别在 ZIP 格式下的强类型物理配置 Profile
    public var zipProfile: ZipCompressionProfile {
        return ZipCompressionProfile.profile(for: self)
    }

    /// 将通用压缩级别透明映射至底层 Deflate 引擎的原生物理等级
    public var effectiveZipRawLevel: Int32 {
        return zipProfile.deflateLevel
    }
    
    /// Measured relative throughput percentage (100% is peak).
    public func relativeSpeedPercentage(for format: ArchiveCompressionFormat? = nil) -> Int {
        let targetFormat = format ?? .zip
        return BenchmarkSpeedCache.shared.relativeSpeedPercentage(format: targetFormat, level: self)
    }
    
    /// Speed badge label.
    public func speedBadge(for format: ArchiveCompressionFormat? = nil) -> String {
        let pct = relativeSpeedPercentage(for: format)
        return "\(pct)% Speed"
    }
    
    /// Compression ratio percentage.
    public func compressionRatioPercent(for format: ArchiveCompressionFormat? = nil) -> Double {
        let targetFormat = format ?? .zip
        return BenchmarkSpeedCache.shared.compressionRatioPercent(format: targetFormat, level: self)
    }
    
    /// Ratio badge label.
    public func ratioBadge(for format: ArchiveCompressionFormat? = nil) -> String {
        let targetFormat = format ?? .zip
        return BenchmarkSpeedCache.shared.ratioBadge(format: targetFormat, level: self)
    }
}

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
    
    public init(
        preservePosixPermissions: Bool = true,
        usePaxHeader: Bool = true,
        numericOwner: Bool = false
    ) {
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
    
    public init(
        compressionAlgorithm: String = "LZFSE",
        preserveExtendedAttributes: Bool = true,
        preserveAccessControlLists: Bool = true
    ) {
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
    
    public init(
        volumeName: String = "TTZipDiskImage",
        enableJolietExtension: Bool = true,
        enableRockRidgeExtension: Bool = true
    ) {
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
    
    public init(
        compressionType: String = "LZX",
        imageName: String = "TTZipWimImage",
        imageDescription: String = "Created by TTZip Native C Bridge"
    ) {
        self.compressionType = compressionType
        self.imageName = imageName
        self.imageDescription = imageDescription
    }
}

/// Unified multi-format advanced configuration options model.
public struct ArchiveAdvancedOptions: Sendable, Equatable {
    public var cpuThreads: Int
    public var zipOptions: ZipFormatOptions
    public var sevenZipOptions: SevenZipFormatOptions
    public var zstdOptions: ZstdFormatOptions
    public var tarOptions: TarFormatOptions
    public var appleArchiveOptions: AppleArchiveFormatOptions
    public var diskImageOptions: DiskImageFormatOptions
    public var wimOptions: WimFormatOptions
    
    // Convenient property accessors
    public var algorithm: String {
        get { sevenZipOptions.algorithm }
        set { sevenZipOptions.algorithm = newValue }
    }
    public var dictionarySizeMB: Int {
        get { sevenZipOptions.dictionarySizeMB }
        set { sevenZipOptions.dictionarySizeMB = newValue }
    }
    public var enableSolidArchive: Bool {
        get { sevenZipOptions.enableSolidArchive }
        set { sevenZipOptions.enableSolidArchive = newValue }
    }
    public var encryptFileNames: Bool {
        get { sevenZipOptions.encryptFileNames }
        set { sevenZipOptions.encryptFileNames = newValue }
    }
    public var zipEncryptionMethod: String {
        get { zipOptions.zipEncryptionMethod }
        set { zipOptions.zipEncryptionMethod = newValue }
    }
    public var zipEncodingUTF8: Bool {
        get { zipOptions.zipEncodingUTF8 }
        set { zipOptions.zipEncodingUTF8 = newValue }
    }
    public var preservePosixAttributes: Bool {
        get { zipOptions.preservePosixAttributes }
        set { zipOptions.preservePosixAttributes = newValue }
    }
    public var enableZeroCopy: Bool {
        get { zipOptions.enableZeroCopy }
        set { zipOptions.enableZeroCopy = newValue }
    }
    public var zstdLevel: Int {
        get { zstdOptions.zstdLevel }
        set { zstdOptions.zstdLevel = newValue }
    }
    public var zstdEnableLDM: Bool {
        get { zstdOptions.zstdEnableLDM }
        set { zstdOptions.zstdEnableLDM = newValue }
    }
    public var zstdDictPath: String? {
        get { zstdOptions.zstdDictPath }
        set { zstdOptions.zstdDictPath = newValue }
    }
    
    public init(
        cpuThreads: Int = 0,
        zipOptions: ZipFormatOptions = ZipFormatOptions(),
        sevenZipOptions: SevenZipFormatOptions = SevenZipFormatOptions(),
        zstdOptions: ZstdFormatOptions = ZstdFormatOptions(),
        tarOptions: TarFormatOptions = TarFormatOptions(),
        appleArchiveOptions: AppleArchiveFormatOptions = AppleArchiveFormatOptions(),
        diskImageOptions: DiskImageFormatOptions = DiskImageFormatOptions(),
        wimOptions: WimFormatOptions = WimFormatOptions()
    ) {
        self.cpuThreads = cpuThreads
        self.zipOptions = zipOptions
        self.sevenZipOptions = sevenZipOptions
        self.zstdOptions = zstdOptions
        self.tarOptions = tarOptions
        self.appleArchiveOptions = appleArchiveOptions
        self.diskImageOptions = diskImageOptions
        self.wimOptions = wimOptions
    }
    
    public init(
        algorithm: String = "LZMA2",
        dictionarySizeMB: Int = 64,
        cpuThreads: Int = 0,
        enableSolidArchive: Bool = true,
        encryptFileNames: Bool = false,
        zipEncryptionMethod: String = "AES-256",
        zipEncodingUTF8: Bool = true,
        zstdLevel: Int = 3,
        zstdEnableLDM: Bool = false,
        preservePosixAttributes: Bool = true,
        zstdDictPath: String? = nil
    ) {
        self.cpuThreads = cpuThreads
        self.sevenZipOptions = SevenZipFormatOptions(
            algorithm: algorithm,
            dictionarySizeMB: dictionarySizeMB,
            enableSolidArchive: enableSolidArchive,
            encryptFileNames: encryptFileNames
        )
        self.zipOptions = ZipFormatOptions(
            zipEncryptionMethod: zipEncryptionMethod,
            zipEncodingUTF8: zipEncodingUTF8,
            preservePosixAttributes: preservePosixAttributes
        )
        self.zstdOptions = ZstdFormatOptions(
            zstdLevel: zstdLevel,
            zstdEnableLDM: zstdEnableLDM,
            zstdDictPath: zstdDictPath
        )
        self.tarOptions = TarFormatOptions()
        self.appleArchiveOptions = AppleArchiveFormatOptions()
        self.diskImageOptions = DiskImageFormatOptions()
        self.wimOptions = WimFormatOptions()
    }
    
    public static var defaultOptions: ArchiveAdvancedOptions {
        let cores = AppleSiliconTuner.shared.topology.totalCores
        return ArchiveAdvancedOptions(
            cpuThreads: cores,
            zipOptions: ZipFormatOptions(),
            sevenZipOptions: SevenZipFormatOptions(),
            zstdOptions: ZstdFormatOptions(),
            tarOptions: TarFormatOptions(),
            appleArchiveOptions: AppleArchiveFormatOptions(),
            diskImageOptions: DiskImageFormatOptions(),
            wimOptions: WimFormatOptions()
        )
    }
}

// MARK: - PrototypeCopyable Prototype Pattern Extension
extension ArchiveAdvancedOptions: PrototypeCopyable {
    /// Deep-copies this configuration model.
    public func clone() -> ArchiveAdvancedOptions {
        return ArchiveAdvancedOptions(
            cpuThreads: self.cpuThreads,
            zipOptions: self.zipOptions,
            sevenZipOptions: self.sevenZipOptions,
            zstdOptions: self.zstdOptions,
            tarOptions: self.tarOptions,
            appleArchiveOptions: self.appleArchiveOptions,
            diskImageOptions: self.diskImageOptions,
            wimOptions: self.wimOptions
        )
    }
}
