import Foundation

// MARK: - 访问者模式核心接口 (GoF Visitor Pattern Protocols)

/// GoF 23 种设计模式收官之作 — 访问者模式 (Visitor Pattern) 核心访问者接口
/// 封装作用于 `ArchiveComponentProtocol` 组合树中各元素的操作，可以在不改变各元素的类的前提下定义作用于这些元素的新操作。
public protocol ArchiveComponentVisitorProtocol<Result> {
    associatedtype Result
    
    /// 访问叶子节点 (Single Leaf File)
    func visit(leaf: ArchiveLeafFile) -> Result
    
    /// 访问组合目录节点 (Composite Directory)
    func visit(directory: ArchiveCompositeDirectory) -> Result
}

// MARK: - 闭包访问者类型 (Closure-based Visitor)

public struct ArchiveComponentVisitor<Result>: Sendable {
    public let visitLeafBlock: @Sendable (ArchiveLeafFile) -> Result
    public let visitCompositeBlock: @Sendable (ArchiveCompositeDirectory) -> Result
    
    public init(
        visitLeaf: @escaping @Sendable (ArchiveLeafFile) -> Result,
        visitComposite: @escaping @Sendable (ArchiveCompositeDirectory) -> Result
    ) {
        self.visitLeafBlock = visitLeaf
        self.visitCompositeBlock = visitComposite
    }
}

// MARK: - 访问者双向与兼容默认实现

extension ArchiveComponentVisitorProtocol {
    /// 兼容与替代访问方法 (Composite Directory Alias)
    public func visit(composite: ArchiveCompositeDirectory) -> Result {
        return visit(directory: composite)
    }
}

// MARK: - 组合组件协议扩展 (Double Dispatch Protocol Extensions)

extension ArchiveComponentProtocol {
    /// 强类型访问者双重分发 API (Double Dispatch API)
    public func accept<V: ArchiveComponentVisitorProtocol>(visitor: V) -> V.Result {
        if let leaf = self as? ArchiveLeafFile {
            return visitor.visit(leaf: leaf)
        } else if let directory = self as? ArchiveCompositeDirectory {
            return visitor.visit(directory: directory)
        } else {
            fatalError("Unsupported ArchiveComponentProtocol type: \(type(of: self))")
        }
    }
}
