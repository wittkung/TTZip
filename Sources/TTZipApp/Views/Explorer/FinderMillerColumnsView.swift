// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore
import AppKit

public struct FinderMillerColumnsView: View {
    public let rootDirectory: URL
    public var initialSelectedPath: String? = nil
    public var sortOption: DiskSortOption = .nameAsc
    public var onNavigateUp: (() -> Void)? = nil
    public let onSelectArchive: (String) -> Void
    public let onCompressPath: (String) -> Void
    public let onPreviewFile: (String) -> Void
    public let onSelectItem: (DiskItemInfo) -> Void
    
    @State var columnPaths: [URL] = []
    @State var selectedPaths: [Int: String] = [:]
    @State var multiSelectedPaths: Set<String> = []
    @State var hoveredColumnIndex: Int? = nil
    @State var selectedItem: DiskItemInfo? = nil
    @State var cachedColumnItems: [String: [DiskItemInfo]] = [:]
    @State var refreshKey: UUID = UUID()
    @State var columnWidths: [Int: CGFloat] = [:]
    @State var perColumnSortOption: [Int: DiskSortOption] = [:]
    @State var eventMonitor: Any? = nil
    
    @State var showNewFolderAlert: Bool = false
    @State var newFolderName: String = "Untitled Folder"
    @State var targetCreateFolderDir: URL? = nil
    
    @State var showNewFileAlert: Bool = false
    @State var newFileName: String = "Untitled.txt"
    @State var targetCreateFileDir: URL? = nil
    
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
        .alert("New Folder", isPresented: $showNewFolderAlert) {
            TextField("Folder Name", text: $newFolderName)
            Button("Cancel", role: .cancel) {
                newFolderName = "Untitled Folder"
            }
            Button("Create") {
                let dir = targetCreateFolderDir ?? rootDirectory
                createNewFolder(in: dir, name: newFolderName)
                newFolderName = "Untitled Folder"
            }
        } message: {
            if let dir = targetCreateFolderDir {
                Text("Creating new folder in:\n\(dir.path)")
            } else {
                Text("Create a new folder")
            }
        }
        .alert("New File", isPresented: $showNewFileAlert) {
            TextField("File Name (e.g. text.txt)", text: $newFileName)
            Button("Cancel", role: .cancel) {
                newFileName = "Untitled.txt"
            }
            Button("Create") {
                let dir = targetCreateFileDir ?? rootDirectory
                createNewFile(in: dir, name: newFileName)
                newFileName = "Untitled.txt"
            }
        } message: {
            if let dir = targetCreateFileDir {
                Text("Creating new file in:\n\(dir.path)")
            } else {
                Text("Create a new empty file")
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
                    case 123:
                        navigateSelectionLeft()
                    case 124:
                        navigateSelectionRight()
                    case 125:
                        navigateSelectionDown()
                    case 126:
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
    
    func millerColumn(index: Int, dirURL: URL) -> some View {
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
                newFolderName = "Untitled Folder"
                showNewFolderAlert = true
            },
            onTriggerNewFile: { dir in
                targetCreateFileDir = dir
                newFileName = "Untitled.txt"
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
                let sorted = DiskItemSorter.sort(scanned, by: sortOpt)
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
}
