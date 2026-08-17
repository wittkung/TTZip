//
//  PathPatternFilterEngine.swift
//  TTZipCore
//
//  Created by TTZip on 2026-08-17.
//  Copyright © 2026 TTZip. All rights reserved.
//

import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// 高性能 POSIX 通配符过滤与路径剥离引擎
///
/// 职责：
/// 1. 基于 Darwin POSIX `fnmatch(3)` 实现零正则开销的高性能 Glob 通配符匹配；
/// 2. 提供 VCS 版本控制与 macOS 专属垃圾元数据 ($O(1)$ 快速哈希过滤；
/// 3. 提供零堆分配的高速路径前缀剥离 (`stripLeadingComponents`)。
public enum PathPatternFilterEngine: Sendable {
    
    // MARK: - 预定义常量与元数据哈希集合
    
    /// 版本控制系统 (VCS) 核心目录名集合
    public static let vcsDirectoryNames: Set<String> = [
        ".git", ".svn", ".hg", ".bzr", "CVS", "_darcs", ".hgignore"
    ]
    
    /// 版本控制系统 (VCS) 核心文件名集合
    public static let vcsFileNames: Set<String> = [
        ".gitignore", ".gitmodules", ".gitattributes", ".gitkeep",
        ".hgignore", ".hgtags",
        ".svnignore", ".bzrignore"
    ]
    
    /// macOS / OS 专属临时垃圾文件与元数据目录集合
    public static let macMetadataNames: Set<String> = [
        ".DS_Store", "__MACOSX", ".Spotlight-V100", ".Trashes",
        ".fseventsd", ".TemporaryItems", ".VolumeIcon.icns",
        "Thumbs.db", "$RECYCLE.BIN", "ehthumbs.db", "Desktop.ini"
    ]
    
    // MARK: - POSIX Fnmatch 通配符匹配
    
    /// 评估路径是否命中给定的 POSIX 通配符模式 (POSIX.2 Glob)
    ///
    /// 匹配策略：
    /// - 若模式以 `/` 开头：自动剥离前导斜杠，启用 `FNM_PATHNAME`（严格按路径层级匹配）；
    /// - 若模式内部包含 `/`：启用 `FNM_PATHNAME`；
    /// - 若模式不含 `/`：同时对 Basename (`lastPathComponent`)、各级组件名以及全路径进行快速匹配；
    /// - 特化优化：对形如 `*.ext` 的模式采用 `hasSuffix` 快速短路；
    /// - 大小写敏感度：通过 `caseSensitive` 参数控制 `FNM_CASEFOLD` 标志。
    ///
    /// - Parameters:
    ///   - pattern: 通配符模式（支持 `*`, `?`, `[...]`, `[!...]`）
    ///   - path: 待测试的相对或绝对路径
    ///   - caseSensitive: 是否区分大小写（默认 `true`）
    /// - Returns: 若命中模式返回 `true`，否则返回 `false`
    public static func matches(pattern: String, path: String, caseSensitive: Bool = true) -> Bool {
        guard !pattern.isEmpty else { return path.isEmpty }
        guard !path.isEmpty else { return pattern == "*" }
        
        // 1. 全通配符极速短路
        if pattern == "*" {
            return true
        }
        
        // 2. 精确全等匹配短路
        if caseSensitive {
            if pattern == path { return true }
        } else {
            if pattern.caseInsensitiveCompare(path) == .orderedSame { return true }
        }
        
        // 3. 常见扩展名模式特化快速路径 (*.ext)
        if pattern.hasPrefix("*.") {
            let suffixPart = pattern.dropFirst() // ".ext"
            if !suffixPart.dropFirst().contains(where: { $0 == "*" || $0 == "?" || $0 == "[" || $0 == "/" || $0 == "\\" }) {
                let suffixStr = String(suffixPart)
                if caseSensitive {
                    if path.hasSuffix(suffixStr) { return true }
                } else {
                    if path.lowercased().hasSuffix(suffixStr.lowercased()) { return true }
                }
            }
        }
        
        let caseFlags: Int32 = caseSensitive ? 0 : FNM_CASEFOLD
        
        // 4. 模式以 '/' 开头（绝对/根锚定模式，如 "/build/*"）
        if pattern.hasPrefix("/") {
            let trimmedPattern = String(pattern.drop(while: { $0 == "/" }))
            let trimmedPath = String(path.drop(while: { $0 == "/" }))
            return invokeFnmatch(pattern: trimmedPattern, path: trimmedPath, flags: FNM_PATHNAME | caseFlags)
        }
        
        // 5. 模式包含 '/'（分层路径匹配，如 "src/*.swift" 或 "docs/api/*"）
        if pattern.contains("/") {
            let trimmedPath = String(path.drop(while: { $0 == "/" }))
            
            // 支持 leading "**/" 跨层级匹配 (如 "**/*.log")
            if pattern.hasPrefix("**/") {
                let subPattern = String(pattern.dropFirst(3))
                if !subPattern.contains("/") {
                    if matches(pattern: subPattern, path: path, caseSensitive: caseSensitive) {
                        return true
                    }
                }
            }
            
            // 支持 trailing "/**" 子目录全量匹配 (如 "build/**")
            if pattern.hasSuffix("/**") {
                let prefix = String(pattern.dropLast(3))
                let cleanPrefix = prefix.hasPrefix("/") ? String(prefix.dropFirst()) : prefix
                if trimmedPath.hasPrefix(cleanPrefix + "/") || trimmedPath == cleanPrefix {
                    return true
                }
            }
            
            return invokeFnmatch(pattern: pattern, path: trimmedPath, flags: FNM_PATHNAME | caseFlags)
        }
        
        // 6. 模式不含 '/'（通用文件名/组件名通配，如 "*.log"、"node_modules"、".DS_Store"）
        // (a) 对 Basename 匹配
        let lastComponent = (path as NSString).lastPathComponent
        if invokeFnmatch(pattern: pattern, path: lastComponent, flags: caseFlags) {
            return true
        }
        
        // (b) 对各中间目录组件名匹配 (如 path="a/b/c.txt", pattern="b")
        let components = path.split(separator: "/")
        for comp in components {
            let compStr = String(comp)
            if invokeFnmatch(pattern: pattern, path: compStr, flags: caseFlags) {
                return true
            }
        }
        
        // (c) 对完整路径执行无 FNM_PATHNAME 匹配
        return invokeFnmatch(pattern: pattern, path: path, flags: caseFlags)
    }
    
