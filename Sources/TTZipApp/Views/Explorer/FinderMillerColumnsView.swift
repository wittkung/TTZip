import SwiftUI
import TTZipCore
import AppKit

public struct FinderMillerColumnsView: View {
    let rootDirectory: URL
    var initialSelectedPath: String? = nil
    var sortOption: DiskSortOption = .nameAsc
    var onNavigateUp: (() -> Void)? = nil
    let onSelectArchive: (String) -> Void
    let onCompressPath: (String) -> Void
    let onPreviewFile: (String) -> Void
    let onSelectItem: (DiskItemInfo) -> Void
    
    @State private var columnPaths: [URL] = []
    @State private var selectedPaths: [Int: String] = [:]
    @State private var multiSelectedPaths: Set<String> = []
    @State private var hoveredColumnIndex: Int? = nil
    @State private var selectedItem: DiskItemInfo? = nil
    @State private var cachedColumnItems: [String: [DiskItemInfo]] = [:]
    @State private var refreshKey: UUID = UUID()
    @State private var columnWidths: [Int: CGFloat] = [:]
    @State private var perColumnSortOption: [Int: DiskSortOption] = [:]
    @State private var eventMonitor: Any? = nil
    
    @State private var showNewFolderAlert: Bool = false
    @State private var newFolderName: String = "未命名文件夹"
    @State private var targetCreateFolderDir: URL? = nil
    
    @State private var showNewFileAlert: Bool = false
    @State private var newFileName: String = "未命名文件.txt"
    @State private var targetCreateFileDir: URL? = nil
    
