import Foundation

/// 深度优先遍历顺序枚举
public enum DFSTraversalOrder: Sendable {
    /// 前序遍历 (Pre-order: 先访问根节点，再依次访问子节点)
    case preOrder
    /// 后序遍历 (Post-order: 先依次访问完子节点，再访问根节点)
    case postOrder
}

/// 深度优先组合树迭代器 (Depth-First Tree Iterator)
/// 遍历 `ArchiveCompositeDirectory` / `ArchiveTreeNode` / `ArchiveComponentProtocol` 组合树
/// 采用**显式栈 (Explicit Stack) 结构**，杜绝深层嵌套目录导致的 Call Stack 栈溢出 (Stack Overflow)
public final class DepthFirstTreeIterator: ArchiveIteratorProtocol, @unchecked Sendable {
    public typealias Element = ArchiveEntry
    
    private struct PostOrderFrame {
        let node: ArchiveComponentProtocol
        var childIndex: Int
        let children: [ArchiveComponentProtocol]
    }
    
    private let rootComponent: ArchiveComponentProtocol
    private let order: DFSTraversalOrder
    private var cachedTotalNodeCount: Int?
    
    // 显式栈数据结构 (代替递归)
    private var preOrderStack: [ArchiveComponentProtocol] = []
    private var postOrderStack: [PostOrderFrame] = []
    
    private let lock = NSLock()
    
    public init(root: ArchiveComponentProtocol, order: DFSTraversalOrder = .preOrder) {
        self.rootComponent = root
        self.order = order
        self.resetState()
    }
    
    private func computeTotalNodes(_ root: ArchiveComponentProtocol) -> Int {
        var total = 0
        var stack: [ArchiveComponentProtocol] = [root]
        while let node = stack.popLast() {
            total += 1
            if node.isDirectory {
                let children = node.getChildren()
                stack.append(contentsOf: children)
            }
        }
        return total
    }
    
    private func resetState() {
        preOrderStack.removeAll(keepingCapacity: true)
        postOrderStack.removeAll(keepingCapacity: true)
        
        switch order {
        case .preOrder:
            preOrderStack.append(rootComponent)
        case .postOrder:
            let frame = PostOrderFrame(node: rootComponent, childIndex: 0, children: rootComponent.getChildren())
            postOrderStack.append(frame)
            advancePostOrder()
        }
    }
    
    /// 后序遍历显式栈推进逻辑：推进至最左侧未遍历的叶节点/子树
    private func advancePostOrder() {
        while !postOrderStack.isEmpty {
            let topIndex = postOrderStack.count - 1
            let frame = postOrderStack[topIndex]
            if frame.childIndex < frame.children.count {
                let child = frame.children[frame.childIndex]
                postOrderStack[topIndex].childIndex += 1
                let childFrame = PostOrderFrame(node: child, childIndex: 0, children: child.getChildren())
                postOrderStack.append(childFrame)
            } else {
                // 当前栈顶节点的所有子节点已访问完毕，准备被产出
                break
            }
        }
    }
    
    // MARK: - ArchiveIteratorProtocol
    
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        if let cached = cachedTotalNodeCount {
            return cached
        }
        let total = computeTotalNodes(rootComponent)
        cachedTotalNodeCount = total
        return total
    }
    
    public var isAtEnd: Bool {
        lock.lock()
        defer { lock.unlock() }
        switch order {
        case .preOrder:
            return preOrderStack.isEmpty
        case .postOrder:
            return postOrderStack.isEmpty
        }
    }
    
    public func peek() -> ArchiveEntry? {
        lock.lock()
        defer { lock.unlock() }
        switch order {
        case .preOrder:
            return preOrderStack.last?.asArchiveEntry
        case .postOrder:
            return postOrderStack.last?.node.asArchiveEntry
        }
    }
    
    public func next() -> ArchiveEntry? {
        lock.lock()
        defer { lock.unlock() }
        
        switch order {
        case .preOrder:
            guard let curr = preOrderStack.popLast() else { return nil }
            let children = curr.getChildren()
            for child in children.reversed() {
                preOrderStack.append(child)
            }
            return curr.asArchiveEntry
            
        case .postOrder:
            guard let readyFrame = postOrderStack.popLast() else { return nil }
            advancePostOrder()
            return readyFrame.node.asArchiveEntry
        }
    }
    
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        resetState()
    }
    
    @discardableResult
    public func skip(count step: Int) -> Int {
        lock.lock()
        defer { lock.unlock() }
        guard step > 0 else { return 0 }
        var skipped = 0
        while skipped < step {
            switch order {
            case .preOrder:
                guard let curr = preOrderStack.popLast() else { return skipped }
                let children = curr.getChildren()
                for child in children.reversed() {
                    preOrderStack.append(child)
                }
                skipped += 1
            case .postOrder:
                guard postOrderStack.popLast() != nil else { return skipped }
                advancePostOrder()
                skipped += 1
            }
        }
        return skipped
    }
}
