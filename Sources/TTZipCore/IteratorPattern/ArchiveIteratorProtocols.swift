import Foundation

// MARK: - 统一归档迭代器协议 (Archive Iterator Protocol)

/// 迭代器模式核心抽象接口
/// 继承与契合 Swift 原生 `IteratorProtocol` 与 `Sequence`，提供标准化元素迭代、Peek 预览、重置与跳跃访问能力
public protocol ArchiveIteratorProtocol: IteratorProtocol, Sequence where Element == ArchiveEntry {
    /// 提取下一个归档条目 (IteratorProtocol 核心 API)
    mutating func next() -> ArchiveEntry?
    
    /// 前瞻/预览下一个归档条目，但不移动内部游标指针 (幂等操作)
    func peek() -> ArchiveEntry?
    
    /// 重置游标回起始状态 (幂等操作)
    mutating func reset()
    
    /// 迭代器管理的总条目数量
    var count: Int { get }
    
    /// 是否已迭代至末尾
    var isAtEnd: Bool { get }
    
    /// 向前跳过指定数量的条目，返回实际跳过的条目数量
    @discardableResult
    mutating func skip(count: Int) -> Int
}

// MARK: - Swift Sequence 原生契合扩展

extension ArchiveIteratorProtocol {
    /// 默认 Sequence 实现：迭代器自身充当 Iterator
    public func makeIterator() -> Self {
        return self
    }
    
    /// 默认末尾检查
    public var isAtEnd: Bool {
        return peek() == nil
    }
    
    /// 默认跳过逻辑
    @discardableResult
    public mutating func skip(count step: Int) -> Int {
        guard step > 0 else { return 0 }
        var skipped = 0
        while skipped < step, next() != nil {
            skipped += 1
        }
        return skipped
    }
}

// MARK: - ArchiveComponentProtocol 辅助转化

extension ArchiveComponentProtocol {
    /// 将组合 Component 节点安全转化为标准的 ArchiveEntry 属性数据
    public var asArchiveEntry: ArchiveEntry {
        if let leaf = self as? ArchiveLeafFile, let entry = leaf.entry {
            return entry
        } else if let composite = self as? ArchiveCompositeDirectory, let entry = composite.entry {
            return entry
        } else {
            return ArchiveEntry(
                path: path,
                uncompressedSize: sizeBytes,
                isDirectory: isDirectory,
                modificationDate: (self as? ArchiveLeafFile)?.modificationDate ?? (self as? ArchiveCompositeDirectory)?.modificationDate
            )
        }
    }
}
