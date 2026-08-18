// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import AppKit

/// Security-scoped bookmark and root directory access manager.
@MainActor
public final class RootFolderAccessManager {
    public static let shared = RootFolderAccessManager()
    
    private let bookmarksKey = "TTZipSecurityScopedBookmarksKey"
    private var activeBookmarks: [URL: Data] = [:]
    private var accessingURLs: Set<URL> = []
    
    private init() {
        restoreBookmarks()
    }
    
    /// Computes highest logical root URL for target path.
    public func highestRootURL(for url: URL) -> URL {
        let homePath = NSHomeDirectory()
        let path = url.path
        
        if path.hasPrefix(homePath) {
            return URL(fileURLWithPath: homePath)
        }
        
        if path.hasPrefix("/Volumes/") {
            let components = url.pathComponents
            if components.count >= 3 {
                let volumePath = "/" + components[1] + "/" + components[2]
                return URL(fileURLWithPath: volumePath)
            }
        }
        
        return URL(fileURLWithPath: "/")
    }
    
    /// Restores and activates saved security-scoped bookmarks.
    public func restoreBookmarks() {
        guard let data = UserDefaults.standard.data(forKey: bookmarksKey),
              let dict = try? PropertyListDecoder().decode([String: Data].self, from: data) else {
            return
        }
        
        for (_, bookmarkData) in dict {
            var isStale = false
            if let resolvedURL = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) {
                if isStale {
                    if let freshData = try? resolvedURL.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                        activeBookmarks[resolvedURL] = freshData
                    }
                } else {
                    activeBookmarks[resolvedURL] = bookmarkData
                }
                if resolvedURL.startAccessingSecurityScopedResource() {
                    accessingURLs.insert(resolvedURL)
                }
            }
        }
        saveBookmarks()
    }
    
    private func saveBookmarks() {
        var saveDict: [String: Data] = [:]
        for (url, data) in activeBookmarks {
            saveDict[url.path] = data
        }
        if let encoded = try? PropertyListEncoder().encode(saveDict) {
            UserDefaults.standard.set(encoded, forKey: bookmarksKey)
        }
    }
    
    /// Verifies and ensures read/write access to target URL and its root.
    @discardableResult
    public func ensureAccess(for url: URL, promptIfMissing: Bool = false) -> Bool {
        let rootURL = highestRootURL(for: url)
        
        if FileManager.default.isReadableFile(atPath: url.path) || FileManager.default.isReadableFile(atPath: rootURL.path) {
            return true
        }
        
        for activeURL in accessingURLs {
            if url.path.hasPrefix(activeURL.path) || rootURL.path == activeURL.path {
                return true
            }
        }
        
        if promptIfMissing {
            return requestRootAccess(for: rootURL)
        }
        
        return false
    }
    
    /// Prompts user for root directory access permission.
    @discardableResult
    public func requestRootAccess(for rootURL: URL) -> Bool {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = rootURL
        panel.title = "TTZip Root Directory Authorization"
        panel.prompt = "Authorize Root Access"
        panel.message = "Authorize TTZip to access root directory (\(rootURL.path)) for seamless navigation."
        
        if panel.runModal() == .OK, let selectedURL = panel.url {
            let targetRoot = highestRootURL(for: selectedURL)
            if let bookmarkData = try? targetRoot.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                activeBookmarks[targetRoot] = bookmarkData
                saveBookmarks()
                if targetRoot.startAccessingSecurityScopedResource() {
                    accessingURLs.insert(targetRoot)
                }
                return true
            }
        }
        return false
    }
}