    // MARK: - 判定与过滤决策
    
    /// 评估路径是否属于版本控制元数据 (VCS Metadata)
    public static func isVCSMetadata(_ path: String) -> Bool {
        guard !path.isEmpty else { return false }
        let last = (path as NSString).lastPathComponent
        if vcsDirectoryNames.contains(last) || vcsFileNames.contains(last) {
            return true
        }
        let components = path.split(separator: "/")
        for comp in components {
            let compStr = String(comp)
            if vcsDirectoryNames.contains(compStr) || vcsFileNames.contains(compStr) {
                return true
            }
        }
        return false
    }
    
    /// 评估路径是否属于 macOS / OS 垃圾与元数据文件
    public static func isMacMetadata(_ path: String) -> Bool {
        guard !path.isEmpty else { return false }
        let last = (path as NSString).lastPathComponent
        if macMetadataNames.contains(last) || last.hasPrefix("._") {
            return true
        }
        let components = path.split(separator: "/")
        for comp in components {
            let compStr = String(comp)
            if compStr == "__MACOSX" || compStr == ".Spotlight-V100" || compStr == ".Trashes" || compStr == ".fseventsd" || compStr == ".TemporaryItems" || compStr.hasPrefix("._") {
                return true
            }
        }
        return false
    }
    
    /// 评估路径是否应该被包含在操作集内 (Should Include)
    ///
    /// 评估优先级：
    /// 1. 若开启 `excludeVCS` 且命中 VCS 目录/文件，返回 `false`；
    /// 2. 若开启 `noMacMetadata` 且命中 Mac 垃圾/元数据，返回 `false`；
    /// 3. 若 `includePatterns` 非空：路径必须至少命中一条包含规则（命中则包含）；
    /// 4. 若 `excludePatterns` 非空：路径若命中任一排除规则，返回 `false`；
    /// 5. 默认返回 `true`。
    public static func shouldInclude(
        path: String,
        excludePatterns: [String] = [],
        includePatterns: [String] = [],
        excludeVCS: Bool = false,
        noMacMetadata: Bool = false
    ) -> Bool {
        if excludeVCS && isVCSMetadata(path) {
            return false
        }
        if noMacMetadata && isMacMetadata(path) {
            return false
        }
        if !includePatterns.isEmpty {
            let matchedInclude = includePatterns.contains { pattern in
                matches(pattern: pattern, path: path)
            }
            if !matchedInclude {
                return false
            }
            return true
        }
        if !excludePatterns.isEmpty {
            let matchedExclude = excludePatterns.contains { pattern in
                matches(pattern: pattern, path: path)
            }
            if matchedExclude {
                return false
            }
        }
        return true
    }
    
