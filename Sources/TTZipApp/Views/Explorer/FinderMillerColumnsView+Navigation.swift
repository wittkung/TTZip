// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import Foundation
import TTZipCore

extension FinderMillerColumnsView {
    
    var activeColumnIndex: Int {
        if let idx = hoveredColumnIndex, idx >= 0 && idx < columnPaths.count {
            return idx
        }
        return max(0, columnPaths.count - 1)
    }
    
    func prependParentColumn(for dirURL: URL) {
        let parentURL = dirURL.deletingLastPathComponent()
        guard parentURL.path != dirURL.path && parentURL.pathComponents.count >= 1 else { return }
        
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            columnPaths.insert(parentURL, at: 0)
            
            var updatedSelected: [Int: String] = [:]
            for (k, v) in selectedPaths {
                updatedSelected[k + 1] = v
            }
            updatedSelected[0] = dirURL.path
            selectedPaths = updatedSelected
            
            var updatedSort: [Int: DiskSortOption] = [:]
            for (k, v) in perColumnSortOption {
                updatedSort[k + 1] = v
            }
            perColumnSortOption = updatedSort
            
            var updatedWidths: [Int: CGFloat] = [:]
            for (k, v) in columnWidths {
                updatedWidths[k + 1] = v
            }
            columnWidths = updatedWidths
        }
    }
    
    func navigateSelectionUp() {
        let targetIndex = activeColumnIndex
        guard targetIndex >= 0, targetIndex < columnPaths.count else { return }
        let targetURL = columnPaths[targetIndex]
        let currentSort = perColumnSortOption[targetIndex] ?? sortOption
        let cacheKey = "\(targetURL.absoluteString)_\(currentSort.rawValue)"
        guard let items = cachedColumnItems[cacheKey], !items.isEmpty else { return }
        
        let currentPath = selectedPaths[targetIndex]
        let currentIndex = currentPath.flatMap { path in items.firstIndex(where: { $0.path == path }) } ?? -1
        let nextIndex: Int
        if currentIndex <= 0 {
            nextIndex = items.count - 1
        } else {
            nextIndex = currentIndex - 1
        }
        let targetItem = items[nextIndex]
        selectItem(item: targetItem, columnIndex: targetIndex, dirURL: targetURL)
    }
    
    func navigateSelectionDown() {
        let targetIndex = activeColumnIndex
        guard targetIndex >= 0, targetIndex < columnPaths.count else { return }
        let targetURL = columnPaths[targetIndex]
        let currentSort = perColumnSortOption[targetIndex] ?? sortOption
        let cacheKey = "\(targetURL.absoluteString)_\(currentSort.rawValue)"
        guard let items = cachedColumnItems[cacheKey], !items.isEmpty else { return }
        
        let currentPath = selectedPaths[targetIndex]
        let currentIndex = currentPath.flatMap { path in items.firstIndex(where: { $0.path == path }) } ?? -1
        let nextIndex: Int
        if currentIndex < 0 || currentIndex >= items.count - 1 {
            nextIndex = 0
        } else {
            nextIndex = currentIndex + 1
        }
        let targetItem = items[nextIndex]
        selectItem(item: targetItem, columnIndex: targetIndex, dirURL: targetURL)
    }
    
    func navigateSelectionLeft() {
        let activeIndex = activeColumnIndex
        if activeIndex > 0 {
            let nextActive = activeIndex - 1
            hoveredColumnIndex = nextActive
            if columnPaths.count > nextActive + 1 {
                columnPaths = Array(columnPaths.prefix(nextActive + 1))
            }
            for key in selectedPaths.keys where key > nextActive {
                selectedPaths.removeValue(forKey: key)
            }
            if let path = selectedPaths[nextActive] {
                let itemInfo = DiskItemInfo(url: URL(fileURLWithPath: path))
                selectedItem = itemInfo
                onSelectItem(itemInfo)
            } else {
                selectedItem = nil
            }
        } else {
            onNavigateUp?()
        }
    }
    
    func navigateSelectionRight() {
        let activeIndex = activeColumnIndex
        if activeIndex < columnPaths.count - 1 {
            let nextActive = activeIndex + 1
            hoveredColumnIndex = nextActive
            let targetURL = columnPaths[nextActive]
            let currentSort = perColumnSortOption[nextActive] ?? sortOption
            let cacheKey = "\(targetURL.absoluteString)_\(currentSort.rawValue)"
            if let items = cachedColumnItems[cacheKey], !items.isEmpty {
                if let selectedPath = selectedPaths[nextActive],
                   let item = items.first(where: { $0.path == selectedPath }) {
                    selectedItem = item
                    onSelectItem(item)
                } else if let firstItem = items.first {
                    selectItem(item: firstItem, columnIndex: nextActive, dirURL: targetURL)
                }
            }
        } else if activeIndex == columnPaths.count - 1 {
            let targetURL = columnPaths[activeIndex]
            let currentSort = perColumnSortOption[activeIndex] ?? sortOption
            let cacheKey = "\(targetURL.absoluteString)_\(currentSort.rawValue)"
            if let selectedPath = selectedPaths[activeIndex],
               let items = cachedColumnItems[cacheKey],
               let selected = items.first(where: { $0.path == selectedPath }),
               (selected.isDirectory || selected.isArchive) {
                selectItem(item: selected, columnIndex: activeIndex, dirURL: targetURL)
                hoveredColumnIndex = activeIndex + 1
            }
        }
    }
}
