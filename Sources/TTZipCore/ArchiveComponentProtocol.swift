import Foundation

// MARK: - 统一组合组件协议 (Composite Component Protocol)

/// 组合模式核心接口：统一“单一文件 (Leaf)”与“文件夹容器 (Composite)”的操作接口
public protocol ArchiveComponentProtocol: Sendable {
    /// 节点名称 (例如: "document.txt" 或 "Photos")
    var name: String { get }
    
    /// 节点相对或绝对路径 (例如: "Photos/document.txt")
    var path: String { get }
    
    /// 是否为目录
    var isDirectory: Bool { get }
    
    /// 节点（含其所有子节点）的总字节大小 (Composite 模式透明计算)
    var sizeBytes: Int64 { get }
    
    /// 获取直接子节点列表 (Leaf 返回空数组，Composite 返回子节点集合)
    func getChildren() -> [ArchiveComponentProtocol]
    
    /// 接受闭包访问者 (Accept Closure Visitor)
    func accept<R>(visitor: ArchiveComponentVisitor<R>) -> R
    
    /// 接受强类型访问者 (Accept Typed Visitor)
    func accept<V: ArchiveComponentVisitorProtocol>(visitor: V) -> V.Result
}

// MARK: - 通用默认扩展 (Default Protocol Extensions)

extension ArchiveComponentProtocol {
    /// 递归计算整棵树中所有的文件 (Leaf) 数量
    public func totalFileCount() -> Int {
        if !isDirectory { return 1 }
        return getChildren().reduce(0) { $0 + $1.totalFileCount() }
    }
    
    /// 递归计算整棵树中所有的子文件夹 (Composite) 数量 (不含根节点自身)
    public func totalDirectoryCount() -> Int {
        if !isDirectory { return 0 }
        let childrenDirs = getChildren().filter { $0.isDirectory }
        return childrenDirs.count + childrenDirs.reduce(0) { $0 + $1.totalDirectoryCount() }
    }
    
    /// 提取整棵树下所有的叶子节点文件
    public func flattenLeaves() -> [ArchiveLeafFile] {
        if let leaf = self as? ArchiveLeafFile {
            return [leaf]
        }
        return getChildren().flatMap { $0.flattenLeaves() }
    }
    
    /// 流式采样提取树下叶子节点扩展名分布（避免超大目录 50,000+ 节点时构建海量数组与 50,000 次 localizedStandardCompare 带来的开销）
    public func sampleLeafExtensions(
        maxSamples: Int = 2000,
        preCompressedSet: Set<String>
    ) -> (totalCount: Int, preCompressedCount: Int) {
        var total = 0
        var preCompressed = 0
        
        func traverse(_ node: ArchiveComponentProtocol) {
            if total >= maxSamples { return }
            if node.isDirectory {
                let children = (node as? ArchiveCompositeDirectory)?.getChildrenUnsorted() ?? node.getChildren()
                for child in children {
                    if total >= maxSamples { break }
                    traverse(child)
                }
            } else {
                total += 1
                let ext = (node.path as NSString).pathExtension.lowercased()
                if !ext.isEmpty && preCompressedSet.contains(".\(ext)") {
                    preCompressed += 1
                }
            }
        }
        
        traverse(self)
        return (total, preCompressed)
    }
    
    /// 递归过滤搜索树节点
    public func search(filter: (ArchiveComponentProtocol) -> Bool) -> [ArchiveComponentProtocol] {
        var results: [ArchiveComponentProtocol] = []
        if filter(self) {
            results.append(self)
        }
        for child in getChildren() {
            results.append(contentsOf: child.search(filter: filter))
        }
        return results
    }

    /// 渲染 Component 树形 ASCII 视图字符串 (用于 CLI 层级展示)
    public func renderTree(prefix: String = "", isLast: Bool = true) -> String {
        var result = ""
        let displayName = name.isEmpty ? "." : name
        let sizeStr = isDirectory ? "<DIR>" : ByteCountFormatterFlyweight.shared.string(fromByteCount: sizeBytes)

        if prefix.isEmpty {
            result += "\(displayName) (\(sizeStr))\n"
        } else {
            let connector = isLast ? "└── " : "├── "
            result += "\(prefix)\(connector)\(displayName) (\(sizeStr))\n"
        }

        let children = getChildren()
        let childPrefix = prefix + (prefix.isEmpty ? "" : (isLast ? "    " : "│   "))
        for (index, child) in children.enumerated() {
            let childIsLast = (index == children.count - 1)
            result += child.renderTree(prefix: childPrefix, isLast: childIsLast)
        }
        return result
    }
}

// MARK: - ArchiveComponentProtocol 集合扩展 (Collection Extensions)

extension Sequence where Element == ArchiveComponentProtocol {
    /// 动态透明计算集合中所有 Component 的字节总和
    public var totalSizeBytes: Int64 {
        return reduce(0) { $0 + $1.sizeBytes }
    }
    
