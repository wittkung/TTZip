import Foundation

/// 磁盘延迟流式迭代器 (Lazy Disk Scanner Iterator)
/// 封装 `FileManager.DirectoryEnumerator`，实现无需全量载入内存的流式文件扫描与谓词拦截
public final class LazyDiskScannerIterator: ArchiveIteratorProtocol, @unchecked Sendable {
    public typealias Element = ArchiveEntry
    
    private let rootURL: URL
    private let enumerationOptions: FileManager.DirectoryEnumerationOptions
    private let urlPredicate: (@Sendable (URL) -> Bool)?
    private let entryPredicate: (@Sendable (ArchiveEntry) -> Bool)?
    
    private var enumerator: FileManager.DirectoryEnumerator?
    private var peekedBuffer: ArchiveEntry?
    private var yieldedCount: Int = 0
    private let lock = NSLock()
    
    public init(
        rootURL: URL,
        options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles],
        urlPredicate: (@Sendable (URL) -> Bool)? = nil,
        entryPredicate: (@Sendable (ArchiveEntry) -> Bool)? = nil
    ) {
        self.rootURL = rootURL
        self.enumerationOptions = options
        self.urlPredicate = urlPredicate
        self.entryPredicate = entryPredicate
        
        self.initEnumerator()
    }
    
    public convenience init(
        diskPath: String,
        options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles],
        urlPredicate: (@Sendable (URL) -> Bool)? = nil,
        entryPredicate: (@Sendable (ArchiveEntry) -> Bool)? = nil
    ) {
        let url = URL(fileURLWithPath: diskPath)
        self.init(rootURL: url, options: options, urlPredicate: urlPredicate, entryPredicate: entryPredicate)
    }
    
    private func initEnumerator() {
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
        self.enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: keys,
            options: enumerationOptions
        )
        self.peekedBuffer = nil
        self.yieldedCount = 0
    }
    
    deinit {
        lock.lock()
        enumerator = nil
        peekedBuffer = nil
        lock.unlock()
    }
    
    /// 显式关闭并释放底层 DirectoryEnumerator 资源句柄 (供 for-in 循环中途 break 提前中断时手动销毁句柄)
    public func close() {
        lock.lock()
        defer { lock.unlock() }
        enumerator = nil
        peekedBuffer = nil
    }
    
    private func fetchNextMatchingEntry() -> ArchiveEntry? {
        guard let enumObj = enumerator else { return nil }
        
        let rootPath = rootURL.path
        let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
        
        while let url = enumObj.nextObject() as? URL {
            if let pred = urlPredicate, !pred(url) {
                continue
            }
            
            let values = try? url.resourceValues(forKeys: resourceKeys)
            let isDir = values?.isDirectory ?? false
            let size = Int64(values?.fileSize ?? 0)
            let modDate = values?.contentModificationDate
            
            let itemPath = url.path
            let relPath: String
            if itemPath.hasPrefix(rootPath) {
                let sub = String(itemPath.dropFirst(rootPath.count))
                relPath = sub.hasPrefix("/") ? String(sub.dropFirst()) : sub
            } else {
                relPath = url.lastPathComponent
            }
            
            guard !relPath.isEmpty else { continue }
            
            let entry = ArchiveEntry(
                path: relPath,
                uncompressedSize: size,
                isDirectory: isDir,
                modificationDate: modDate
            )
            
            if let entryPred = entryPredicate, !entryPred(entry) {
                continue
            }
            
            return entry
        }
        
        // 自然迭代结束：立刻彻底释放 DirectoryEnumerator 句柄与描述符
        self.enumerator = nil
        return nil
    }
    
    // MARK: - ArchiveIteratorProtocol
    
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return yieldedCount + (peekedBuffer != nil ? 1 : 0)
    }
    
    public var isAtEnd: Bool {
        lock.lock()
        defer { lock.unlock() }
        if peekedBuffer != nil { return false }
        peekedBuffer = fetchNextMatchingEntry()
        return peekedBuffer == nil
    }
    
    public func peek() -> ArchiveEntry? {
        lock.lock()
        defer { lock.unlock() }
        if let buffered = peekedBuffer {
            return buffered
        }
        let fetched = fetchNextMatchingEntry()
        self.peekedBuffer = fetched
        return fetched
    }
    
    public func next() -> ArchiveEntry? {
        lock.lock()
        defer { lock.unlock() }
        if let buffered = peekedBuffer {
            peekedBuffer = nil
            yieldedCount += 1
            return buffered
        }
        if let fetched = fetchNextMatchingEntry() {
            yieldedCount += 1
            return fetched
        }
        return nil
    }
    
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        initEnumerator()
    }
    
    @discardableResult
    public func skip(count step: Int) -> Int {
        lock.lock()
        defer { lock.unlock() }
        guard step > 0 else { return 0 }
        var skipped = 0
        if peekedBuffer != nil {
            peekedBuffer = nil
            yieldedCount += 1
            skipped += 1
        }
        while skipped < step {
            if fetchNextMatchingEntry() != nil {
                yieldedCount += 1
                skipped += 1
            } else {
                break
            }
        }
        return skipped
    }
}

