// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Weitao Kung (Witt Kung) <kevintungs@163.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// 归档可视化目录树渲染器 (Archive Visual Tree Renderer)
public enum ArchiveVisualTreeRenderer: Sendable {
    
    /// 将归档条目渲染为精美的 Unicode 树状文本图谱
    /// - Parameters:
    ///   - archivePath: 归档路径或名称
    ///   - entries: 归档条目列表
    ///   - maxDepth: 最大遍历深度限制（nil 代表无限制）
    /// - Returns: 格式化好的整段树形文本
    public static func render(
        archivePath: String,
        entries: [ArchiveEntry],
        maxDepth: Int? = nil
    ) -> String {
        let root = buildTree(entries: entries)
        var output = ""
        let baseName = (archivePath as NSString).lastPathComponent
        output += "📦 \(baseName)\n"
        
        renderNode(
            node: root,
            prefix: "",
            isLast: true,
            currentDepth: 0,
            maxDepth: maxDepth,
            output: &output
        )
        
        let fileCount = root.totalFileCount()
        let dirCount = root.totalDirectoryCount()
        let totalBytes = root.totalSizeBytes()
        let sizeStr = formatBytes(totalBytes)
        
        output += "\n\(dirCount) directories, \(fileCount) files (Total: \(sizeStr))\n"
        return output
    }
    
    // MARK: - 内部节点与渲染递归
    
    private final class TreeNode {
        let name: String
        var isDirectory: Bool
        var sizeBytes: Int64
        var children: [String: TreeNode] = [:]
        
        init(name: String, isDirectory: Bool, sizeBytes: Int64 = 0) {
            self.name = name
            self.isDirectory = isDirectory
            self.sizeBytes = sizeBytes
        }
        
        func totalFileCount() -> Int {
            var count = isDirectory ? 0 : 1
            for child in children.values {
                count += child.totalFileCount()
            }
            return count
        }
        
        func totalDirectoryCount() -> Int {
            var count = isDirectory && !name.isEmpty ? 1 : 0
            for child in children.values {
                count += child.totalDirectoryCount()
            }
            return count
        }
        
        func totalSizeBytes() -> Int64 {
            var total = sizeBytes
            for child in children.values {
                total += child.totalSizeBytes()
            }
            return total
        }
    }
    
    private static func buildTree(entries: [ArchiveEntry]) -> TreeNode {
        let root = TreeNode(name: "", isDirectory: true)
        
        for entry in entries {
            let normalized = entry.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard !normalized.isEmpty else { continue }
            let parts = normalized.split(separator: "/").map { String($0) }
            
            var current = root
            for (idx, part) in parts.enumerated() {
                let isLastPart = (idx == parts.count - 1)
                let isDir = isLastPart ? entry.isDirectory : true
                let sz = isLastPart ? entry.uncompressedSize : 0
                
                if let existing = current.children[part] {
                    if isLastPart {
                        existing.sizeBytes = sz
                        existing.isDirectory = isDir
                    }
                    current = existing
                } else {
                    let newNode = TreeNode(name: part, isDirectory: isDir, sizeBytes: sz)
                    current.children[part] = newNode
                    current = newNode
                }
            }
        }
        return root
    }
    
    private static func renderNode(
        node: TreeNode,
        prefix: String,
        isLast: Bool,
        currentDepth: Int,
        maxDepth: Int?,
        output: inout String
    ) {
        // 根节点无需打印自身标签
        if !node.name.isEmpty {
            let connector = isLast ? "└── " : "├── "
            let icon = node.isDirectory ? "📁 " : "📄 "
            let sizeInfo = node.isDirectory ? "" : " (\(formatBytes(node.sizeBytes)))"
            output += "\(prefix)\(connector)\(icon)\(node.name)\(sizeInfo)\n"
        }
        
        // 深度限制判定
        if let max = maxDepth, currentDepth >= max {
            if !node.children.isEmpty && !node.name.isEmpty {
                let nextPrefix = prefix + (isLast ? "    " : "│   ")
                output += "\(nextPrefix)└── ... (\(node.children.count) sub-items collapsed)\n"
            }
            return
        }
        
        let childPrefix = node.name.isEmpty ? "" : prefix + (isLast ? "    " : "│   ")
        let sortedKeys = node.children.keys.sorted { a, b in
            let nodeA = node.children[a]!
            let nodeB = node.children[b]!
            if nodeA.isDirectory != nodeB.isDirectory {
                return nodeA.isDirectory && !nodeB.isDirectory
            }
            return a.localizedStandardCompare(b) == .orderedAscending
        }
        
        for (idx, key) in sortedKeys.enumerated() {
            let child = node.children[key]!
            let isLastChild = (idx == sortedKeys.count - 1)
            renderNode(
                node: child,
                prefix: childPrefix,
                isLast: isLastChild,
                currentDepth: currentDepth + 1,
                maxDepth: maxDepth,
                output: &output
            )
        }
    }
    
    private static func formatBytes(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        let kb = Double(bytes) / 1024.0
        if kb < 1024 { return String(format: "%.1f KB", kb) }
        let mb = kb / 1024.0
        if mb < 1024 { return String(format: "%.1f MB", mb) }
        let gb = mb / 1024.0
        return String(format: "%.2f GB", gb)
    }
}
