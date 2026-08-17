import Foundation

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
    
    // 兼容复合与历史别名
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

    /// 7Z / DMG / ISO / Split Volume (.001) 兼容文件扩展名集合
    public static let sevenZipFamilyExtensions: Set<String> = [
        ".7z", ".cb7", ".dmg", ".iso", ".001"
    ]

    /// TAR 衍生全变体与 UnRAR / libarchive 全兼容文件扩展名集合
    public static let tarFamilyExtensions: Set<String> = [
        ".tar", ".tar.gz", ".tgz", ".tar.zst", ".tzst",
        ".tar.xz", ".txz", ".tar.bz2", ".tbz2", ".tar.lz",
        ".tlz", ".gz", ".bz2", ".xz", ".lz", ".lzip", ".zst",
        ".lz4", ".br", ".brotli", ".lrz", ".lrzip", ".sz", ".snappy",
        ".aar", ".wim", ".dmg", ".iso", ".rar", ".cbr"
    ]

    /// 根据扩展名或路径判定是否为归档文件格式
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

    /// 根据扩展名或格式名称解析归档压缩格式
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



    /// 根据扩展名与归档标记解析描述性类型名称
    public static func kindDescription(forExtension ext: String, isArchive: Bool, path: String = "") -> String {
        let lowerExt = ext.lowercased()
        if isArchive {
            return "归档压缩包"
        }
        if let format = ArchiveCompressionFormat(rawValue: lowerExt) {
            return "\(format.displayName) 文件"
        }
        
        switch lowerExt {
        case "jpg", "jpeg": return "JPEG 图像"
        case "png": return "PNG 图像"
        case "gif": return "GIF 动画图像"
        case "webp": return "WebP 图像"
        case "heic": return "HEIC 高效图像"
        case "pdf": return "PDF 文档"
        case "mp4", "mov": return "MPEG-4 视频"
        case "mp3", "wav", "m4a": return "音频文件"
        case "txt", "md": return "文本文档"
        case "swift", "py", "json": return "代码源文件"
        default: return "\(ext.uppercased()) 文件"
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
    
    /// 该格式支持的有效压缩级别列表
    public var supportedLevels: [ArchiveCompressionLevel] {
        switch self {
        case .tar, .dmg, .iso, .aar:
            return [.store]
        case .sevenZip, .zip, .zst, .tarZst, .gz, .tarGz, .bz2, .tarBz2, .xz, .tarXz, .lzip, .lz4, .brotli, .lrzip, .snappy, .wim:
            return [.store, .level1, .level6, .level9]
        }
    }
}

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
    
    // 快捷兼容别名
    public static var fastest: ArchiveCompressionLevel { .level1 }
    public static var fast: ArchiveCompressionLevel { .level3 }
    public static var medium: ArchiveCompressionLevel { .level5 }
    public static var normal: ArchiveCompressionLevel { .level6 }
    public static var maximum: ArchiveCompressionLevel { .level7 }
    public static var ultra: ArchiveCompressionLevel { .level9 }
    
    public var id: Int { rawValue }
    
    public var title: String {
        switch self {
        case .fast5: return "⚡ 极限极速 (-5)"
        case .fast4: return "⚡ 极限极速 (-4)"
        case .fast3: return "⚡ 超极速 (-3)"
        case .fast2: return "⚡ 超极速 (-2)"
        case .fast1: return "⚡ 极速+ (-1)"
        case .store: return "📦 仅存储 (0)"
        case .level1: return "⚡ 极速 (1)"
        case .level2: return "⚡ 极速+ (2)"
        case .level3: return "🚀 较快 (3)"
        case .level4: return "🚀 较快+ (4)"
        case .level5: return "⚖️ 平衡 (5)"
        case .level6: return "⚖️ 标准 (6)"
        case .level7: return "💎 较高 (7)"
        case .level8: return "💎 高 (8)"
        case .level9: return "✨ 极限 (9)"
        case .level10, .level11, .level12, .level13, .level14, .level15: return "✨ 极限+ (\(rawValue))"
        case .level16, .level17, .level18, .level19: return "🔥 超极限 (\(rawValue))"
        case .level20, .level21, .level22: return "🔥 变态极限 (\(rawValue))"
        }
    }
    
    public var isQuickPreset: Bool {
        return self == .store || self == .level1 || self == .level6 || self == .level9
    }
    
    public var detailDescription: String {
        switch self {
        case .fast5, .fast4, .fast3, .fast2, .fast1: return "极致无损极速压缩，适合内部高速网络传输或高带宽流式处理"
        case .store: return "仅归档打包不压缩，极速 I/O 吞吐，适合已压缩音视频/安装包"
        case .level1: return "全核最高并发吞吐，最轻量字典匹配，快速打包传输"
        case .level2: return "轻量级 LZ77 快速级别 2，兼顾响应与初期吞吐"
        case .level3: return "轻量字典算法匹配，兼顾打包速度与初始体积"
        case .level4: return "中轻度字典匹配，平衡速度与中间体积"
        case .level5: return "中度算法匹配，平衡体积压缩比与 CPU 计算消耗"
        case .level6: return "经典标准平衡点，通用场景首选推荐"
        case .level7: return "深度字典与模式查找，进一步缩减存储空间"
        case .level8: return "高阶深度算法匹配，追求极小体积"
        case .level9: return "最大化深度算法字典查找，极限节省磁盘存储空间"
        case .level10, .level11, .level12, .level13, .level14, .level15: return "突破级深度字典查找，在可控内存下逼近极限体积"
        case .level16, .level17, .level18, .level19: return "极高内存占用的大规模历史查表匹配，只为极小空间设计"
        case .level20, .level21, .level22: return "彻底无视内存占用与吞吐极限的变态级算法搜索（限 Zstd）"
        }
    }
    
    public init(levelInt: Int) {
        let clamped = max(-5, min(22, levelInt))
        self = ArchiveCompressionLevel(rawValue: clamped) ?? .level6
    }
    
    /// 基于物理实测数据动态换算的相对压缩吞吐速度百分比 (最快标为 100%)
    public func relativeSpeedPercentage(for format: ArchiveCompressionFormat? = nil) -> Int {
        let targetFormat = format ?? .zip
        return BenchmarkSpeedCache.shared.relativeSpeedPercentage(format: targetFormat, level: self)
    }
    
    /// 实测相对速度标注徽章
    public func speedBadge(for format: ArchiveCompressionFormat? = nil) -> String {
        let pct = relativeSpeedPercentage(for: format)
        return "\(pct)% 速度"
    }
    
    /// 基于物理实测数据动态获取的压缩体积百分比 (%)
    public func compressionRatioPercent(for format: ArchiveCompressionFormat? = nil) -> Double {
        let targetFormat = format ?? .zip
        return BenchmarkSpeedCache.shared.compressionRatioPercent(format: targetFormat, level: self)
    }
    
    /// 实测相对压缩体积与空间节省标注徽章
    public func ratioBadge(for format: ArchiveCompressionFormat? = nil) -> String {
        let targetFormat = format ?? .zip
        return BenchmarkSpeedCache.shared.ratioBadge(format: targetFormat, level: self)
    }
}

