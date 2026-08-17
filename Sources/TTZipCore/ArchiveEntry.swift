import Foundation

public struct ArchiveEntry: Identifiable, Sendable, Equatable {
    public var id: String { path }
    public let path: String
    public let name: String
    public let uncompressedSize: Int64
    public let isDirectory: Bool
    public let detectedEncoding: String
    public let modificationDate: Date?
    
    // 3-Tier 加密自省元数据
    public let isEncrypted: Bool
    public let isDataEncrypted: Bool
    public let isMetadataEncrypted: Bool
    public let encryptionMethod: String?
    
    // 享元状态属性
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
