import Foundation

/// 归档与解压过滤选择结构
public struct ArchiveFilterOptions: Sendable, Equatable {
    public var skipMacJunk: Bool
    public var skipGitDirectory: Bool
    public var customIgnorePatterns: [String]
    
    public init(
        skipMacJunk: Bool = true,
        skipGitDirectory: Bool = false,
        customIgnorePatterns: [String] = []
    ) {
        self.skipMacJunk = skipMacJunk
        self.skipGitDirectory = skipGitDirectory
        self.customIgnorePatterns = customIgnorePatterns
    }
    
    public static let defaultClean = ArchiveFilterOptions(skipMacJunk: true, skipGitDirectory: false)
    public static let preserveAll = ArchiveFilterOptions(skipMacJunk: false, skipGitDirectory: false)
}

// MARK: - PrototypeCopyable 原型模式扩展
extension ArchiveFilterOptions: PrototypeCopyable {
    /// 原型模式默认无差异快照克隆
    public func clone() -> ArchiveFilterOptions {
        return clone(mutate: { _ in })
    }
    
    /// 特化快照变异克隆 API (Prototype Copy with Inout Mutation)
    /// - Parameter mutate: 在独立副本上施加修改闭包
    /// - Returns: 变更后的 ArchiveFilterOptions 独立快照
    public func clone(mutate: (inout ArchiveFilterOptions) -> Void = { _ in }) -> ArchiveFilterOptions {
        var copy = self
        mutate(&copy)
        return copy
    }
}

