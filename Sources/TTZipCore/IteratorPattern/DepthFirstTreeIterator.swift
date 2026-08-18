// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Depth-first traversal order classification.
public enum DFSTraversalOrder: Sendable {
    /// Pre-order: root visited before children.
    case preOrder
    /// Post-order: children visited before root.
    case postOrder
}

/// Depth-first composite tree iterator traversing tree structures using an explicit stack to prevent recursion overflow.
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