    /// 评估路径是否应该被排除 (Should Exclude)
    public static func shouldExclude(
        path: String,
        excludePatterns: [String] = [],
        includePatterns: [String] = [],
        excludeVCS: Bool = false,
        noMacMetadata: Bool = false
    ) -> Bool {
        return !shouldInclude(
            path: path,
            excludePatterns: excludePatterns,
            includePatterns: includePatterns,
            excludeVCS: excludeVCS,
            noMacMetadata: noMacMetadata
        )
    }
    
    /// 根据 `ArchiveFilterOptions` 评估路径是否应包含
    public static func shouldInclude(path: String, options: ArchiveFilterOptions) -> Bool {
        return shouldInclude(
            path: path,
            excludePatterns: options.excludePatterns,
            includePatterns: options.includePatterns,
            excludeVCS: options.excludeVCS,
            noMacMetadata: options.noMacMetadata
        )
    }
    
    /// 根据 `ArchiveFilterOptions` 评估路径是否应排除
    public static func shouldExclude(path: String, options: ArchiveFilterOptions) -> Bool {
        return shouldExclude(
            path: path,
            excludePatterns: options.excludePatterns,
            includePatterns: options.includePatterns,
            excludeVCS: options.excludeVCS,
            noMacMetadata: options.noMacMetadata
        )
    }
    
    // MARK: - 路径前缀组件剥离 (Component Stripping)
    
    /// 剥离指定数量的前导非空路径层级（零中间堆分配扫描）
    ///
    /// 规范：
    /// - 若 `count <= 0`，直接返回原始 `path`；
    /// - 若有效路径层级数 $\le count$，返回 `nil`（表示当前条目被完全剔除）；
    /// - 自动过滤前导连续 `/` 与 `./` 相对根前缀；
    ///
    /// - Parameters:
    ///   - path: 原始相对或绝对路径
    ///   - count: 需要剥离的前导组件数量
    /// - Returns: 剥离后的路径字符串；若组件数不足则返回 `nil`
    public static func stripLeadingComponents(_ path: String, count: Int) -> String? {
        guard count > 0 else { return path }
        guard !path.isEmpty else { return nil }
        
        let utf8 = path.utf8
        var i = utf8.startIndex
        let end = utf8.endIndex
        
        // 1. 跳过前导连续斜杠
        while i < end && utf8[i] == UInt8(ascii: "/") {
            i = utf8.index(after: i)
        }
        
        // 2. 跳过前导 "./"
        if i < end && utf8[i] == UInt8(ascii: ".") {
            let next = utf8.index(after: i)
            if next < end && utf8[next] == UInt8(ascii: "/") {
                i = utf8.index(after: next)
                while i < end && utf8[i] == UInt8(ascii: "/") {
                    i = utf8.index(after: i)
                }
            }
        }
        
        var strippedCount = 0
        while strippedCount < count && i < end {
            // 跳过当前组件字符直到遇到 '/'
            while i < end && utf8[i] != UInt8(ascii: "/") {
                i = utf8.index(after: i)
            }
            strippedCount += 1
            // 跳过组件后的连续斜杠
            while i < end && utf8[i] == UInt8(ascii: "/") {
                i = utf8.index(after: i)
            }
        }
        
        // 若剥离数未达到指定 count，或已到达结尾
        guard strippedCount == count, i < end else {
            return nil
        }
        
        let remaining = String(path[i..<end])
        return remaining.isEmpty ? nil : remaining
    }
    
    // MARK: - 私有 C fnmatch 桥接
    
    private static func invokeFnmatch(pattern: String, path: String, flags: Int32) -> Bool {
        return pattern.withCString { p in
            path.withCString { s in
                fnmatch(p, s, flags) == 0
            }
        }
    }
}