    /// 动态计算集合中所有文件 (Leaf) 的总数量
    public var totalFileCount: Int {
        return reduce(0) { $0 + $1.totalFileCount() }
    }
    
    /// 动态计算集合中所有目录 (Composite) 的总数量
    public var totalDirectoryCount: Int {
        return reduce(0) { $0 + $1.totalDirectoryCount() }
    }
    
    /// 提取集合中所有叶子节点文件
    public func flattenLeaves() -> [ArchiveLeafFile] {
        return flatMap { $0.flattenLeaves() }
    }
}

// MARK: - 叶子节点 (Leaf Node: Single File)

public final class ArchiveLeafFile: ArchiveComponentProtocol, Identifiable, Equatable, @unchecked Sendable {
    public var id: String { path }
    public let name: String
    public let path: String
    public let sizeBytes: Int64
    public let isDirectory: Bool = false
    public let entry: ArchiveEntry?
    public let modificationDate: Date?
    public let compressedSizeBytes: Int64?
    public let crc32: UInt32?
    
    public init(
        name: String,
        path: String,
        sizeBytes: Int64,
        entry: ArchiveEntry? = nil,
        modificationDate: Date? = nil,
        compressedSizeBytes: Int64? = nil,
        crc32: UInt32? = nil
    ) {
        let factory = ArchiveEntryFlyweightFactory.shared
        self.name = factory.internPath(name)
        self.path = factory.internPath(path)
        self.sizeBytes = sizeBytes
        self.entry = entry
        self.modificationDate = modificationDate
        self.compressedSizeBytes = compressedSizeBytes
        self.crc32 = crc32
    }
    
    public func getChildren() -> [ArchiveComponentProtocol] {
        return []
    }
    
    public func accept<R>(visitor: ArchiveComponentVisitor<R>) -> R {
        return visitor.visitLeafBlock(self)
    }
    
    public func accept<V: ArchiveComponentVisitorProtocol>(visitor: V) -> V.Result {
        return visitor.visit(leaf: self)
    }
    
    public static func == (lhs: ArchiveLeafFile, rhs: ArchiveLeafFile) -> Bool {
        return lhs.path == rhs.path && lhs.sizeBytes == rhs.sizeBytes
    }
}

// MARK: - 组合容器节点 (Composite Container Node: Directory)

public final class ArchiveCompositeDirectory: ArchiveComponentProtocol, Identifiable, Equatable, @unchecked Sendable {
    public var id: String { path }
    public let name: String
    public let path: String
    public let isDirectory: Bool = true
    public let entry: ArchiveEntry?
    public let modificationDate: Date?
    
    private var childrenMap: [String: ArchiveComponentProtocol] = [:]
    private let lock = NSLock()
    
    public init(
        name: String,
        path: String,
        entry: ArchiveEntry? = nil,
        modificationDate: Date? = nil,
        children: [ArchiveComponentProtocol] = []
    ) {
        let factory = ArchiveEntryFlyweightFactory.shared
        self.name = factory.internPath(name)
        self.path = factory.internPath(path)
        self.entry = entry
        self.modificationDate = modificationDate
        for child in children {
            self.childrenMap[child.name] = child
        }
    }
    
    /// Composite 核心：动态透明递归计算所有子节点的总字节大小
    public var sizeBytes: Int64 {
        lock.lock()
        defer { lock.unlock() }
        return childrenMap.values.reduce(0) { $0 + $1.sizeBytes }
    }
    
    /// 获取未排序子节点（O(1) 拷贝无 50,000 次 localizedStandardCompare 排序开销，供流式采样与快速遍历使用）
    public func getChildrenUnsorted() -> [ArchiveComponentProtocol] {
        lock.lock()
        defer { lock.unlock() }
        return Array(childrenMap.values)
    }
    
    /// 获取子节点（并按文件夹优先、名称字母升序排序）
    public func getChildren() -> [ArchiveComponentProtocol] {
        lock.lock()
        let items = Array(childrenMap.values)
        lock.unlock()
        
        return items.sorted { a, b in
            if a.isDirectory != b.isDirectory {
                return a.isDirectory && !b.isDirectory
            }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }
    
    /// 内部非加锁直接添加子节点（仅供树初始化单线程阶段使用）
    internal func addDirect(component: ArchiveComponentProtocol) {
        childrenMap[component.name] = component
    }

    /// 内部非加锁直接查找子节点（仅供树初始化单线程阶段使用）
    internal func findChildDirect(named name: String) -> ArchiveComponentProtocol? {
        return childrenMap[name]
    }

    /// 动态添加子节点
    public func add(component: ArchiveComponentProtocol) {
        lock.lock()
        defer { lock.unlock() }
        childrenMap[component.name] = component
    }
    
    /// 移除指定名称的子节点
    public func remove(componentNamed name: String) {
        lock.lock()
        defer { lock.unlock() }
        childrenMap.removeValue(forKey: name)
    }
    
    /// 清空所有子节点
    public func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        childrenMap.removeAll()
    }
    
