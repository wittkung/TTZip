// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore
import AppKit

public struct SingleMillerColumnView: View {
    @ObservedObject private var l10n = AppLocalizationState.shared
    public let index: Int
    public let dirURL: URL
    public let selectedPath: String?
    public let currentSort: DiskSortOption
    public let items: [DiskItemInfo]?
    public let currentWidth: CGFloat
    public let canGoParent: Bool
    public let isColumnActive: Bool
    public let multiSelectedPaths: Set<String>
    
    public let onPrependParent: () -> Void
    public let onChangeSort: (DiskSortOption) -> Void
    public let onSelectArchive: (String) -> Void
    public let onCompressPath: (String) -> Void
    public let onSelectItem: (DiskItemInfo, Int, Bool, Bool, URL?) -> Void
    public let onTriggerNewFolder: (URL) -> Void
    public let onTriggerNewFile: (URL) -> Void
    public let onRefresh: () -> Void
    public let onHoverColumn: (Int) -> Void
    public let onSelectAll: () -> Void
    public let onWidthChanged: (CGFloat) -> Void
    
    public init(
        index: Int,
        dirURL: URL,
        selectedPath: String?,
        currentSort: DiskSortOption,
        items: [DiskItemInfo]?,
        currentWidth: CGFloat,
        canGoParent: Bool,
        isColumnActive: Bool = true,
        multiSelectedPaths: Set<String>,
        onPrependParent: @escaping () -> Void,
        onChangeSort: @escaping (DiskSortOption) -> Void,
        onSelectArchive: @escaping (String) -> Void,
        onCompressPath: @escaping (String) -> Void,
        onSelectItem: @escaping (DiskItemInfo, Int, Bool, Bool, URL?) -> Void,
        onTriggerNewFolder: @escaping (URL) -> Void,
        onTriggerNewFile: @escaping (URL) -> Void,
        onRefresh: @escaping () -> Void,
        onHoverColumn: @escaping (Int) -> Void,
        onSelectAll: @escaping () -> Void,
        onWidthChanged: @escaping (CGFloat) -> Void
    ) {
        self.index = index
        self.dirURL = dirURL
        self.selectedPath = selectedPath
        self.currentSort = currentSort
        self.items = items
        self.currentWidth = currentWidth
        self.canGoParent = canGoParent
        self.isColumnActive = isColumnActive
        self.multiSelectedPaths = multiSelectedPaths
        self.onPrependParent = onPrependParent
        self.onChangeSort = onChangeSort
        self.onSelectArchive = onSelectArchive
        self.onCompressPath = onCompressPath
        self.onSelectItem = onSelectItem
        self.onTriggerNewFolder = onTriggerNewFolder
        self.onTriggerNewFile = onTriggerNewFile
        self.onRefresh = onRefresh
        self.onHoverColumn = onHoverColumn
        self.onSelectAll = onSelectAll
        self.onWidthChanged = onWidthChanged
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    ZStack {
                        if index == 0 && canGoParent {
                            Button(action: onPrependParent) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.primary)
                                    .padding(3)
                                    .background(Color.primary.opacity(0.08))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .help("Expand parent folder to left")
                        } else {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(TTZipTheme.bambooGreen.opacity(0.8))
                        }
                    }
                    .frame(width: 16, height: 16)
                    
                    Text(dirURL.lastPathComponent.isEmpty ? "/" : dirURL.lastPathComponent)
                        .font(.system(size: 11, weight: .bold, design: .serif))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    
                    Spacer(minLength: 4)
                    
                    Menu {
                        ForEach(DiskSortOption.allCases) { opt in
                            Button(action: { onChangeSort(opt) }) {
                                if currentSort == opt {
                                    Label(opt.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(opt.rawValue)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: currentSort.iconName)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 7))
                                .foregroundStyle(.secondary.opacity(0.6))
                        }
                        .padding(2)
                    }
                    .menuStyle(.borderlessButton)
                    .help("Change sort order")
                }
                .padding(.horizontal, 8)
                .frame(height: 30)
                .background(Color.clear)
                
                Divider()
                
                AppKitMillerColumnScrollView {
                    LazyVStack(spacing: 2) {
                        if let items = items {
                            if items.isEmpty {
                                Text(l10n.t(L10n.Explorer.emptyDirectory))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 12)
                            } else {
                                ForEach(items) { item in
                                    let isRowSelected = multiSelectedPaths.contains(item.path) || selectedPath == item.path
                                    MillerColumnItemRowView(
                                        item: item,
                                        columnIndex: index,
                                        isSelected: isRowSelected,
                                        isColumnActive: isColumnActive,
                                        dirURL: dirURL,
                                        multiSelectedPaths: multiSelectedPaths,
                                        onSelectArchive: onSelectArchive,
                                        onCompressPath: onCompressPath,
                                        onSelectItem: onSelectItem,
                                        onTriggerNewFolder: onTriggerNewFolder,
                                        onTriggerNewFile: onTriggerNewFile
                                    )
                                }
                            }
                        } else {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text(l10n.t(L10n.Common.loading))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 16)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                .background(Color.primary.opacity(0.005))
                .contentShape(Rectangle())
                .onDrop(of: [.fileURL, .text], isTargeted: nil) { providers in
                    for provider in providers {
                        _ = provider.loadObject(ofClass: URL.self) { url, _ in
                            if let srcURL = url, srcURL.isFileURL {
                                DispatchQueue.main.async {
                                    FileDragDropHelper.performMove(sources: [srcURL], to: dirURL)
                                }
                            }
                        }
                    }
                    return true
                }
                .contextMenu {
                    Button {
                        onTriggerNewFolder(dirURL)
                    } label: {
                        Label("New Folder", systemImage: "folder.badge.plus")
                    }
                    
                    Button {
                        onTriggerNewFile(dirURL)
                    } label: {
                        Label("New Empty File...", systemImage: "doc.badge.plus")
                    }
                    
                    Divider()
                    
                    Button {
                        FileClipboardStore.shared.paste(to: dirURL)
                    } label: {
                        Label(l10n.t(L10n.Common.paste), systemImage: "doc.on.clipboard")
                    }
                    .disabled(!FileClipboardStore.shared.canPaste)
                    
                    Divider()
                    
                    Button {
                        onRefresh()
                    } label: {
                        Label(l10n.t(L10n.Common.retry), systemImage: "arrow.clockwise")
                    }
                    
                    Button {
                        NSWorkspace.shared.selectFile(dirURL.path, inFileViewerRootedAtPath: "")
                    } label: {
                        Label(l10n.t(L10n.Common.revealInFinder), systemImage: "folder")
                    }
                }
            }
            .frame(width: currentWidth)
            .onHover { isHovered in
                if isHovered {
                    onHoverColumn(index)
                }
            }
            .background(
                Button("") {
                    onSelectAll()
                }
                .keyboardShortcut("a", modifiers: [.command])
                .opacity(0)
            )
            
            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(width: 1)
                .overlay(
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 8)
                        .contentShape(Rectangle())
                        .onHover { hovering in
                            if hovering { NSCursor.resizeLeftRight.push() }
                            else { NSCursor.pop() }
                        }
                        .gesture(
                            DragGesture(minimumDistance: 1)
                                .onChanged { gesture in
                                    let updated = min(max(currentWidth + gesture.translation.width, 110), 600)
                                    onWidthChanged(updated)
                                }
                        )
                )
            
            Rectangle()
                .fill(TTZipTheme.hairlineBorder)
                .frame(width: 0.5)
        }
    }
}
