// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import AppKit
import TTZipCore

public struct MillerColumnItemRowView: View {
    public let item: DiskItemInfo
    public let columnIndex: Int
    public let isSelected: Bool
    public let isColumnActive: Bool
    public let dirURL: URL
    public let multiSelectedPaths: Set<String>
    public let onSelectArchive: (String) -> Void
    public let onCompressPath: (String) -> Void
    public let onSelectItem: (DiskItemInfo, Int, Bool, Bool, URL?) -> Void
    public let onTriggerNewFolder: (URL) -> Void
    public let onTriggerNewFile: (URL) -> Void
    
    public init(
        item: DiskItemInfo,
        columnIndex: Int,
        isSelected: Bool,
        isColumnActive: Bool = true,
        dirURL: URL,
        multiSelectedPaths: Set<String>,
        onSelectArchive: @escaping (String) -> Void,
        onCompressPath: @escaping (String) -> Void,
        onSelectItem: @escaping (DiskItemInfo, Int, Bool, Bool, URL?) -> Void,
        onTriggerNewFolder: @escaping (URL) -> Void,
        onTriggerNewFile: @escaping (URL) -> Void
    ) {
        self.item = item
        self.columnIndex = columnIndex
        self.isSelected = isSelected
        self.isColumnActive = isColumnActive
        self.dirURL = dirURL
        self.multiSelectedPaths = multiSelectedPaths
        self.onSelectArchive = onSelectArchive
        self.onCompressPath = onCompressPath
        self.onSelectItem = onSelectItem
        self.onTriggerNewFolder = onTriggerNewFolder
        self.onTriggerNewFile = onTriggerNewFile
    }
    
    private var isEncryptedLockItem: Bool {
        item.kindText == "受密码保护的归档包" || item.name.contains("压缩包已被加密")
    }
    
    private var iconName: String {
        isEncryptedLockItem ? "lock.doc.fill" : (item.isDirectory ? "folder.fill" : (item.isArchive ? "archivebox.fill" : "doc.fill"))
    }
    
    private var iconColor: Color {
        isEncryptedLockItem ? Color.orange : (item.isDirectory ? TTZipTheme.bambooGreen : (item.isArchive ? Color.orange : Color.secondary))
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 11))
                .foregroundStyle(iconColor)
                .frame(width: 14)
            
            Text(item.name)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.primary : (isEncryptedLockItem ? Color.orange : (item.isArchive ? TTZipTheme.bambooGreen : Color.primary.opacity(0.85))))
                .lineLimit(1)
            
            Spacer()
            
            if item.isDirectory || item.isArchive {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9))
                    .foregroundStyle(item.isArchive ? TTZipTheme.bambooGreen : Color.secondary.opacity(0.6))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(isSelected ? (isColumnActive ? TTZipTheme.bambooGreen.opacity(0.18) : Color.primary.opacity(0.08)) : Color.primary.opacity(0.015))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(isSelected ? (isColumnActive ? TTZipTheme.bambooGreen.opacity(0.4) : Color.primary.opacity(0.15)) : Color.clear, lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            NSApp.keyWindow?.makeFirstResponder(nil)
            let flags = NSEvent.modifierFlags
            let isCommand = flags.contains(.command)
            let isShift = flags.contains(.shift)
            
            onSelectItem(item, columnIndex, isCommand, isShift, dirURL)
        }
        .onDrag {
            let providers = buildDragProviders()
            return providers.first ?? Self.makeDragItemProvider(for: item)
        }
        .onDrop(of: [.fileURL, .text], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
        .contextMenu {
            MillerColumnItemContextMenu(
                item: item,
                columnIndex: columnIndex,
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
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let targetDir = item.isDirectory ? URL(fileURLWithPath: item.path) : dirURL
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let srcURL = url, srcURL.isFileURL {
                    DispatchQueue.main.async {
                        FileDragDropHelper.performMove(sources: [srcURL], to: targetDir)
                    }
                }
            }
        }
        return true
    }
    
    private func buildDragProviders() -> [NSItemProvider] {
        let isMulti = multiSelectedPaths.contains(item.path) && multiSelectedPaths.count > 1
        let targets: [String] = isMulti ? Array(multiSelectedPaths) : [item.path]
        return targets.map { (path: String) -> NSItemProvider in
            if path == item.path {
                return Self.makeDragItemProvider(for: item)
            }
            let dummyItem = DiskItemInfo(
                virtualName: (path as NSString).lastPathComponent,
                virtualURL: URL(string: path) ?? URL(fileURLWithPath: path),
                isDirectory: false,
                isArchive: false,
                sizeText: "",
                rawSizeBytes: 0,
                kindText: ""
            )
            return Self.makeDragItemProvider(for: dummyItem)
        }
    }
    
    public static func parseVirtualURL(_ path: String) -> (archivePath: String, subpath: String) {
        if let u = URL(string: path),
           let comp = URLComponents(url: u, resolvingAgainstBaseURL: false),
           let sub = comp.queryItems?.first(where: { $0.name == "subpath" })?.value {
            var arch = u.path
            if arch.isEmpty { arch = path }
            return (arch, sub)
        }
        return (path, "")
    }
    
    public static func makeDragItemProvider(for item: DiskItemInfo) -> NSItemProvider {
        let (archivePath, subpath) = parseVirtualURL(item.path)
        if !subpath.isEmpty {
            let filename = (subpath as NSString).lastPathComponent
            let hash = abs(archivePath.hashValue).description + "_" + abs(filename.hashValue).description
            if let cached = PreviewLRUCacheManager.shared.cachedURL(forKey: hash),
               FileManager.default.fileExists(atPath: cached.path) {
                let provider = NSItemProvider(object: cached as NSURL)
                provider.suggestedName = filename
                return provider
            } else {
                let provider = NSItemProvider()
                provider.suggestedName = filename
                if let u = URL(string: item.path), u.scheme != nil {
                    provider.registerObject(u as NSURL, visibility: .all)
                } else {
                    provider.registerObject(URL(fileURLWithPath: item.path) as NSURL, visibility: .all)
                }
                return provider
            }
        } else {
            let fileURL = URL(fileURLWithPath: item.path)
            let provider = NSItemProvider(object: fileURL as NSURL)
            provider.suggestedName = item.name
            return provider
        }
    }
}
