// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import SwiftUI
import TTZipCore

/// Archive tree store and search filtering state container.
///
/// Handles asynchronous hierarchical tree building, tree node memoization, and debounced search matching.
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
    
    /// Updates source entries and triggers asynchronous background tree construction.
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
    
    /// Executes debounced asynchronous search filtering.
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
    
    /// Clears directory tree and active caches.
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
