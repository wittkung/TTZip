import SwiftUI

public enum DiskSortOption: String, CaseIterable, Identifiable, Codable {
    case nameAsc = "名称 (A-Z)"
    case nameDesc = "名称 (Z-A)"
    case sizeDesc = "体积 (从大到小)"
    case sizeAsc = "体积 (从小到大)"
    case dateDesc = "修改时间 (最新)"
    case dateAsc = "修改时间 (最早)"
    case kind = "文件类型"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .nameAsc: return "textformat.abc"
        case .nameDesc: return "textformat.abc"
        case .sizeDesc: return "arrow.down.circle"
        case .sizeAsc: return "arrow.up.circle"
        case .dateDesc: return "calendar.badge.clock"
        case .dateAsc: return "calendar"
        case .kind: return "square.grid.3x3.fill"
        }
    }
}

public struct FinderFavoriteItem: Identifiable, Hashable, Equatable, Sendable, Codable {
    public var id: String { path }
    public let name: String
    public let path: String
    public let systemImage: String
    
    public init(name: String, path: String, systemImage: String) {
        self.name = name
        self.path = path
        self.systemImage = systemImage
    }
}

public struct FavoriteDropDelegate: DropDelegate {
    let item: FinderFavoriteItem
    @Binding var favorites: [FinderFavoriteItem]
    @Binding var draggingItem: FinderFavoriteItem?
    
    public init(item: FinderFavoriteItem, favorites: Binding<[FinderFavoriteItem]>, draggingItem: Binding<FinderFavoriteItem?>) {
        self.item = item
        self._favorites = favorites
        self._draggingItem = draggingItem
    }
    
    public func performDrop(info: DropInfo) -> Bool {
        draggingItem = nil
        let paths = favorites.map { $0.path }
        UserDefaults.standard.set(paths, forKey: "TTZipUserFavoritesOrder")
        return true
    }
    
    public func dropEntered(info: DropInfo) {
        guard let draggingItem = draggingItem,
              draggingItem.id != item.id,
              let fromIndex = favorites.firstIndex(where: { $0.id == draggingItem.id }),
              let toIndex = favorites.firstIndex(where: { $0.id == item.id }) else { return }
        
        if favorites[toIndex].id != draggingItem.id {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                favorites.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
            }
        }
    }
    
    public func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}
