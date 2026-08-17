import Foundation

/// 排序维度属性
public enum ArchiveSortKey: Sendable {
    case path
    case name
    case size
    case modificationDate
}

/// 排序方向
public enum ArchiveSortOrder: Sendable {
    case ascending
    case descending
}

/// 数组归档迭代器 (Array Archive Iterator)
/// 支持在内存数组之上的高级谓词过滤 (扩展名/文件大小/名称/正则/自定义谓词)、多维排序、切片与幂等指针控制
public final class ArrayArchiveIterator: ArchiveIteratorProtocol, @unchecked Sendable {
    public typealias Element = ArchiveEntry
    
    private let rawEntries: [ArchiveEntry]
    private var filteredEntries: [ArchiveEntry]
    private var currentIndex: Int = 0
    private let lock = NSLock()
    
    public init(
        entries: [ArchiveEntry],
        extensions: Set<String>? = nil,
        minSize: Int64? = nil,
        maxSize: Int64? = nil,
        namePattern: String? = nil,
        regexPattern: String? = nil,
        predicate: (@Sendable (ArchiveEntry) -> Bool)? = nil,
        sortBy: ArchiveSortKey? = nil,
        sortOrder: ArchiveSortOrder = .ascending
    ) {
        self.rawEntries = entries
        var result = entries
        
        // 1. 扩展名过滤
        if let exts = extensions, !exts.isEmpty {
            let lowerExts = Set(exts.map { $0.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")) })
            result = result.filter { entry in
                let ext = (entry.name as NSString).pathExtension.lowercased()
                return lowerExts.contains(ext)
            }
        }
        
        // 2. 文件大小过滤
        if let minS = minSize {
            result = result.filter { $0.uncompressedSize >= minS }
        }
        if let maxS = maxSize {
            result = result.filter { $0.uncompressedSize <= maxS }
        }
        
        // 3. 名称子串过滤
        if let pattern = namePattern, !pattern.isEmpty {
            result = result.filter { $0.path.localizedCaseInsensitiveContains(pattern) }
        }
        
        // 4. 正则表达式过滤
        if let regexStr = regexPattern, !regexStr.isEmpty, let regex = try? NSRegularExpression(pattern: regexStr, options: [.caseInsensitive]) {
            result = result.filter { entry in
                let range = NSRange(location: 0, length: entry.path.utf16.count)
                return regex.firstMatch(in: entry.path, options: [], range: range) != nil
            }
        }
        
        // 5. 自定义谓词过滤
        if let pred = predicate {
            result = result.filter(pred)
        }
        
        // 6. 排序
        if let key = sortBy {
            result.sort { a, b in
                let isAsc = (sortOrder == .ascending)
                switch key {
                case .path:
                    let cmp = a.path.localizedStandardCompare(b.path) == .orderedAscending
                    return isAsc ? cmp : !cmp
                case .name:
                    let cmp = a.name.localizedStandardCompare(b.name) == .orderedAscending
                    return isAsc ? cmp : !cmp
                case .size:
                    if a.uncompressedSize != b.uncompressedSize {
                        return isAsc ? (a.uncompressedSize < b.uncompressedSize) : (a.uncompressedSize > b.uncompressedSize)
                    }
                    return a.path < b.path
                case .modificationDate:
                    let d1 = a.modificationDate ?? Date.distantPast
                    let d2 = b.modificationDate ?? Date.distantPast
                    if d1 != d2 {
                        return isAsc ? (d1 < d2) : (d1 > d2)
                    }
                    return a.path < b.path
                }
            }
        }
        
        self.filteredEntries = result
    }
    
    /// 切片获取子迭代器 API (Pagination / Slicing)
    public func slice(offset: Int, limit: Int) -> ArrayArchiveIterator {
        lock.lock()
        defer { lock.unlock() }
        let start = Swift.max(0, Swift.min(offset, filteredEntries.count))
        let end = Swift.max(start, Swift.min(start + limit, filteredEntries.count))
        let sliced = Array(filteredEntries[start..<end])
        return ArrayArchiveIterator(entries: sliced)
    }
    
    // MARK: - ArchiveIteratorProtocol
    
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return filteredEntries.count
    }
    
    public var isAtEnd: Bool {
        lock.lock()
        defer { lock.unlock() }
        return currentIndex >= filteredEntries.count
    }
    
    public func peek() -> ArchiveEntry? {
        lock.lock()
        defer { lock.unlock() }
        guard currentIndex < filteredEntries.count else { return nil }
        return filteredEntries[currentIndex]
    }
    
    public func next() -> ArchiveEntry? {
        lock.lock()
        defer { lock.unlock() }
        guard currentIndex < filteredEntries.count else { return nil }
        let entry = filteredEntries[currentIndex]
        currentIndex += 1
        return entry
    }
    
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        currentIndex = 0
    }
    
    @discardableResult
    public func skip(count step: Int) -> Int {
        lock.lock()
        defer { lock.unlock() }
        guard step > 0 else { return 0 }
        let remaining = filteredEntries.count - currentIndex
        let actualSkip = Swift.min(step, Swift.max(0, remaining))
        currentIndex += actualSkip
        return actualSkip
    }
}
