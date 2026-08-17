import Foundation

/// 归档与解压过滤选择结构
public struct ArchiveFilterOptions: Sendable, Equatable {
    public var excludePatterns: [String]
    public var includePatterns: [String]
    public var stripComponents: Int
    public var excludeVCS: Bool
    public var noMacMetadata: Bool
    public var flattenPaths: Bool
    public var filesFromPath: String?
    public var nullDelimiter: Bool
    
    // MARK: - Backwards Compatibility Aliases
    public var skipMacJunk: Bool {
        get { noMacMetadata }
        set { noMacMetadata = newValue }
    }
    
    public var skipGitDirectory: Bool {
        get { excludeVCS }
        set { excludeVCS = newValue }
    }
    
    public var customIgnorePatterns: [String] {
        get { excludePatterns }
        set { excludePatterns = newValue }
    }
    
    public init(
        excludePatterns: [String] = [],
        includePatterns: [String] = [],
        stripComponents: Int = 0,
        excludeVCS: Bool = false,
        noMacMetadata: Bool = true,
        flattenPaths: Bool = false,
        filesFromPath: String? = nil,
        nullDelimiter: Bool = false
    ) {
        self.excludePatterns = excludePatterns
        self.includePatterns = includePatterns
        self.stripComponents = stripComponents
        self.excludeVCS = excludeVCS
        self.noMacMetadata = noMacMetadata
        self.flattenPaths = flattenPaths
        self.filesFromPath = filesFromPath
        self.nullDelimiter = nullDelimiter
    }
    
    public init(
        skipMacJunk: Bool = true,
        skipGitDirectory: Bool = false,
        customIgnorePatterns: [String] = []
    ) {
        self.excludePatterns = customIgnorePatterns
        self.includePatterns = []
        self.stripComponents = 0
        self.excludeVCS = skipGitDirectory
        self.noMacMetadata = skipMacJunk
        self.flattenPaths = false
        self.filesFromPath = nil
        self.nullDelimiter = false
    }
    
    public static let defaultClean = ArchiveFilterOptions(excludePatterns: [], includePatterns: [], stripComponents: 0, excludeVCS: false, noMacMetadata: true)
    public static let preserveAll = ArchiveFilterOptions(excludePatterns: [], includePatterns: [], stripComponents: 0, excludeVCS: false, noMacMetadata: false)
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