    private func createNewFolder(in dir: URL, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = trimmed.isEmpty ? "未命名文件夹" : trimmed
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
    
    private func createNewFile(in dir: URL, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = trimmed.isEmpty ? "未命名文件.txt" : trimmed
        
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
    
    public init(
        rootDirectory: URL,
        initialSelectedPath: String? = nil,
        sortOption: DiskSortOption = .nameAsc,
        onNavigateUp: (() -> Void)? = nil,
        onSelectArchive: @escaping (String) -> Void,
        onCompressPath: @escaping (String) -> Void,
        onPreviewFile: @escaping (String) -> Void,
        onSelectItem: @escaping (DiskItemInfo) -> Void
    ) {
        self.rootDirectory = rootDirectory
        self.initialSelectedPath = initialSelectedPath
        self.sortOption = sortOption
        self.onNavigateUp = onNavigateUp
        self.onSelectArchive = onSelectArchive
        self.onCompressPath = onCompressPath
        self.onPreviewFile = onPreviewFile
        self.onSelectItem = onSelectItem
    }
    
    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ScrollViewReader { proxy in
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(columnPaths.enumerated()), id: \.offset) { index, dirURL in
                        millerColumn(index: index, dirURL: dirURL)
                            .id(index)
                    }
                }
                .onChange(of: columnPaths.count) { _, newCount in
                    if newCount > 0 {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                            proxy.scrollTo(newCount - 1, anchor: .trailing)
                        }
                    }
                }
            }
        }
        .clipped()
        .alert("新建文件夹", isPresented: $showNewFolderAlert) {
            TextField("文件夹名称", text: $newFolderName)
            Button("取消", role: .cancel) {
                newFolderName = "未命名文件夹"
            }
            Button("创建") {
                let dir = targetCreateFolderDir ?? rootDirectory
                createNewFolder(in: dir, name: newFolderName)
                newFolderName = "未命名文件夹"
            }
        } message: {
            if let dir = targetCreateFolderDir {
                Text("将在以下路径创建新文件夹：\n\(dir.path)")
            } else {
                Text("创建新的文件夹")
            }
        }
        .alert("新建空白文件", isPresented: $showNewFileAlert) {
            TextField("文件名 (含扩展名, 如 .txt / .md)", text: $newFileName)
            Button("取消", role: .cancel) {
                newFileName = "未命名文件.txt"
            }
            Button("创建") {
                let dir = targetCreateFileDir ?? rootDirectory
                createNewFile(in: dir, name: newFileName)
                newFileName = "未命名文件.txt"
            }
        } message: {
            if let dir = targetCreateFileDir {
                Text("将在以下路径创建空文件：\n\(dir.path)")
            } else {
                Text("创建新的空白文件")
            }
        }
        .onAppear {
            if columnPaths.isEmpty {
                columnPaths = [rootDirectory]
            }
            if let target = initialSelectedPath, !target.isEmpty {
                selectedPaths[0] = target
                let targetURL = URL(fileURLWithPath: target)
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: target, isDirectory: &isDir), isDir.boolValue {
                    columnPaths = [rootDirectory, targetURL]
                }
            }
            
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if let firstResponder = NSApp.keyWindow?.firstResponder {
                    if firstResponder.isKind(of: NSTextView.self) && (firstResponder as? NSTextView)?.isFieldEditor == true {
                        return event
                    }
                }
                if event.keyCode >= 123 && event.keyCode <= 126 {
                    switch event.keyCode {
                    case 123: // Left
                        navigateSelectionLeft()
                    case 124: // Right
                        navigateSelectionRight()
                    case 125: // Down
                        navigateSelectionDown()
                    case 126: // Up
                        navigateSelectionUp()
                    default:
                        break
                    }
                    return nil
                }
                return event
            }
        }
        .onDisappear {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
        }
        .onChange(of: rootDirectory) { _, newRoot in
            selectedPaths = [:]
            hoveredColumnIndex = 0
            if let target = initialSelectedPath, !target.isEmpty {
                selectedPaths[0] = target
                let targetURL = URL(fileURLWithPath: target)
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: target, isDirectory: &isDir), isDir.boolValue {
                    columnPaths = [newRoot, targetURL]
                } else {
                    columnPaths = [newRoot]
                }
                let item = DiskItemInfo(url: targetURL)
                selectedItem = item
                onSelectItem(item)
            } else {
                columnPaths = [newRoot]
                selectedItem = nil
            }
            cachedColumnItems = [:]
            perColumnSortOption = [:]
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TTZipArchiveUnlockedRefresh"))) { _ in
            cachedColumnItems = [:]
            refreshKey = UUID()
        }
        .overlay(
            Group {
                Button("") {
                    let targets: [URL] = {
                        if !multiSelectedPaths.isEmpty {
                            return multiSelectedPaths.map { URL(fileURLWithPath: $0) }
                        } else if let selectedPath = selectedPaths.compactMap({ $0.value }).last {
                            return [URL(fileURLWithPath: selectedPath)]
                        }
                        return []
                    }()
                    if !targets.isEmpty {
                        FileClipboardStore.shared.copy(urls: targets)
                    }
                }
                .keyboardShortcut("c", modifiers: .command)
                
                Button("") {
                    let targets: [URL] = {
                        if !multiSelectedPaths.isEmpty {
                            return multiSelectedPaths.map { URL(fileURLWithPath: $0) }
                        } else if let selectedPath = selectedPaths.compactMap({ $0.value }).last {
                            return [URL(fileURLWithPath: selectedPath)]
                        }
                        return []
                    }()
                    if !targets.isEmpty {
                        FileClipboardStore.shared.cut(urls: targets)
                    }
                }
                .keyboardShortcut("x", modifiers: .command)
                
                Button("") {
                    let targetDir: URL = {
                        if let selectedPath = selectedPaths.compactMap({ $0.value }).last {
                            var isDir: ObjCBool = false
                            if FileManager.default.fileExists(atPath: selectedPath, isDirectory: &isDir), isDir.boolValue {
                                return URL(fileURLWithPath: selectedPath)
                            }
                        }
                        return columnPaths.last ?? rootDirectory
                    }()
                    FileClipboardStore.shared.paste(to: targetDir)
                }
                .keyboardShortcut("v", modifiers: .command)
            }
            .opacity(0)
            .allowsHitTesting(false)
        )
    }
    
    private func prependParentColumn(for dirURL: URL) {
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
    
    private var activeColumnIndex: Int {
        if let idx = hoveredColumnIndex, idx >= 0 && idx < columnPaths.count {
            return idx
        }
        return max(0, columnPaths.count - 1)
    }
    
    private func millerColumn(index: Int, dirURL: URL) -> some View {
        let selectedPath = selectedPaths[index]
        let currentSort = perColumnSortOption[index] ?? sortOption
        let cacheKey = "\(dirURL.absoluteString)_\(currentSort.rawValue)"
        let items = cachedColumnItems[cacheKey]
        let currentWidth = columnWidths[index] ?? 200
        let canGoParent = dirURL.path != "/" && dirURL.pathComponents.count > 1
        let isColumnActive = (index == activeColumnIndex)
        
        return SingleMillerColumnView(
            index: index,
            dirURL: dirURL,
            selectedPath: selectedPath,
            currentSort: currentSort,
            items: items,
            currentWidth: currentWidth,
            canGoParent: canGoParent,
            isColumnActive: isColumnActive,
            multiSelectedPaths: multiSelectedPaths,
            onPrependParent: { prependParentColumn(for: dirURL) },
            onChangeSort: { perColumnSortOption[index] = $0 },
            onSelectArchive: onSelectArchive,
            onCompressPath: onCompressPath,
            onSelectItem: { it, idx, cmd, shift, dir in
                selectItem(item: it, columnIndex: idx, isCommand: cmd, isShift: shift, dirURL: dir)
            },
            onTriggerNewFolder: { dir in
                targetCreateFolderDir = dir
                newFolderName = "未命名文件夹"
                showNewFolderAlert = true
            },
            onTriggerNewFile: { dir in
                targetCreateFileDir = dir
                newFileName = "未命名文件.txt"
                showNewFileAlert = true
            },
            onRefresh: {
                cachedColumnItems.removeAll()
                refreshKey = UUID()
            },
            onHoverColumn: { idx in hoveredColumnIndex = idx },
            onSelectAll: { selectAllInActiveColumn() },
            onWidthChanged: { w in columnWidths[index] = w }
        )
        .task(id: "\(cacheKey)_\(refreshKey.uuidString)") {
            if cachedColumnItems[cacheKey] == nil {
                let dir = dirURL
                let sortOpt = currentSort
                let scanned = await MillerColumnDirectoryScanner.loadContentsOf(dirURL: dir)
                let sorted = DiskDirectoryBrowserView.sortItems(scanned, option: sortOpt)
                cachedColumnItems[cacheKey] = sorted
                if cachedColumnItems.count > 64 {
                    let activeKeys = Set(columnPaths.enumerated().map { idx, path in
                        let sort = perColumnSortOption[idx] ?? sortOption
                        return "\(path.absoluteString)_\(sort.rawValue)"
                    })
                    for k in Array(cachedColumnItems.keys) where !activeKeys.contains(k) {
                        cachedColumnItems.removeValue(forKey: k)
                    }
                }
            }
        }
    }
    
    private func selectItem(item: DiskItemInfo, columnIndex: Int, isCommand: Bool = false, isShift: Bool = false, dirURL: URL? = nil) {
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
    
    private func selectAllInActiveColumn() {
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
    
    private func parseVirtualURL(_ path: String) -> (archivePath: String, subpath: String) {
        if let u = URL(string: path),
           let comp = URLComponents(url: u, resolvingAgainstBaseURL: false),
           let sub = comp.queryItems?.first(where: { $0.name == "subpath" })?.value {
            var arch = u.path
            if arch.isEmpty { arch = path }
            return (arch, sub)
        }
        return (path, "")
    }
    
    private func navigateSelectionUp() {
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
    
    private func navigateSelectionDown() {
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
    
    private func navigateSelectionLeft() {
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
    
    private func navigateSelectionRight() {
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
