// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import AppKit
import TTZipCore

public struct MillerColumnItemContextMenu: View {
    public let item: DiskItemInfo
    public let columnIndex: Int
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
        self.dirURL = dirURL
        self.multiSelectedPaths = multiSelectedPaths
        self.onSelectArchive = onSelectArchive
        self.onCompressPath = onCompressPath
        self.onSelectItem = onSelectItem
        self.onTriggerNewFolder = onTriggerNewFolder
        self.onTriggerNewFile = onTriggerNewFile
    }
    
    public var body: some View {
        Button {
            onSelectItem(item, columnIndex, false, false, dirURL)
        } label: {
            Text("Selected: \(item.name)")
        }
        .disabled(true)
        
        Divider()
        
        if multiSelectedPaths.count > 1 && multiSelectedPaths.contains(item.path) {
            Button {
                let targets = Array(multiSelectedPaths).map { URL(fileURLWithPath: $0) }
                FileClipboardStore.shared.copy(urls: targets)
            } label: {
                Label("Copy \(multiSelectedPaths.count) items", systemImage: "doc.on.doc")
            }
            
            Button {
                let targets = Array(multiSelectedPaths).map { URL(fileURLWithPath: $0) }
                FileClipboardStore.shared.cut(urls: targets)
            } label: {
                Label("Cut \(multiSelectedPaths.count) items", systemImage: "scissors")
            }
            
            Divider()
            
            Button {
                onCompressPath(Array(multiSelectedPaths).joined(separator: "\n"))
            } label: {
                Label("TTZip: New Archive (\(multiSelectedPaths.count) items)...", systemImage: "archivebox.fill")
            }
            
            Button {
                for path in multiSelectedPaths {
                    let u = URL(fileURLWithPath: path)
                    try? FileManager.default.trashItem(at: u, resultingItemURL: nil)
                }
                NotificationCenter.default.post(name: NSNotification.Name("TTZipArchiveUnlockedRefresh"), object: nil)
            } label: {
                Label("Move to Trash (\(multiSelectedPaths.count) items)", systemImage: "trash")
            }
        } else if item.path.contains("?subpath=") {
            Button {
                onSelectItem(item, columnIndex, false, false, dirURL)
                let (archivePath, subpath) = MillerColumnItemRowView.parseVirtualURL(item.path)
                let destDir = (archivePath as NSString).deletingLastPathComponent
                Task {
                    let pwd = ArchivePasswordStore.shared.getPassword(for: archivePath)
                    try? await TTZipEngineFacade.shared.extractSingleEntry(archivePath: archivePath, entryPath: subpath, destinationDir: destDir, password: pwd)
                    NSWorkspace.shared.selectFile((destDir as NSString).appendingPathComponent(item.name), inFileViewerRootedAtPath: "")
                }
            } label: {
                Label("TTZip: Extract to current folder", systemImage: "arrow.down.doc.fill")
            }
            
            Button {
                onSelectItem(item, columnIndex, false, false, dirURL)
                let panel = NSOpenPanel()
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                if panel.runModal() == .OK, let destURL = panel.url {
                    let (archivePath, subpath) = MillerColumnItemRowView.parseVirtualURL(item.path)
                    Task {
                        let pwd = ArchivePasswordStore.shared.getPassword(for: archivePath)
                        try? await TTZipEngineFacade.shared.extractSingleEntry(archivePath: archivePath, entryPath: subpath, destinationDir: destURL.path, password: pwd)
                        NSWorkspace.shared.selectFile((destURL.path as NSString).appendingPathComponent(item.name), inFileViewerRootedAtPath: "")
                    }
                }
            } label: {
                Label("TTZip: Extract to specified path...", systemImage: "folder.badge.plus")
            }
            
            Divider()
            
            Button {
                let (_, subpath) = MillerColumnItemRowView.parseVirtualURL(item.path)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(subpath, forType: .string)
            } label: {
                Label("Copy archive relative path", systemImage: "doc.on.doc")
            }
        } else {
            Button {
                onSelectItem(item, columnIndex, false, false, dirURL)
                FileClipboardStore.shared.copy(urls: [URL(fileURLWithPath: item.path)])
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            
            Button {
                onSelectItem(item, columnIndex, false, false, dirURL)
                FileClipboardStore.shared.cut(urls: [URL(fileURLWithPath: item.path)])
            } label: {
                Label("Cut", systemImage: "scissors")
            }
            
            if item.isDirectory {
                Button {
                    onSelectItem(item, columnIndex, false, false, dirURL)
                    FileClipboardStore.shared.paste(to: URL(fileURLWithPath: item.path))
                } label: {
                    Label("Paste into this folder", systemImage: "doc.on.clipboard")
                }
                .disabled(!FileClipboardStore.shared.canPaste)
            }
            
            Divider()
            
            Button {
                onSelectItem(item, columnIndex, false, false, dirURL)
                let u = URL(fileURLWithPath: item.path)
                NSWorkspace.shared.open(u)
            } label: {
                Label("Open", systemImage: "arrow.up.forward.app")
            }
            
            Button {
                onSelectItem(item, columnIndex, false, false, dirURL)
                let u = URL(fileURLWithPath: item.path)
                NSWorkspace.shared.activateFileViewerSelecting([u])
            } label: {
                Label("Quick Look", systemImage: "eye")
            }
            
            Button {
                onSelectItem(item, columnIndex, false, false, dirURL)
                let script = "tell application \"Finder\" to open information window of (POSIX file \"\(item.path)\" as alias)"
                if let appleScript = NSAppleScript(source: script) {
                    var error: NSDictionary?
                    appleScript.executeAndReturnError(&error)
                }
            } label: {
                Label("Get Info", systemImage: "info.circle")
            }
            
            Button {
                onSelectItem(item, columnIndex, false, false, dirURL)
                NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }
            
            Button {
                onSelectItem(item, columnIndex, false, false, dirURL)
                onTriggerNewFolder(item.isDirectory ? URL(fileURLWithPath: item.path) : dirURL)
            } label: {
                Label("New Folder...", systemImage: "folder.badge.plus")
            }
            
            Button {
                onSelectItem(item, columnIndex, false, false, dirURL)
                onTriggerNewFile(item.isDirectory ? URL(fileURLWithPath: item.path) : dirURL)
            } label: {
                Label("New Empty File...", systemImage: "doc.badge.plus")
            }
            
            Divider()
            
            if item.isArchive {
                Button {
                    onSelectItem(item, columnIndex, false, false, dirURL)
                    onSelectArchive(item.path)
                } label: {
                    Label("TTZip: Expand and Browse", systemImage: "sidebar.right")
                }
                
                Button {
                    onSelectItem(item, columnIndex, false, false, dirURL)
                    NotificationCenter.default.post(name: NSNotification.Name("TTZipQuickExtractArchive"), object: item.path)
                } label: {
                    Label("TTZip: Quick Extract", systemImage: "arrow.down.circle.fill")
                }
                
                Button {
                    onSelectItem(item, columnIndex, false, false, dirURL)
                    NotificationCenter.default.post(name: NSNotification.Name("TTZipOpenArchiveInspector"), object: item.path)
                } label: {
                    Label("TTZip: Compliance & Diagnostics...", systemImage: "doc.badge.gearshape")
                }
                
                Button {
                    onSelectItem(item, columnIndex, false, false, dirURL)
                    NotificationCenter.default.post(name: NSNotification.Name("TTZipEncryptedArchivePromptRequired"), object: item.path)
                } label: {
                    Label("TTZip: Verify Password...", systemImage: "key.fill")
                }
            } else {
                Button {
                    onSelectItem(item, columnIndex, false, false, dirURL)
                    onCompressPath(item.path)
                } label: {
                    Label("TTZip: New Archive...", systemImage: "archivebox.fill")
                }
            }
            
            Divider()
            
            Button {
                onSelectItem(item, columnIndex, false, false, dirURL)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.path, forType: .string)
            } label: {
                Label("Copy Absolute Path", systemImage: "doc.on.doc")
            }
            
            Divider()
            
            Button(role: .destructive) {
                onSelectItem(item, columnIndex, false, false, dirURL)
                let u = URL(fileURLWithPath: item.path)
                try? FileManager.default.trashItem(at: u, resultingItemURL: nil)
                NotificationCenter.default.post(name: NSNotification.Name("TTZipArchiveUnlockedRefresh"), object: nil)
            } label: {
                Label("Move to Trash", systemImage: "trash")
            }
        }
    }
}
