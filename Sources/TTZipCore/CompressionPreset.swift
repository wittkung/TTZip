import Foundation



/// 自定义常用压缩预设模型
public struct CompressionPreset: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var format: ArchiveCompressionFormat
    public var level: ArchiveCompressionLevel
    public var splitVolumeSizeBytes: Int64? // nil 表示不分卷，如 20 * 1024 * 1024 * 1024 (20GB)
    public var defaultPassword: String?
    public var skipMacJunk: Bool
    public var skipGitDirectory: Bool
    
    public init(
        id: UUID = UUID(),
        name: String,
        format: ArchiveCompressionFormat,
        level: ArchiveCompressionLevel,
        splitVolumeSizeBytes: Int64? = nil,
        defaultPassword: String? = nil,
        skipMacJunk: Bool = true,
        skipGitDirectory: Bool = false
    ) {
        self.id = id
        self.name = name
        self.format = format
        self.level = level
        self.splitVolumeSizeBytes = splitVolumeSizeBytes
        self.defaultPassword = defaultPassword
        self.skipMacJunk = skipMacJunk
        self.skipGitDirectory = skipGitDirectory
    }
    
    public var splitVolumeDescription: String {
        guard let bytes = splitVolumeSizeBytes, bytes > 0 else {
            return "不分卷"
        }
        let gb = Double(bytes) / (1024.0 * 1024.0 * 1024.0)
        if gb >= 1.0 {
            return String(format: "%.0f GB 分卷", gb)
        }
        let mb = Double(bytes) / (1024.0 * 1024.0)
        return String(format: "%.0f MB 分卷", mb)
    }
}

// MARK: - PrototypeCopyable 原型模式扩展
extension CompressionPreset: PrototypeCopyable {
    /// 原型模式默认克隆：分配新 UUID 独立标识符，保持继承名称与所有选项
    public func clone() -> CompressionPreset {
        return clone(newId: UUID(), newName: nil)
    }
    
    /// 特化预设衍生与克隆 API (Prototype Copy)
    /// - Parameters:
    ///   - newId: 目标新预设 UUID (默认自动分配全新 UUID)
    ///   - newName: 目标新预设名称 (若为 nil 则继承当前预设原名)
    /// - Returns: 独立全新配制的 CompressionPreset 副本
    public func clone(newId: UUID = UUID(), newName: String? = nil) -> CompressionPreset {
        return CompressionPreset(
            id: newId,
            name: newName ?? self.name,
            format: self.format,
            level: self.level,
            splitVolumeSizeBytes: self.splitVolumeSizeBytes,
            defaultPassword: self.defaultPassword,
            skipMacJunk: self.skipMacJunk,
            skipGitDirectory: self.skipGitDirectory
        )
    }
}

