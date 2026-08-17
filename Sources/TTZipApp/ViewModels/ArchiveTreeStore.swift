import Foundation
import SwiftUI
import TTZipCore

/// 归档目录树与搜索过滤状态容器
/// 负责后台异步构建层级树、树节点 Memoization 与防抖异步搜索匹配，确保主线程 UI 零卡顿
@MainActor
public final class ArchiveTreeStore: ObservableObject {
    @Published public private(set) var rootNodes: [ArchiveTreeNode] = []
    @Published public private(set) var isBuildingTree: Bool = false
    @Published public private(set) var filteredEntries: [ArchiveEntry] = []
    @Published public private(set) var isFiltering: Bool = false
    @Published public private(set) var currentSearchQuery: String = ""
    
    private var cachedSourceEntries: [ArchiveEntry] = []
    private var activeBuildTask: Task<[ArchiveTreeNode], Never>?
    private var activeFilterTask: Task<[ArchiveEntry], Never>?
    
    public init() {}
    
    /// 更新归档条目数据源并触发后台异步树构建
    /// - Parameters:
    ///   - entries: 扁平归档条目列表
    ///   - force: 是否强制重新构建
    public func updateEntries(_ entries: [ArchiveEntry]) {
        updateEntries(entries, force: false)
    }
    
    public func updateEntries(_ entries: [ArchiveEntry], force: Bool = false) {
        if !force && cachedSourceEntries.count == entries.count && cachedSourceEntries.first?.path == entries.first?.path && cachedSourceEntries.last?.path == entries.last?.path {
            return
        }
        
        cachedSourceEntries = entries
        filteredEntries = entries
        
        activeBuildTask?.cancel()
        activeBuildTask = nil
        
        if entries.isEmpty {
            rootNodes = []
            isBuildingTree = false
            return
        }
        
        isBuildingTree = true
        let source = entries
        
        activeBuildTask = Task.detached(priority: .userInitiated) {
            let tree = ArchiveTreeBuilder.buildTree(from: source)
            return tree
        }
        
        Task { [weak self] in
            guard let self = self, let task = self.activeBuildTask else { return }
            let nodes = await task.value
            guard !Task.isCancelled else { return }
            self.rootNodes = nodes
            self.isBuildingTree = false
        }
    }
    
    /// 执行带防抖 (Debounce) 的异步搜索过滤
    /// - Parameters:
    ///   - query: 搜索关键词
    ///   - debounceMs: 防抖延迟毫秒数 (默认 100ms)
    public func filter(query: String) {
        filter(query: query, debounceMs: 100)
    }
    
    public func filter(query: String, debounceMs: UInt64 = 100) {
        currentSearchQuery = query
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        activeFilterTask?.cancel()
        activeFilterTask = nil
        
        if trimmed.isEmpty {
            filteredEntries = cachedSourceEntries
            isFiltering = false
            return
        }
        
        isFiltering = true
        let source = cachedSourceEntries
        
        activeFilterTask = Task.detached(priority: .userInitiated) {
            if debounceMs > 0 {
                try? await Task.sleep(nanoseconds: debounceMs * 1_000_000)
            }
            guard !Task.isCancelled else { return [] }
            
            let lowerQuery = trimmed.lowercased()
            let matched = source.filter { entry in
                entry.name.lowercased().contains(lowerQuery) || entry.path.lowercased().contains(lowerQuery)
            }
            return matched
        }
        
        Task { [weak self] in
            guard let self = self, let task = self.activeFilterTask else { return }
            let results = await task.value
            guard !Task.isCancelled else { return }
            self.filteredEntries = results
            self.isFiltering = false
        }
    }
    
    /// 清空目录树与缓存
    public func clear() {
        activeBuildTask?.cancel()
        activeBuildTask = nil
        activeFilterTask?.cancel()
        activeFilterTask = nil
        
        cachedSourceEntries = []
        rootNodes = []
        filteredEntries = []
        isBuildingTree = false
        isFiltering = false
        currentSearchQuery = ""
    }
}
