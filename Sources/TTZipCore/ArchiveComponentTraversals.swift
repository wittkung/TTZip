// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - Default Protocol Extensions

extension ArchiveComponentProtocol {
    /// Recursively counts all leaf files in the hierarchy.
    public func totalFileCount() -> Int {
        if !isDirectory { return 1 }
        return getChildren().reduce(0) { $0 + $1.totalFileCount() }
    }
    
    /// Recursively counts all composite directory containers (excluding root itself).
    public func totalDirectoryCount() -> Int {
        if !isDirectory { return 0 }
        let childrenDirs = getChildren().filter { $0.isDirectory }
        return childrenDirs.count + childrenDirs.reduce(0) { $0 + $1.totalDirectoryCount() }
    }
    
    /// Flattens all nested leaf files into a sequential array.
    public func flattenLeaves() -> [ArchiveLeafFile] {
        if let leaf = self as? ArchiveLeafFile {
            return [leaf]
        }
        return getChildren().flatMap { $0.flattenLeaves() }
    }
    
    /// Samples leaf file extensions to detect pre-compressed workloads without sorting huge trees.
    public func sampleLeafExtensions(
        maxSamples: Int = 2000,
        preCompressedSet: Set<String>
    ) -> (totalCount: Int, preCompressedCount: Int) {
        var total = 0
        var preCompressed = 0
        
        func traverse(_ node: ArchiveComponentProtocol) {
            if total >= maxSamples { return }
            if node.isDirectory {
                let children = (node as? ArchiveCompositeDirectory)?.getChildrenUnsorted() ?? node.getChildren()
                for child in children {
                    if total >= maxSamples { break }
                    traverse(child)
                }
            } else {
                total += 1
                let ext = (node.path as NSString).pathExtension.lowercased()
                if !ext.isEmpty && preCompressedSet.contains(".\(ext)") {
                    preCompressed += 1
                }
            }
        }
        
        traverse(self)
        return (total, preCompressed)
    }
    
    /// Recursively filters tree nodes matching a given predicate.
    public func search(filter: (ArchiveComponentProtocol) -> Bool) -> [ArchiveComponentProtocol] {
        var results: [ArchiveComponentProtocol] = []
        if filter(self) {
            results.append(self)
        }
        for child in getChildren() {
            results.append(contentsOf: child.search(filter: filter))
        }
        return results
    }

    /// Renders an ASCII Unicode hierarchical tree representation of this component.
    public func renderTree(prefix: String = "", isLast: Bool = true) -> String {
        var result = ""
        let displayName = name.isEmpty ? "." : name
        let sizeStr = isDirectory ? "<DIR>" : ByteCountFormatterFlyweight.shared.string(fromByteCount: sizeBytes)

        if prefix.isEmpty {
            result += "\(displayName) (\(sizeStr))\n"
        } else {
            let connector = isLast ? "└── " : "├── "
            result += "\(prefix)\(connector)\(displayName) (\(sizeStr))\n"
        }

        let children = getChildren()
        let childPrefix = prefix + (prefix.isEmpty ? "" : (isLast ? "    " : "│   "))
        for (index, child) in children.enumerated() {
            let childIsLast = (index == children.count - 1)
            result += child.renderTree(prefix: childPrefix, isLast: childIsLast)
        }
        return result
    }
}

// MARK: - Sequence Collections Extension

extension Sequence where Element == ArchiveComponentProtocol {
    /// Sums total byte size across all components in collection.
    public var totalSizeBytes: Int64 {
        return reduce(0) { $0 + $1.sizeBytes }
    }
    
    /// Counts total leaf files across all components in collection.
    public var totalFileCount: Int {
        return reduce(0) { $0 + $1.totalFileCount() }
    }
    
    /// Counts total directories across all components in collection.
    public var totalDirectoryCount: Int {
        return reduce(0) { $0 + $1.totalDirectoryCount() }
    }
    
