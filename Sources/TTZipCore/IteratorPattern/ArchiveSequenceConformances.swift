import Foundation

// MARK: - ArchiveCompositeDirectory 原生 Sequence 协议实现

extension ArchiveCompositeDirectory: Sequence {
    public typealias Element = ArchiveEntry
    
    /// 默认 Sequence Iterator：深度优先 (DFS Pre-order) 迭代器
    public func makeIterator() -> DepthFirstTreeIterator {
        return DepthFirstTreeIterator(root: self, order: .preOrder)
    }
    
    /// 显式获取深度优先 (DFS Pre-order / Post-order) 迭代器
    public func makeDepthFirstIterator(order: DFSTraversalOrder = .preOrder) -> DepthFirstTreeIterator {
        return DepthFirstTreeIterator(root: self, order: order)
    }
    
    /// 显式获取广度优先 (BFS) 迭代器
    public func makeBreadthFirstIterator() -> BreadthFirstTreeIterator {
        return BreadthFirstTreeIterator(root: self)
    }
}

// MARK: - ArchiveTreeNode 原生 Sequence 协议实现

extension ArchiveTreeNode: Sequence {
    public typealias Element = ArchiveEntry
    
    /// 默认 Sequence Iterator：深度优先 (DFS Pre-order) 迭代器
    public func makeIterator() -> DepthFirstTreeIterator {
        return DepthFirstTreeIterator(root: self.toComponent(), order: .preOrder)
    }
    
    /// 显式获取深度优先 (DFS) 迭代器
    public func makeDepthFirstIterator(order: DFSTraversalOrder = .preOrder) -> DepthFirstTreeIterator {
        return DepthFirstTreeIterator(root: self.toComponent(), order: order)
    }
    
    /// 显式获取广度优先 (BFS) 迭代器
    public func makeBreadthFirstIterator() -> BreadthFirstTreeIterator {
        return BreadthFirstTreeIterator(root: self.toComponent())
    }
}

// MARK: - ArchiveInspectionResult 原生 Sequence 协议实现

extension ArchiveInspectionResult: Sequence {
    public typealias Element = ArchiveEntry
    
    /// 默认 Sequence Iterator：数组归档迭代器
    public func makeIterator() -> ArrayArchiveIterator {
        return ArrayArchiveIterator(entries: entries)
    }
    
    /// 显式获取带过滤与排序能力的 ArrayArchiveIterator
    public func makeFilteredIterator(
        extensions: Set<String>? = nil,
        minSize: Int64? = nil,
        maxSize: Int64? = nil,
        namePattern: String? = nil,
        regexPattern: String? = nil,
        sortBy: ArchiveSortKey? = nil,
        sortOrder: ArchiveSortOrder = .ascending
    ) -> ArrayArchiveIterator {
        return ArrayArchiveIterator(
            entries: entries,
            extensions: extensions,
            minSize: minSize,
            maxSize: maxSize,
            namePattern: namePattern,
            regexPattern: regexPattern,
            sortBy: sortBy,
            sortOrder: sortOrder
        )
    }
}

// MARK: - ArchiveReader Sequence 扩展

extension ArchiveReader {
    /// 异步获取归档条目的原生 Iterator 实例
    public func makeIterator(
        for archivePath: String,
        password: String? = nil
    ) async throws -> ArrayArchiveIterator {
        let entries = try await inspect(archivePath: archivePath, password: password)
        return ArrayArchiveIterator(entries: entries)
    }
}

// MARK: - ArchiveBatchFacade Sequence 扩展

extension ArchiveBatchFacade {
    /// 辅助转换条目数组为迭代器
    public func makeIterator(for entries: [ArchiveEntry]) -> ArrayArchiveIterator {
        return ArrayArchiveIterator(entries: entries)
    }
}
