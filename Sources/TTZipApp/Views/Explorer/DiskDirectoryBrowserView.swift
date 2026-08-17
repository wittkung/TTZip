import SwiftUI
import TTZipCore
import AppKit

/// 原生级 macOS 磁盘文件浏览与 Miller Columns 分栏器
public struct DiskDirectoryBrowserView: View {
    let rootDirectory: URL
    let onSelectArchive: (String) -> Void
    let onCompressPath: (String) -> Void
    let onPreviewFile: (String) -> Void
    let onSelectItem: (DiskItemInfo) -> Void
    
    @State private var currentDirectory: URL
    @State private var searchQuery: String = ""
    @StateObject private var searchService = SpotlightSearchService()
    @State private var sortOption: DiskSortOption = .nameAsc
    @State private var items: [DiskItemInfo] = []
    @State private var targetSelectedPath: String? = nil
    @State private var dynamicFinderFavorites: [FinderFavoriteItem] = []
    @State private var draggingFavorite: FinderFavoriteItem? = nil
    
    public init(
        rootDirectory: URL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory()),
        onSelectArchive: @escaping (String) -> Void,
        onCompressPath: @escaping (String) -> Void,
        onPreviewFile: @escaping (String) -> Void,
        onSelectItem: @escaping (DiskItemInfo) -> Void = { _ in }
    ) {
        self.rootDirectory = rootDirectory
        self._currentDirectory = State(initialValue: rootDirectory)
        self.onSelectArchive = onSelectArchive
        self.onCompressPath = onCompressPath
        self.onPreviewFile = onPreviewFile
        self.onSelectItem = onSelectItem
    }
    
    nonisolated public static func sortItems(_ items: [DiskItemInfo], option: DiskSortOption) -> [DiskItemInfo] {
        return DiskItemSorter.sort(items, by: option)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(dynamicFinderFavorites) { fav in
                            shortcutTag(
                                label: fav.name,
                                systemImage: fav.systemImage,
                                targetURL: URL(fileURLWithPath: fav.path)
                            )
                            .onDrag {
                                self.draggingFavorite = fav
                                return NSItemProvider(object: fav.path as NSString)
                            }
                            .onDrop(of: [.text], delegate: FavoriteDropDelegate(item: fav, favorites: $dynamicFinderFavorites, draggingItem: $draggingFavorite))
                        }
                        
                        ForEach(customPinnedPaths, id: \.self) { path in
                            let url = URL(fileURLWithPath: path)
                            if !dynamicFinderFavorites.contains(where: { $0.path == path }) {
                                shortcutTag(
                                    label: url.lastPathComponent,
                                    systemImage: "folder.fill",
                                    targetURL: url,
                                    isCustom: true
                                )
                            }
                        }
                        
                        Button(action: addCustomPinnedFolder) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 9.5, weight: .bold))
                                Text("添加快捷")
                                    .font(.system(size: 10.5, weight: .bold))
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4.5)
                            .background(TTZipTheme.bambooGreen.opacity(0.12))
                            .foregroundStyle(TTZipTheme.bambooGreen)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().strokeBorder(TTZipTheme.bambooGreen.opacity(0.3), lineWidth: 0.8)
                            )
                        }
                        .buttonStyle(.plain)
                        .help("添加 Mac 上的任意自定义文件夹钉住至快捷栏")
                    }
                    .padding(.vertical, 2)
                }
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black, location: 0.92),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                
                Button(action: { reloadCurrentDirectory() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .bold))
                        Text("刷新")
                            .font(.system(size: 10.5, weight: .medium))
                    }
                    .foregroundStyle(TTZipTheme.bambooGreen)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(TTZipTheme.bambooGreen.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().strokeBorder(TTZipTheme.bambooGreen.opacity(0.3), lineWidth: 0.8)
                    )
                }
                .buttonStyle(.plain)
                .help("刷新整个文件浏览器内容")
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            
            FinderMillerColumnsView(
                rootDirectory: currentDirectory,
                initialSelectedPath: targetSelectedPath,
                sortOption: sortOption,
                onNavigateUp: canNavigateUp ? { navigateUp() } : nil,
                onSelectArchive: onSelectArchive,
                onCompressPath: onCompressPath,
                onPreviewFile: onPreviewFile,
                onSelectItem: onSelectItem
            )
            .frame(maxHeight: .infinity)
        }
        .task {
            let favs = await Task.detached(priority: .userInitiated) {
                FinderFavoritesReader.fetchFavorites()
            }.value
            await MainActor.run {
                self.dynamicFinderFavorites = favs
            }
            reloadCurrentDirectory()
        }
    }
    
    private func shortcutTag(label: String, systemImage: String, targetURL: URL, isCustom: Bool = false) -> some View {
        Button(action: {
            currentDirectory = targetURL
            reloadCurrentDirectory()
        }) {
            let isSelected = currentDirectory.path == targetURL.path
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 9.5, weight: .semibold))
                Text(label)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4.5)
            .background(isSelected ? TTZipTheme.bambooGreen.opacity(0.16) : Color.primary.opacity(0.035))
            .foregroundStyle(isSelected ? TTZipTheme.bambooGreen : Color.primary.opacity(0.85))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? TTZipTheme.bambooGreen.opacity(0.35) : Color.primary.opacity(0.06), lineWidth: isSelected ? 1 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            if isCustom {
                Button("取消钉住此快捷路径") {
                    removeCustomPinnedFolder(path: targetURL.path)
                }
            }
            Button("在 Finder 中显示") {
                NSWorkspace.shared.selectFile(targetURL.path, inFileViewerRootedAtPath: "")
            }
        }
    }
    
    @AppStorage("TTZipCustomShortcutFolderPaths") private var customPinnedPathsJSON: String = "[]"
    
    private var customPinnedPaths: [String] {
        guard let data = customPinnedPathsJSON.data(using: .utf8),
              let list = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return list
    }
    
    private func saveCustomPinnedPaths(_ paths: [String]) {
        if let data = try? JSONEncoder().encode(paths),
           let jsonStr = String(data: data, encoding: .utf8) {
            customPinnedPathsJSON = jsonStr
        }
    }
    
    private func addCustomPinnedFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "钉住快捷文件夹"
        panel.message = "选择要钉住在顶部快捷栏的文件夹："
        
        if panel.runModal() == .OK {
            var current = customPinnedPaths
            for url in panel.urls {
                if !current.contains(url.path) {
                    current.append(url.path)
                }
            }
            saveCustomPinnedPaths(current)
        }
    }
    
    private func removeCustomPinnedFolder(path: String) {
        var current = customPinnedPaths
        current.removeAll { $0 == path }
        saveCustomPinnedPaths(current)
    }
    
    private var canNavigateUp: Bool { currentDirectory.path != "/" && currentDirectory.pathComponents.count > 1 }
    
    private func navigateUp() {
        guard canNavigateUp else { return }
        let prevPath = currentDirectory.path
        targetSelectedPath = prevPath
        currentDirectory = currentDirectory.deletingLastPathComponent()
        reloadCurrentDirectory()
    }
    
    private func reloadCurrentDirectory() {
        let dir = currentDirectory
        Task.detached(priority: .userInitiated) {
            let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .isPackageKey, .isHiddenKey]
            guard let contents = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
                await MainActor.run {
                    if self.currentDirectory == dir {
                        self.items = []
                    }
                }
                return
            }
            let list = contents.map { DiskItemInfo(url: $0) }
            let sorted = list.sorted { a, b in
                if a.isDirectory != b.isDirectory {
                    return a.isDirectory
                }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
            await MainActor.run {
                if self.currentDirectory == dir {
                    self.items = sorted
                }
            }
        }
    }
}