    /// Flattens all leaves across collection.
    public func flattenLeaves() -> [ArchiveLeafFile] {
        return flatMap { $0.flattenLeaves() }
    }
}

// MARK: - Tree Builders

/// Factory constructing composite directory trees from flat `ArchiveEntry` sequences or disk paths.
public final class ArchiveComponentTreeBuilder: @unchecked Sendable {
    
    /// Builds a composite directory tree from flat `ArchiveEntry` items.
    public static func buildTree(from entries: [ArchiveEntry]) -> ArchiveCompositeDirectory {
        let root = ArchiveCompositeDirectory(name: "", path: "")
        
        for entry in entries {
            let path = entry.path
            guard !path.isEmpty else { continue }
            
            var currentDir = root
            var startIdx = path.startIndex
            let endIdx = path.endIndex
            
            while startIdx < endIdx {
                let nextSlash = path[startIdx..<endIdx].firstIndex(of: "/") ?? endIdx
                let componentName = String(path[startIdx..<nextSlash])
                let nextIdx = (nextSlash < endIdx) ? path.index(after: nextSlash) : endIdx
                let isLast = (nextIdx >= endIdx)
                let currentPath = String(path[..<nextSlash])
                
                if !componentName.isEmpty {
                    if isLast {
                        if entry.isDirectory {
                            if currentDir.findChildDirect(named: componentName) as? ArchiveCompositeDirectory == nil {
                                let newDir = ArchiveCompositeDirectory(name: componentName, path: currentPath, entry: entry)
                                currentDir.addDirect(component: newDir)
                            }
                        } else {
                            let leaf = ArchiveLeafFile(name: componentName, path: currentPath, sizeBytes: entry.uncompressedSize, entry: entry)
                            currentDir.addDirect(component: leaf)
                        }
                    } else {
                        if let existing = currentDir.findChildDirect(named: componentName) as? ArchiveCompositeDirectory {
                            currentDir = existing
                        } else {
                            let newDir = ArchiveCompositeDirectory(name: componentName, path: currentPath)
                            currentDir.addDirect(component: newDir)
                            currentDir = newDir
                        }
                    }
                }
                startIdx = nextIdx
            }
        }
        return root
    }
    
    /// Scans a physical disk path and builds a composite component tree with symlink cycle detection.
    public static func buildTree(fromDiskPath path: String, visited: Set<String> = []) -> ArchiveComponentProtocol {
        var visitedSet = visited
        return buildTreeInternal(fromDiskPath: path, visited: &visitedSet)
    }
    
    private static func buildTreeInternal(fromDiskPath path: String, visited: inout Set<String>) -> ArchiveComponentProtocol {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir) else {
            return ArchiveLeafFile(name: (path as NSString).lastPathComponent, path: path, sizeBytes: 0)
        }
        
        let url = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        let canonicalPath = url.path
        let name = url.lastPathComponent
        
        if visited.contains(canonicalPath) {
            return ArchiveLeafFile(name: name, path: canonicalPath, sizeBytes: 0)
        }
        
        visited.insert(canonicalPath)
        
        if !isDir.boolValue {
            let sz = Int64((try? fm.attributesOfItem(atPath: canonicalPath)[.size] as? Int64) ?? 0)
            let modDate = try? fm.attributesOfItem(atPath: canonicalPath)[.modificationDate] as? Date
            return ArchiveLeafFile(name: name, path: canonicalPath, sizeBytes: sz, modificationDate: modDate)
        } else {
            let modDate = try? fm.attributesOfItem(atPath: canonicalPath)[.modificationDate] as? Date
            let compositeDir = ArchiveCompositeDirectory(name: name, path: canonicalPath, modificationDate: modDate)
            
            let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
            if let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) {
                for itemURL in contents {
                    let childComponent = buildTreeInternal(fromDiskPath: itemURL.path, visited: &visited)
                    compositeDir.add(component: childComponent)
                }
            }
            return compositeDir
        }
    }
}
