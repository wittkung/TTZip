// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import TTZipCore

/// Multi-dimensional sorting strategy engine for disk and archive entries.
public enum DiskItemSorter {
    
    /// Sorts DiskItemInfo array deterministically according to chosen sort option.
    public static func sort(_ items: [DiskItemInfo], by option: DiskSortOption) -> [DiskItemInfo] {
        return items.sorted { isOrderedBefore($0, $1, option: option) }
    }
    
    /// Evaluates strict partial ordering ($a < $b) between two DiskItemInfo entries.
    public static func isOrderedBefore(_ a: DiskItemInfo, _ b: DiskItemInfo, option: DiskSortOption) -> Bool {
        // Priority 1: Folder partitioning
        if a.isDirectory != b.isDirectory {
            return a.isDirectory
        }
        
        // Priority 2: Primary sort key
        switch option {
        case .nameAsc:
            let cmp = NativeMicrokernelBridge.naturalCompare(a.name, b.name)
            if cmp != .orderedSame {
                return cmp == .orderedAscending
            }
            
        case .nameDesc:
            let cmp = NativeMicrokernelBridge.naturalCompare(a.name, b.name)
            if cmp != .orderedSame {
                return cmp == .orderedDescending
            }
            
        case .sizeDesc:
            if a.rawSizeBytes != b.rawSizeBytes {
                return a.rawSizeBytes > b.rawSizeBytes
            }
            
        case .sizeAsc:
            if a.rawSizeBytes != b.rawSizeBytes {
                return a.rawSizeBytes < b.rawSizeBytes
            }
            
        case .dateDesc:
            switch (a.modificationDate, b.modificationDate) {
            case let (dateA?, dateB?):
                if dateA != dateB {
                    return dateA > dateB
                }
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                break
            }
            
        case .dateAsc:
            switch (a.modificationDate, b.modificationDate) {
            case let (dateA?, dateB?):
                if dateA != dateB {
                    return dateA < dateB
                }
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                break
            }
            
        case .kind:
            let kindCmp = a.kindText.localizedStandardCompare(b.kindText)
            if kindCmp != .orderedSame {
                return kindCmp == .orderedAscending
            }
        }
        
        // Priority 3: Secondary natural name sort
        let nameCmp = NativeMicrokernelBridge.naturalCompare(a.name, b.name)
        if nameCmp != .orderedSame {
            return nameCmp == .orderedAscending
        }
        
        // Priority 4: Tertiary absolute path stability
        return a.path.compare(b.path) == .orderedAscending
    }
}
