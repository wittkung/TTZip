import Foundation

// MARK: - 访问者模式双重分发与递归传递扩展 (Visitor Pattern Dispatch & Traversal Helpers)

extension ArchiveComponentProtocol {
    /// 辅助方法：向特定访问者广播当前节点
    public func dispatchVisitor<V: ArchiveComponentVisitorProtocol>(_ visitor: V) -> V.Result {
        return self.accept(visitor: visitor)
    }
}

extension ArchiveCompositeDirectory {
    /// 组合容器目录节点的子节点递归遍历分发方法
    public func acceptChildren<V: ArchiveComponentVisitorProtocol>(visitor: V) -> [V.Result] {
        return getChildren().map { $0.accept(visitor: visitor) }
    }
}
