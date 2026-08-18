// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import TTZipCore
import AppKit

/// Observable service providing asynchronous directory item autocompletion with LRU micro-caching.
@MainActor
public final class AsyncPathAutocompletionEngine: ObservableObject {
    
    /// Published list of autocompleted path suggestions.
    @Published public var suggestions: [PathSuggestionItem] = []
    
    /// Indicates whether a directory scan or autocompletion query is actively in progress.
    @Published public var isLoading: Bool = false
    
    /// In-memory LRU cache storing directory contents keyed by parent POSIX directory path.
    public let cache: ExplorerLRUCache<String, [DiskItemInfo]>
    
    /// Currently running background query task.
    private var activeTask: Task<Void, Never>?
    
    /// Maximum number of autocompletion suggestions returned to the UI.
    public static let maxSuggestionsCount: Int = 15
    
    /// Initializes the autocompletion engine with an optional LRU cache capacity (default 128).
    public init(cacheCapacity: Int = 128) {
        self.cache = ExplorerLRUCache<String, [DiskItemInfo]>(capacity: cacheCapacity)
    }
    
    /// Initiates an asynchronous query for matching directory and file items.
    ///
    /// - Parameters:
    ///   - rawInput: The user's typed path input.
    ///   - baseDirectory: Base directory URL used to resolve relative paths.
    public func query(rawInput: String, baseDirectory: URL) {
        activeTask?.cancel()
        activeTask = nil
        
        let trimmed = rawInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            self.suggestions = []
            self.isLoading = false
            return
        }
        
        let (parentDir, prefix) = POSIXPathSanitizer.extractParentAndPrefix(rawInput: trimmed, baseDirectory: baseDirectory)
        self.isLoading = true
        
        let localCache = self.cache
        let maxCount = Self.maxSuggestionsCount
        
        activeTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard !Task.isCancelled else { return }
            
            let items: [DiskItemInfo]
            if let cached = localCache.get(parentDir) {
                items = cached
            } else {
                let parentURL = URL(fileURLWithPath: parentDir)
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: parentDir, isDirectory: &isDir), isDir.boolValue else {
                    await self?.finishQuery(suggestions: [], isLoading: false)
                    return
                }
                
                guard let contents = try? FileManager.default.contentsOfDirectory(
                    at: parentURL,
                    includingPropertiesForKeys: [.isDirectoryKey, .nameKey, .fileSizeKey, .contentModificationDateKey],
                    options: [.skipsPackageDescendants]
                ) else {
                    await self?.finishQuery(suggestions: [], isLoading: false)
                    return
                }
                
                guard !Task.isCancelled else { return }
                
                let scanned = contents.map { DiskItemInfo(url: $0) }
                localCache.set(parentDir, value: scanned)
                items = scanned
            }
            
            guard !Task.isCancelled else { return }
            
            let isDotQuery = prefix.hasPrefix(".")
            let lowerPrefix = prefix.lowercased()
            
            let filtered = items.filter { item in
                if !isDotQuery && item.name.hasPrefix(".") {
                    return false
                }
                if prefix.isEmpty {
                    return true
                }
                return item.name.lowercased().hasPrefix(lowerPrefix)
            }
            
            guard !Task.isCancelled else { return }
            
            // Directories first (rank 0), archives second (rank 1), files third (rank 2)
            let sorted = filtered.sorted { a, b in
                let rankA = a.isDirectory ? 0 : (a.isArchive ? 1 : 2)
                let rankB = b.isDirectory ? 0 : (b.isArchive ? 1 : 2)
                if rankA != rankB {
                    return rankA < rankB
                }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
            
            let limited = Array(sorted.prefix(maxCount))
            
            let mapped = limited.map { item -> PathSuggestionItem in
                let iconName: String
                if item.isDirectory {
                    iconName = "folder.fill"
                } else if item.isArchive {
                    iconName = "archivebox.fill"
                } else {
                    iconName = "doc.fill"
                }
                
                let highlightRange: [Int]
                if !prefix.isEmpty && item.name.lowercased().hasPrefix(lowerPrefix) {
                    highlightRange = [0, prefix.count]
                } else {
                    highlightRange = [0, 0]
                }
                
                return PathSuggestionItem(
                    id: item.path,
                    path: item.path,
                    displayName: item.name,
                    parentPath: parentDir,
                    isDirectory: item.isDirectory,
                    isArchive: item.isArchive,
                    systemIconName: iconName,
                    matchHighlightRange: highlightRange
                )
            }
            
            guard !Task.isCancelled else { return }
            
            await self?.finishQuery(suggestions: mapped, isLoading: false)
        }
    }
    
    /// Asynchronously awaits completion of an autocompletion query and returns the resulting suggestions.
    @discardableResult
    public func queryAsync(rawInput: String, baseDirectory: URL) async -> [PathSuggestionItem] {
        query(rawInput: rawInput, baseDirectory: baseDirectory)
        if let task = activeTask {
            _ = await task.value
        }
        return self.suggestions
    }
    
    /// Clears any active query task and resets suggestion state.
    public func clear() {
        activeTask?.cancel()
        activeTask = nil
        self.suggestions = []
        self.isLoading = false
    }
    
    // MARK: - Private Helpers
    
    private func finishQuery(suggestions: [PathSuggestionItem], isLoading: Bool) {
        self.suggestions = suggestions
        self.isLoading = isLoading
    }
}
