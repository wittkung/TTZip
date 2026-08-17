import Foundation

/// 归档容器结构格式 (负责 Entry Header 目录结构与元数据编解码)
///
/// 对标 libarchive `archive_format_descriptor`
public enum ArchiveContainerFormat: String, Sendable, CaseIterable, Codable {
    case zip
    case sevenZip = "7z"
    case tar
    case cpio
    case ar
    case iso
    case wim
    case raw
    
    /// 默认主扩展名
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

/// 流式传输与压缩转换滤镜 (负责纯字节流的编解码与算法转换)
///
/// 对标 libarchive `archive_read_filter` / `archive_write_filter`
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
    
    /// 滤镜对应的后缀扩展名
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

/// 容器格式与流式滤镜的正交组合实体模型
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
