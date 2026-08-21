// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - TreeRendererVisitor

/// Formats composite directory tree into formatted ASCII tree text (`├── file.txt`, `└── folder/`).
public final class TreeRendererVisitor: ArchiveComponentVisitorProtocol, @unchecked Sendable {
    public typealias Result = String
    
    private let includeSize: Bool
    private let currentIndent: String
    private let isLast: Bool
    private let isRoot: Bool
    
    public init(includeSize: Bool = false) {
        self.includeSize = includeSize
        self.currentIndent = ""
        self.isLast = true
        self.isRoot = true
    }
    
    private init(includeSize: Bool, currentIndent: String, isLast: Bool, isRoot: Bool) {
        self.includeSize = includeSize
        self.currentIndent = currentIndent
        self.isLast = isLast
        self.isRoot = isRoot
    }
    
    public func visit(leaf: ArchiveLeafFile) -> String {
        let prefix = isRoot ? "" : (isLast ? "└── " : "├── ")
        let sizeInfo = includeSize ? " (\(formatBytes(leaf.sizeBytes)))" : ""
        return "\(currentIndent)\(prefix)\(leaf.name)\(sizeInfo)"
    }
    
    public func visit(directory: ArchiveCompositeDirectory) -> String {
        let nameStr = directory.name.isEmpty ? "." : directory.name
        let dirHeader: String
        if isRoot {
            dirHeader = "\(nameStr)/"
        } else {
            let prefix = isLast ? "└── " : "├── "
            dirHeader = "\(currentIndent)\(prefix)\(nameStr)/"
        }
        
        let children = directory.getChildren()
        if children.isEmpty {
            return dirHeader
        }
        
        let childIndent: String
        if isRoot {
            childIndent = ""
        } else {
            childIndent = currentIndent + (isLast ? "    " : "│   ")
        }
        
        var lines: [String] = [dirHeader]
        for (index, child) in children.enumerated() {
            let childIsLast = (index == children.count - 1)
            let childVisitor = TreeRendererVisitor(
                includeSize: includeSize,
                currentIndent: childIndent,
                isLast: childIsLast,
                isRoot: false
            )
            lines.append(child.accept(visitor: childVisitor))
        }
        
        return lines.joined(separator: "\n")
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        return ByteCountFormatterCache.string(fromByteCount: bytes)
    }
}
