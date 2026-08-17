import Foundation
import TTZipCore

/// 负责磁盘与归档包内条目多维排序的纯函数中枢 (Strategy Pattern / Comparator Engine)
public enum DiskItemSorter {
    
    /// 对 DiskItemInfo 数组进行确定性多级排序
    /// - Parameters:
    ///   - items: 待排序集合
    ///   - option: 排序维度 (DiskSortOption)
    /// - Returns: 严格排序后的数组
    public static func sort(_ items: [DiskItemInfo], by option: DiskSortOption) -> [DiskItemInfo] {
        return items.sorted { isOrderedBefore($0, $1, option: option) }
    }
    
    /// 比较两个 DiskItemInfo 元素是否满足严格偏序 ($a < $b)
    public static func isOrderedBefore(_ a: DiskItemInfo, _ b: DiskItemInfo, option: DiskSortOption) -> Bool {
        // 第一优先级：文件夹置顶分区 (Folder Partitioning)
        if a.isDirectory != b.isDirectory {
            return a.isDirectory
        }
        
        // 第二优先级：主排序键 (Primary Sort Key)
        switch option {
        case .nameAsc:
            let cmp = a.name.localizedStandardCompare(b.name)
            if cmp != .orderedSame {
                return cmp == .orderedAscending
            }
            
        case .nameDesc:
            let cmp = a.name.localizedStandardCompare(b.name)
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
        
        // 第三优先级：次级文件名自然排序决胜键 (Secondary Tie-Breaker)
        let nameCmp = a.name.localizedStandardCompare(b.name)
        if nameCmp != .orderedSame {
            return nameCmp == .orderedAscending
        }
        
        // 第四优先级：路径绝对唯一键兜底 (Tertiary Tie-Breaker for Absolute Stability)
        return a.path.compare(b.path) == .orderedAscending
    }
}
