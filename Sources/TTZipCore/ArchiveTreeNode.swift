import Foundation

/// 代表归档文件内部的项目节点（支持树状层级）
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
        let factory = ArchiveEntryFlyweightFactory.shared
        self.name = factory.internPath(name)
        self.path = factory.internPath(path)
        self.uncompressedSize = uncompressedSize
        self.isDirectory = isDirectory
        self.detectedEncoding = factory.internPath(detectedEncoding)
        self.children = children
        self.entry = entry
    }
}

// MARK: - PrototypeCopyable 原型模式扩展
extension ArchiveTreeNode: PrototypeCopyable {
    /// 原型模式默认克隆：递归深拷贝整棵节点树
    public func clone() -> ArchiveTreeNode {
        return cloneTree()
    }
    
    /// 树形层级深拷贝克隆 API (Deep Copy Tree)
    /// - Returns: 全新深拷贝的 ArchiveTreeNode 独立树节点
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


// MARK: - ArchiveComponentProtocol 组合模式扩展
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
    
    public func accept<R>(visitor: ArchiveComponentVisitor<R>) -> R {
        if isDirectory {
            let childComponents = getChildren()
            let composite = ArchiveCompositeDirectory(name: name, path: path, entry: entry, children: childComponents)
            return visitor.visitCompositeBlock(composite)
        } else {
            let leaf = ArchiveLeafFile(name: name, path: path, sizeBytes: uncompressedSize, entry: entry)
            return visitor.visitLeafBlock(leaf)
        }
    }
    
    public func accept<V: ArchiveComponentVisitorProtocol>(visitor: V) -> V.Result {
        if isDirectory {
            let childComponents = getChildren()
            let composite = ArchiveCompositeDirectory(name: name, path: path, entry: entry, children: childComponents)
            return visitor.visit(composite: composite)
        } else {
            let leaf = ArchiveLeafFile(name: name, path: path, sizeBytes: uncompressedSize, entry: entry)
            return visitor.visit(leaf: leaf)
        }
    }
    
    /// 将当前节点转构为标准的组合 Component (Leaf 或 Composite)
    public func toComponent() -> ArchiveComponentProtocol {
        if isDirectory {
            let childComponents = (children ?? []).map { $0.toComponent() }
            return ArchiveCompositeDirectory(name: name, path: path, entry: entry, children: childComponents)
        } else {
            return ArchiveLeafFile(name: name, path: path, sizeBytes: uncompressedSize, entry: entry)
        }
    }
    
    /// 从组合 Component 节点反向构造 ArchiveTreeNode
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


/// 将扁平的 ArchiveEntry 路径列表转构为层级化的 ArchiveTreeNode 目录树
public final class ArchiveTreeBuilder: @unchecked Sendable {
    public static func buildTree(from entries: [ArchiveEntry]) -> [ArchiveTreeNode] {
        let rootComponent = ArchiveComponentTreeBuilder.buildTree(from: entries)
        return rootComponent.getChildren().map { ArchiveTreeNode(component: $0) }
    }
}

