// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import AppKit

public final class FinderFavoritesReader {
    public static func fetchFavorites() -> [FinderFavoriteItem] {
        var results: [FinderFavoriteItem] = []
        let home = NSHomeDirectory()
        let fm = FileManager.default
        
        let standardPaths: [(String, String)] = [
            ((home as NSString).appendingPathComponent("Downloads"), "arrow.down.circle.fill"),
            ((home as NSString).appendingPathComponent("Documents"), "doc.text.fill"),
            ((home as NSString).appendingPathComponent("Desktop"), "desktopcomputer"),
            (home, "house.fill"),
            ((home as NSString).appendingPathComponent("Pictures"), "photo.fill"),
            ((home as NSString).appendingPathComponent("Movies"), "film.fill"),
            ((home as NSString).appendingPathComponent("Music"), "music.note")
        ]
        
        for (path, icon) in standardPaths {
            if fm.fileExists(atPath: path) {
                let displayName = fm.displayName(atPath: path)
                results.append(FinderFavoriteItem(name: displayName, path: path, systemImage: icon))
            }
        }
        
        if let mountedVolumes = fm.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeIsInternalKey, .volumeLocalizedNameKey], options: .skipHiddenVolumes) {
            for volumeURL in mountedVolumes {
                if volumeURL.path == "/" || volumeURL.path == "/System/Volumes/Data" {
                    continue
                }
                
                let isInternal = (try? volumeURL.resourceValues(forKeys: [.volumeIsInternalKey]).volumeIsInternal) ?? true
                let name = (try? volumeURL.resourceValues(forKeys: [.volumeLocalizedNameKey]).volumeLocalizedName) ?? volumeURL.lastPathComponent
                
                let icon = isInternal ? "internaldrive.fill" : "externaldrive.fill"
                results.append(FinderFavoriteItem(name: name, path: volumeURL.path, systemImage: icon))
            }
        }
        
        return results
    }
}