/// 针对 ZIP 格式独立定制的高级参数配置
public struct ZipFormatOptions: Sendable, Equatable, Codable {
    public var zipEncryptionMethod: String // AES-256 / AES-128 / ZipCrypto
    public var zipEncodingUTF8: Bool // 强制 UTF-8 语言编码标志
    public var preservePosixAttributes: Bool // 保留 macOS / POSIX 文件权限与扩展属性
    public var zip64Mode: String // Auto / Always / Never
    public var enableZeroCopy: Bool // APFS 物理零拷贝 Extent 克隆
    
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

/// 针对 7Z 格式独立定制的高级参数配置
public struct SevenZipFormatOptions: Sendable, Equatable, Codable {
    public var algorithm: String // LZMA2 / LZMA / PPMd / BZip2
    public var dictionarySizeMB: Int // 16MB / 32MB / 64MB / 128MB / 256MB / 512MB
    public var enableSolidArchive: Bool // 固实压缩 (Solid)
    public var encryptFileNames: Bool // 标头加密 (mhe=on)
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

/// 针对 Zstandard (zst) 格式独立定制的高级参数配置
public struct ZstdFormatOptions: Sendable, Equatable, Codable {
    public var zstdLevel: Int // 1..22
    public var zstdEnableLDM: Bool // 长距离匹配 (Long Distance Matching)
    public var zstdJobSizeMB: Int // 1MB..512MB 多线程块大小
    public var zstdWindowLog: Int // 10..31 滑动窗口 Log2
    public var zstdChecksum: Bool // XXHash64 帧完整性校验和
    public var zstdDictPath: String? // Zstandard 外部训练字典文件路径
    
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

/// 针对 TAR 家族 (TAR, GZ, BZ2, XZ, LZIP, LZ4, BROTLI, LRZIP, SNAPPY) 的高级配置
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

/// 针对 Apple Archive (.aar) 原生流式归档的高级配置
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

/// 针对 DMG / ISO 磁盘映像的高级配置
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

/// 针对 WIM 映像归档的高级配置
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

/// 全局多格式统一高级专业配置包装模型
public struct ArchiveAdvancedOptions: Sendable, Equatable {
    public var cpuThreads: Int
    public var zipOptions: ZipFormatOptions
    public var sevenZipOptions: SevenZipFormatOptions
    public var zstdOptions: ZstdFormatOptions
    public var tarOptions: TarFormatOptions
    public var appleArchiveOptions: AppleArchiveFormatOptions
    public var diskImageOptions: DiskImageFormatOptions
    public var wimOptions: WimFormatOptions
    
    // 快捷兼容属性暴露
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

// MARK: - PrototypeCopyable 原型模式扩展
extension ArchiveAdvancedOptions: PrototypeCopyable {
    /// 原型模式深拷贝独立快照
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

