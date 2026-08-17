import Foundation

/// 广度优先组合树迭代器 (Breadth-First Tree Iterator)
/// 按层级 Queue 队列顺序依次遍历 `ArchiveCompositeDirectory` / `ArchiveTreeNode` / `ArchiveComponentProtocol` 组合树
public final class BreadthFirstTreeIterator: ArchiveIteratorProtocol, @unchecked Sendable {
    public typealias Element = ArchiveEntry
    
    private let rootComponent: ArchiveComponentProtocol
    private var cachedTotalNodeCount: Int?
    private var queue: [ArchiveComponentProtocol] = []
    private let lock = NSLock()
    
    public init(root: ArchiveComponentProtocol) {
        self.rootComponent = root
        self.resetState()
    }
    
    private func computeTotalNodes(_ node: ArchiveComponentProtocol) -> Int {
        if !node.isDirectory { return 1 }
        var sum = 1
        for child in node.getChildren() {
            sum += computeTotalNodes(child)
        }
        return sum
    }
    
    private func resetState() {
        queue.removeAll(keepingCapacity: true)
        queue.append(rootComponent)
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
        return queue.isEmpty
    }
    
    public func peek() -> ArchiveEntry? {
        lock.lock()
        defer { lock.unlock() }
        return queue.first?.asArchiveEntry
    }
    
    public func next() -> ArchiveEntry? {
        lock.lock()
        defer { lock.unlock() }
        guard !queue.isEmpty else { return nil }
        let curr = queue.removeFirst()
        let children = curr.getChildren()
        queue.append(contentsOf: children)
        return curr.asArchiveEntry
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
        while skipped < step && !queue.isEmpty {
            let curr = queue.removeFirst()
            queue.append(contentsOf: curr.getChildren())
            skipped += 1
        }
        return skipped
    }
}
