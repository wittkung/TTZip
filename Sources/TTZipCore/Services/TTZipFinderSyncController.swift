// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
#if canImport(AppKit) && canImport(FinderSync)
import FinderSync
import AppKit

/// Finder Sync extension controller managing dynamic right-click context menus for all archive formats.
public class TTZipFinderSyncController: FIFinderSync, @unchecked Sendable {
    
    public override init() {
        super.init()
        // Register monitored directory (root volume for contextual discovery)
        let myFolderURL = URL(fileURLWithPath: "/")
        FIFinderSyncController.default().directoryURLs = [myFolderURL]
    }
    
    // MARK: - Menu and Toolbar Item Support
    
    public override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForItems else { return nil }
        
        let selectedURLs = FIFinderSyncController.default().selectedItemURLs() ?? []
        guard !selectedURLs.isEmpty else { return nil }
        
        let menuItems = FinderSyncHelper.shared.getContextMenuItems(selectedURLs: selectedURLs)
        guard !menuItems.isEmpty else { return nil }
        
        let menu = NSMenu(title: "TTZip")
        
        for item in menuItems {
            let nsMenuItem = NSMenuItem(
                title: item.title,
                action: #selector(contextActionDispatched(_:)),
                keyEquivalent: ""
            )
            nsMenuItem.target = self
            nsMenuItem.representedObject = FinderSyncActionRequest(
                actionIdentifier: item.actionIdentifier,
                sourcePaths: selectedURLs.map(\.path),
                destinationDirectory: nil,
                sanitizeMacMetadata: false,
                password: nil
            )
            
            if let image = NSImage(systemSymbolName: item.iconSystemName, accessibilityDescription: item.title) {
                nsMenuItem.image = image
            }
            
            menu.addItem(nsMenuItem)
        }
        
        return menu
    }
    
    @objc private func contextActionDispatched(_ sender: NSMenuItem) {
        guard let request = sender.representedObject as? FinderSyncActionRequest else { return }
        
        // Dispatch action via TTZip URL scheme or direct in-process engine
        switch request.actionIdentifier {
        case "extract_here":
            for path in request.sourcePaths {
                let dest = (path as NSString).deletingLastPathComponent
                Task {
                    _ = try? await ArchiveExtractor().extract(archivePath: path, destinationDir: dest)
                }
            }
        case "extract_to_subfolder":
            for path in request.sourcePaths {
                let base = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
                let parent = (path as NSString).deletingLastPathComponent
                let dest = (parent as NSString).appendingPathComponent(base)
                Task {
                    _ = try? await ArchiveExtractor().extract(archivePath: path, destinationDir: dest)
                }
            }
        case "compress_quick_7z":
            if let first = request.sourcePaths.first {
                let out = first + ".7z"
                Task {
                    try? await ArchiveWriter().createArchive(
                        outputPath: out,
                        format: .sevenZip,
                        inputPaths: request.sourcePaths
                    )
                }
            }
        case "compress_quick_zip":
            if let first = request.sourcePaths.first {
                let out = first + ".zip"
                Task {
                    try? await ArchiveWriter().createArchive(
                        outputPath: out,
                        format: .zip,
                        inputPaths: request.sourcePaths
                    )
                }
            }
        default:
            // Interactive actions: launch main app with action payload
            if let first = request.sourcePaths.first {
                let actionRaw = request.actionIdentifier
                let urlString = "ttzip://open?action=\(actionRaw)&path=\(first.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? first)"
                if let appURL = URL(string: urlString) {
                    NSWorkspace.shared.open(appURL)
                }
            }
        }
    }
}
#endif
