import Foundation

/// 【2.7 代理模式 (Proxy Pattern)】虚拟代理 (Virtual Proxy)
/// `LazyArchiveEntryProxy` 封装归档条目的延迟加载机制
/// 打开大型归档包时仅解析轻量元数据，当且仅当显式访问 POSIX 属性、媒体元数据、缩略图或哈希校验时，才触发延迟加载与缓存
public final class LazyArchiveEntryProxy: Identifiable, @unchecked Sendable, Equatable {
    public var id: String { entry.path }
    public let entry: ArchiveEntry
    
    // 线程安全互斥锁与状态追踪
    private let lock = NSLock()
    
    private var _posixAttributes: [FileAttributeKey: Any]?
    private var _posixPermissions: UInt16?
    private var _mediaMetadata: [String: String]?
    private var _thumbnailData: Data?
    private var _sha256Hash: String?
    
    public private(set) var posixLoadCount: Int = 0
    public private(set) var mediaMetadataLoadCount: Int = 0
    public private(set) var thumbnailLoadCount: Int = 0
    public private(set) var hashLoadCount: Int = 0
    
    private var posixProvider: (@Sendable () -> [FileAttributeKey: Any])?
    private var mediaMetadataProvider: (@Sendable () -> [String: String])?
    private var thumbnailProvider: (@Sendable () -> Data?)?
    private var hashProvider: (@Sendable () -> String)?
    
    public init(
        entry: ArchiveEntry,
        posixProvider: (@Sendable () -> [FileAttributeKey: Any])? = nil,
        mediaMetadataProvider: (@Sendable () -> [String: String])? = nil,
        thumbnailProvider: (@Sendable () -> Data?)? = nil,
        hashProvider: (@Sendable () -> String)? = nil
    ) {
        self.entry = entry
        self.posixProvider = posixProvider
        self.mediaMetadataProvider = mediaMetadataProvider
        self.thumbnailProvider = thumbnailProvider
        self.hashProvider = hashProvider
    }
    
    // MARK: - 基础转发属性 (轻量开销，无需延迟)
    
    public var path: String { entry.path }
    public var name: String { entry.name }
    public var uncompressedSize: Int64 { entry.uncompressedSize }
    public var isDirectory: Bool { entry.isDirectory }
    public var detectedEncoding: String { entry.detectedEncoding }
    public var modificationDate: Date? { entry.modificationDate }
    public var extensionName: String { entry.extensionName }
    public var mimeType: String { entry.mimeType }
    public var formattedSize: String { entry.formattedSize }
    
    // MARK: - 延迟加载属性 (Virtual Proxy Core)
    
    /// 是否已加载 POSIX 属性
    public var isPosixLoaded: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _posixAttributes != nil
    }
    
    /// POSIX 文件扩展属性 (首次访问时触发延迟解析)
    public var posixAttributes: [FileAttributeKey: Any] {
        lock.lock()
        defer { lock.unlock() }
        if let attributes = _posixAttributes {
            return attributes
        }
        let loaded = posixProvider?() ?? [:]
        _posixAttributes = loaded
        posixProvider = nil
        posixLoadCount += 1
        return loaded
    }
    
    /// POSIX 权限位 (0o644, 0o755 等)
    public var posixPermissions: UInt16 {
        lock.lock()
        defer { lock.unlock() }
        if let perms = _posixPermissions {
            return perms
        }
        if _posixAttributes == nil {
            let loaded = posixProvider?() ?? [:]
            _posixAttributes = loaded
            posixProvider = nil
            posixLoadCount += 1
        }
        let attrs = _posixAttributes ?? [:]
        let perms = (attrs[.posixPermissions] as? NSNumber)?.uint16Value ?? (isDirectory ? 0o755 : 0o644)
        _posixPermissions = perms
        return perms
    }
    
    /// 是否已加载媒体元数据
    public var isMediaMetadataLoaded: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _mediaMetadata != nil
    }
    
    /// 媒体与文档扩展元数据 (如 EXIF、分辨率、音频采样率，延迟解析)
    public var mediaMetadata: [String: String] {
        lock.lock()
        defer { lock.unlock() }
        if let metadata = _mediaMetadata {
            return metadata
        }
        let loaded = mediaMetadataProvider?() ?? [:]
        _mediaMetadata = loaded
        mediaMetadataProvider = nil
        mediaMetadataLoadCount += 1
        return loaded
    }
    
    /// 是否已加载缩略图
    public var isThumbnailLoaded: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _thumbnailData != nil
    }
    
    /// 预览缩略图二进制数据 (延迟解析)
    public var thumbnailData: Data? {
        lock.lock()
        defer { lock.unlock() }
        if let thumb = _thumbnailData {
            return thumb
        }
        let loaded = thumbnailProvider?()
        _thumbnailData = loaded
        thumbnailProvider = nil
        thumbnailLoadCount += 1
        return loaded
    }
    
    /// 是否已加载 SHA-256 哈希
    public var isHashLoaded: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _sha256Hash != nil
    }
    
    /// 条目 SHA-256 校验和 (延迟计算)
    public var sha256Hash: String {
        lock.lock()
        defer { lock.unlock() }
        if let hash = _sha256Hash {
            return hash
        }
        let loaded = hashProvider?() ?? ""
        _sha256Hash = loaded
        hashProvider = nil
        hashLoadCount += 1
        return loaded
    }
    
    // MARK: - 静态工厂与转换辅助
    
    /// 根据磁盘真实路径自动预置 物理文件 POSIX/缩略图延迟解析器
    public static func create(for entry: ArchiveEntry, diskPath: String? = nil) -> LazyArchiveEntryProxy {
        guard let path = diskPath, FileManager.default.fileExists(atPath: path) else {
            return LazyArchiveEntryProxy(entry: entry)
        }
        
        let posixResolver: @Sendable () -> [FileAttributeKey: Any] = {
            return (try? FileManager.default.attributesOfItem(atPath: path)) ?? [:]
        }
        
        let metadataResolver: @Sendable () -> [String: String] = {
            var meta: [String: String] = [:]
            meta["DiskPath"] = path
            meta["MimeType"] = entry.mimeType
            meta["Extension"] = entry.extensionName
            return meta
        }
        
        let thumbnailResolver: @Sendable () -> Data? = {
            // 简单的二进制图像/文本预览生成代理
            if ["png", "jpg", "jpeg", "gif", "txt", "json", "xml", "md"].contains(entry.extensionName.lowercased()) {
                return try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
            }
            return nil
        }
        
        return LazyArchiveEntryProxy(
            entry: entry,
            posixProvider: posixResolver,
            mediaMetadataProvider: metadataResolver,
            thumbnailProvider: thumbnailResolver
        )
    }
    
    public static func == (lhs: LazyArchiveEntryProxy, rhs: LazyArchiveEntryProxy) -> Bool {
        return lhs.entry == rhs.entry
    }
}
