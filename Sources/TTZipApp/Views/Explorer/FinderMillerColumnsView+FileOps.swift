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
    
    func createNewFolder(in dir: URL, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = trimmed.isEmpty ? "Untitled Folder" : trimmed
        var targetURL = dir.appendingPathComponent(baseName)
        
        var counter = 2
        while FileManager.default.fileExists(atPath: targetURL.path) {
            targetURL = dir.appendingPathComponent("\(baseName) \(counter)")
            counter += 1
        }
        
        do {
            try FileManager.default.createDirectory(at: targetURL, withIntermediateDirectories: true, attributes: nil)
            cachedColumnItems.removeAll()
            refreshKey = UUID()
            let createdItem = DiskItemInfo(url: targetURL)
            selectedItem = createdItem
            onSelectItem(createdItem)
            NotificationCenter.default.post(name: NSNotification.Name("TTZipArchiveUnlockedRefresh"), object: nil)
        } catch {
            TTLogger.error("Failed to create directory: \(error)")
        }
    }
    
    func createNewFile(in dir: URL, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = trimmed.isEmpty ? "Untitled.txt" : trimmed
        
        let pathExtension = (baseName as NSString).pathExtension
        let nameWithoutExt = (baseName as NSString).deletingPathExtension
        
        var targetURL = dir.appendingPathComponent(baseName)
        var counter = 2
        while FileManager.default.fileExists(atPath: targetURL.path) {
            let nextName = pathExtension.isEmpty ? "\(baseName) \(counter)" : "\(nameWithoutExt) \(counter).\(pathExtension)"
            targetURL = dir.appendingPathComponent(nextName)
            counter += 1
        }
        
        FileManager.default.createFile(atPath: targetURL.path, contents: Data(), attributes: nil)
        cachedColumnItems.removeAll()
        refreshKey = UUID()
        let createdItem = DiskItemInfo(url: targetURL)
        selectedItem = createdItem
        onSelectItem(createdItem)
        NotificationCenter.default.post(name: NSNotification.Name("TTZipArchiveUnlockedRefresh"), object: nil)
    }
}
