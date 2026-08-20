// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// macOS Finder context menu action item matching industrial standards.
public struct FinderContextMenuItem: Sendable, Equatable {
    public let title: String
    public let actionIdentifier: String
    public let iconSystemName: String
    public let isDestructive: Bool
    
    public init(
        title: String,
        actionIdentifier: String,
        iconSystemName: String = "archivebox",
        isDestructive: Bool = false
    ) {
        self.title = title
        self.actionIdentifier = actionIdentifier
        self.iconSystemName = iconSystemName
        self.isDestructive = isDestructive
    }
}

/// Helper facilitating FinderSync context menu construction across all 16 supported archive formats.
public final class FinderSyncHelper: @unchecked Sendable {
    public static let shared = FinderSyncHelper()
    
    private init() {}
    
    public typealias ContextMenuItem = FinderContextMenuItem
    
    /// Supported archive extensions recognized by FinderSync context menu dispatcher.
    public static let supportedArchiveExtensions: Set<String> = [
        "zip", "zipx", "cbz", "7z", "cb7", "tar", "gz", "tgz", "bz2", "tbz2", "tbz",
        "xz", "txz", "zst", "tzst", "lz4", "br", "lz", "lzip", "lrz", "lrzip",
        "aar", "applearchive", "sz", "snappy", "wim", "dmg", "iso", "rar", "cbr", "cab", "001"
    ]
    
    /// Returns the dynamic context menu items based on the user's selected file URLs.
    public func getContextMenuItems(selectedURLs: [URL]) -> [FinderContextMenuItem] {
        guard !selectedURLs.isEmpty else { return [] }
        
        let firstURL = selectedURLs[0]
        let baseName = selectedURLs.count == 1 ? firstURL.deletingPathExtension().lastPathComponent : "ArchiveBundle"
        let ext = firstURL.pathExtension.lowercased()
        let isArchive = Self.supportedArchiveExtensions.contains(ext)
        let manager = TTZipLocalizationManager.shared
        
        if isArchive {
            return [
                FinderContextMenuItem(title: "⚡️ " + manager.string(for: L10n.Menu.finderExtractHere) + " (\(baseName))", actionIdentifier: "extract_here", iconSystemName: "arrow.down.doc"),
                FinderContextMenuItem(title: "📂 " + manager.string(for: L10n.Menu.finderExtractSubfolder), actionIdentifier: "extract_to_subfolder", iconSystemName: "folder.badge.plus"),
                FinderContextMenuItem(title: "🔍 " + manager.string(for: L10n.Menu.finderInspect) + "...", actionIdentifier: "inspect_archive", iconSystemName: "eye"),
                FinderContextMenuItem(title: "🔑 " + manager.string(for: L10n.Menu.finderAutofillVault), actionIdentifier: "autofill_password", iconSystemName: "key"),
                FinderContextMenuItem(title: "🛡️ " + manager.string(for: L10n.Menu.finderComputeHash), actionIdentifier: "compute_hash", iconSystemName: "checkmark.shield")
            ]
        } else {
            return [
                FinderContextMenuItem(title: "🌟 " + manager.string(for: L10n.Menu.finderCompress7z) + " (\"\(baseName).7z\")", actionIdentifier: "compress_quick_7z", iconSystemName: "sparkles"),
                FinderContextMenuItem(title: "📦 " + manager.string(for: L10n.Menu.finderCompressZip) + " (\"\(baseName).zip\")", actionIdentifier: "compress_quick_zip", iconSystemName: "archivebox"),
                FinderContextMenuItem(title: "📑 " + manager.string(for: L10n.Menu.finderCompressSeparate), actionIdentifier: "compress_separate", iconSystemName: "doc.on.doc"),
                FinderContextMenuItem(title: "🧹 " + manager.string(for: L10n.Menu.finderCompressDeleteSource), actionIdentifier: "compress_and_delete_source", iconSystemName: "trash", isDestructive: true),
                FinderContextMenuItem(title: "⚙️ " + manager.string(for: L10n.Menu.finderCompressAdvanced), actionIdentifier: "compress_modal_advanced", iconSystemName: "slider.horizontal.3")
            ]
        }
    }
}
