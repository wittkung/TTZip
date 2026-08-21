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
    
    func selectItem(item: DiskItemInfo, columnIndex: Int, isCommand: Bool = false, isShift: Bool = false, dirURL: URL? = nil) {
        hoveredColumnIndex = columnIndex
        let currentSort = perColumnSortOption[columnIndex] ?? sortOption
        let cacheKey = dirURL.map { "\($0.absoluteString)_\(currentSort.rawValue)" } ?? ""
        let items = cachedColumnItems[cacheKey] ?? []
        
        if isCommand {
            if multiSelectedPaths.contains(item.path) {
                multiSelectedPaths.remove(item.path)
            } else {
                multiSelectedPaths.insert(item.path)
            }
        } else if isShift, !items.isEmpty,
                  let lastPath = selectedPaths[columnIndex],
                  let lastIndex = items.firstIndex(where: { $0.path == lastPath }),
                  let currentIndex = items.firstIndex(where: { $0.path == item.path }) {
            let start = min(lastIndex, currentIndex)
            let end = max(lastIndex, currentIndex)
            for i in start...end {
                multiSelectedPaths.insert(items[i].path)
            }
        } else {
            multiSelectedPaths = [item.path]
        }
        
        selectedPaths[columnIndex] = item.path
        for key in selectedPaths.keys where key > columnIndex {
            selectedPaths.removeValue(forKey: key)
        }
        selectedItem = item
        onSelectItem(item)
        
        let isEncrypted = item.kindText == "受密码保护的归档包" || item.name.contains("压缩包已被加密")
        if isEncrypted {
            let (archivePath, _) = parseVirtualURL(item.path)
            NotificationCenter.default.post(name: NSNotification.Name("TTZipEncryptedArchivePromptRequired"), object: archivePath)
            return
        }
        
        if columnPaths.count > columnIndex + 1 {
            columnPaths = Array(columnPaths.prefix(columnIndex + 1))
        }
        
        if item.isDirectory || item.isArchive {
            let targetURL: URL
            if let u = URL(string: item.path), u.scheme != nil {
                targetURL = u
            } else {
                targetURL = URL(fileURLWithPath: item.path)
            }
            columnPaths.append(targetURL)
        }
    }
    
    func selectAllInActiveColumn() {
        let targetIndex = hoveredColumnIndex ?? (columnPaths.count - 1)
        guard targetIndex < columnPaths.count else { return }
        let targetURL = columnPaths[targetIndex]
        let currentSort = perColumnSortOption[targetIndex] ?? sortOption
        let cacheKey = "\(targetURL.absoluteString)_\(currentSort.rawValue)"
        guard let items = cachedColumnItems[cacheKey], !items.isEmpty else { return }
        
        multiSelectedPaths = Set(items.map { $0.path })
        if let first = items.first {
            selectedPaths[targetIndex] = first.path
            selectedItem = first
            onSelectItem(first)
        }
    }
    
    func parseVirtualURL(_ path: String) -> (archivePath: String, subpath: String) {
        if let u = URL(string: path),
           let comp = URLComponents(url: u, resolvingAgainstBaseURL: false),
           let sub = comp.queryItems?.first(where: { $0.name == "subpath" })?.value {
            var arch = u.path
            if arch.isEmpty { arch = path }
            return (arch, sub)
        }
        return (path, "")
    }
}
