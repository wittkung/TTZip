// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Represents a hierarchical tree node for archive file and directory navigation.
public struct ArchiveTreeNode: Identifiable, Sendable, Equatable {
    public var id: String { path }
    public let name: String
    public let path: String
    public let uncompressedSize: Int64
    public let isDirectory: Bool
    public let detectedEncoding: String
    public var children: [ArchiveTreeNode]?
    public var entry: ArchiveEntry?
    
    public init(
        id: String,
        name: String,
        path: String,
        uncompressedSize: Int64,
        isDirectory: Bool,
        detectedEncoding: String = "UTF-8",
        children: [ArchiveTreeNode]? = nil,
        entry: ArchiveEntry? = nil
    ) {
        self.name = name
        self.path = path
        self.uncompressedSize = uncompressedSize
        self.isDirectory = isDirectory
        self.detectedEncoding = detectedEncoding
        self.children = children
        self.entry = entry
    }
}

// MARK: - PrototypeCopyable Prototype Pattern Extension
extension ArchiveTreeNode: PrototypeCopyable {
    /// Creates a deep clone of the entire tree hierarchy.
    public func clone() -> ArchiveTreeNode {
        return cloneTree()
    }
    
    /// Recursively deep-copies this tree node and all descendants.
    /// - Returns: Independent cloned `ArchiveTreeNode` subtree.
    public func cloneTree() -> ArchiveTreeNode {
        let clonedChildren = children?.map { $0.cloneTree() }
        return ArchiveTreeNode(
            id: self.id,
            name: self.name,
            path: self.path,
            uncompressedSize: self.uncompressedSize,
            isDirectory: self.isDirectory,
            detectedEncoding: self.detectedEncoding,
            children: clonedChildren,
            entry: self.entry
        )
    }
}

// MARK: - ArchiveComponentProtocol Composite Pattern Extension
extension ArchiveTreeNode: ArchiveComponentProtocol {
    public var sizeBytes: Int64 {
        if isDirectory, let children = children, !children.isEmpty {
            return children.reduce(0) { $0 + $1.sizeBytes }
        }
        return uncompressedSize
    }
    
    public func getChildren() -> [ArchiveComponentProtocol] {
        return children?.map { $0 as ArchiveComponentProtocol } ?? []
    }
    
    /// Converts this node into a composite Component (Leaf or Composite Directory).
    public func toComponent() -> ArchiveComponentProtocol {
        if isDirectory {
            let childComponents = (children ?? []).map { $0.toComponent() }
            return ArchiveCompositeDirectory(name: name, path: path, entry: entry, children: childComponents)
        } else {
            return ArchiveLeafFile(name: name, path: path, sizeBytes: uncompressedSize, entry: entry)
        }
    }
    
    /// Reconstructs an `ArchiveTreeNode` from a composite Component.
    public init(component: ArchiveComponentProtocol, detectedEncoding: String = "UTF-8") {
        self.name = component.name
        self.path = component.path
        self.uncompressedSize = component.sizeBytes
        self.isDirectory = component.isDirectory
        self.detectedEncoding = detectedEncoding
        
        let childComponents = component.getChildren()
        if component.isDirectory {
            self.children = childComponents.map { ArchiveTreeNode(component: $0, detectedEncoding: detectedEncoding) }
        } else {
            self.children = nil
        }
        
        if let leaf = component as? ArchiveLeafFile {
            self.entry = leaf.entry
        } else if let composite = component as? ArchiveCompositeDirectory {
            self.entry = composite.entry
        } else {
            self.entry = nil
        }
    }
}

/// Builds a hierarchical list of `ArchiveTreeNode` objects from flat `ArchiveEntry` lists.
public final class ArchiveTreeBuilder: @unchecked Sendable {
    public static func buildTree(from entries: [ArchiveEntry]) -> [ArchiveTreeNode] {
        let rootComponent = ArchiveComponentTreeBuilder.buildTree(from: entries)
        return rootComponent.getChildren().map { ArchiveTreeNode(component: $0) }
    }
}