    /// 查找直接子节点
    public func findChild(named name: String) -> ArchiveComponentProtocol? {
        lock.lock()
        defer { lock.unlock() }
        return childrenMap[name]
    }
    
    public func accept<R>(visitor: ArchiveComponentVisitor<R>) -> R {
        return visitor.visitCompositeBlock(self)
    }
    
    public func accept<V: ArchiveComponentVisitorProtocol>(visitor: V) -> V.Result {
        return visitor.visit(directory: self)
    }
    
    public static func == (lhs: ArchiveCompositeDirectory, rhs: ArchiveCompositeDirectory) -> Bool {
        return lhs.path == rhs.path && lhs.getChildren().count == rhs.getChildren().count
    }
}

// MARK: - 组合树构建器 (ArchiveComponentTreeBuilder)

public final class ArchiveComponentTreeBuilder: @unchecked Sendable {
    
    /// 从 ArchiveEntry 扁平条目列表构造组合 Component 目录树
    public static func buildTree(from entries: [ArchiveEntry]) -> ArchiveCompositeDirectory {
        let root = ArchiveCompositeDirectory(name: "", path: "")
        
        for entry in entries {
            let path = entry.path
            guard !path.isEmpty else { continue }
            
            var currentDir = root
            var startIdx = path.startIndex
            let endIdx = path.endIndex
            
            while startIdx < endIdx {
                let nextSlash = path[startIdx..<endIdx].firstIndex(of: "/") ?? endIdx
                let componentName = String(path[startIdx..<nextSlash])
                let nextIdx = (nextSlash < endIdx) ? path.index(after: nextSlash) : endIdx
                let isLast = (nextIdx >= endIdx)
                let currentPath = String(path[..<nextSlash])
                
                if !componentName.isEmpty {
                    if isLast {
                        if entry.isDirectory {
                            if currentDir.findChildDirect(named: componentName) as? ArchiveCompositeDirectory == nil {
                                let newDir = ArchiveCompositeDirectory(name: componentName, path: currentPath, entry: entry)
                                currentDir.addDirect(component: newDir)
                            }
                        } else {
                            let leaf = ArchiveLeafFile(name: componentName, path: currentPath, sizeBytes: entry.uncompressedSize, entry: entry)
                            currentDir.addDirect(component: leaf)
                        }
                    } else {
                        if let existing = currentDir.findChildDirect(named: componentName) as? ArchiveCompositeDirectory {
                            currentDir = existing
                        } else {
                            let newDir = ArchiveCompositeDirectory(name: componentName, path: currentPath)
                            currentDir.addDirect(component: newDir)
                            currentDir = newDir
                        }
                    }
                }
                startIdx = nextIdx
            }
        }
        return root
    }
    
    /// 从磁盘路径扫描构造组合 Component 节点（单文件返回 Leaf，目录返回 Composite 树，并支持防死循环符号链接去重）
    public static func buildTree(fromDiskPath path: String, visited: Set<String> = []) -> ArchiveComponentProtocol {
        var visitedSet = visited
        return buildTreeInternal(fromDiskPath: path, visited: &visitedSet)
    }
    
    private static func buildTreeInternal(fromDiskPath path: String, visited: inout Set<String>) -> ArchiveComponentProtocol {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir) else {
            return ArchiveLeafFile(name: (path as NSString).lastPathComponent, path: path, sizeBytes: 0)
        }
        
        let url = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        let canonicalPath = url.path
        let name = url.lastPathComponent
        
        if visited.contains(canonicalPath) {
            return ArchiveLeafFile(name: name, path: canonicalPath, sizeBytes: 0)
        }
        
        visited.insert(canonicalPath)
        
        if !isDir.boolValue {
            let sz = Int64((try? fm.attributesOfItem(atPath: canonicalPath)[.size] as? Int64) ?? 0)
            let modDate = try? fm.attributesOfItem(atPath: canonicalPath)[.modificationDate] as? Date
            return ArchiveLeafFile(name: name, path: canonicalPath, sizeBytes: sz, modificationDate: modDate)
        } else {
            let modDate = try? fm.attributesOfItem(atPath: canonicalPath)[.modificationDate] as? Date
            let compositeDir = ArchiveCompositeDirectory(name: name, path: canonicalPath, modificationDate: modDate)
            
            let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
            if let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) {
                for itemURL in contents {
                    let childComponent = buildTreeInternal(fromDiskPath: itemURL.path, visited: &visited)
                    compositeDir.add(component: childComponent)
                }
            }
            return compositeDir
        }
    }
}

