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
        let isZh = TTZipLocalizationManager.shared.currentLanguage == .zhHans
        
        if isArchive {
            if isZh {
                return [
                    FinderContextMenuItem(title: "⚡️ 解压到当前文件夹 (\(baseName))", actionIdentifier: "extract_here", iconSystemName: "arrow.down.doc"),
                    FinderContextMenuItem(title: "📂 自动创建同名独立文件夹解压", actionIdentifier: "extract_to_subfolder", iconSystemName: "folder.badge.plus"),
                    FinderContextMenuItem(title: "🔍 浏览包内结构与媒体预览...", actionIdentifier: "inspect_archive", iconSystemName: "eye"),
                    FinderContextMenuItem(title: "🔑 提取前预检/自动匹配密码库", actionIdentifier: "autofill_password", iconSystemName: "key"),
                    FinderContextMenuItem(title: "🛡️ 计算文件 CRC32 / SHA-256 散列", actionIdentifier: "compute_hash", iconSystemName: "checkmark.shield")
                ]
            } else {
                return [
                    FinderContextMenuItem(title: "⚡️ Extract Here (\(baseName))", actionIdentifier: "extract_here", iconSystemName: "arrow.down.doc"),
                    FinderContextMenuItem(title: "📂 Extract to \"\(baseName)/\"", actionIdentifier: "extract_to_subfolder", iconSystemName: "folder.badge.plus"),
                    FinderContextMenuItem(title: "🔍 Inspect Archive & Quick Preview...", actionIdentifier: "inspect_archive", iconSystemName: "eye"),
                    FinderContextMenuItem(title: "🔑 Verify with Password Vault", actionIdentifier: "autofill_password", iconSystemName: "key"),
                    FinderContextMenuItem(title: "🛡️ Compute CRC32 / SHA-256 Checksum", actionIdentifier: "compute_hash", iconSystemName: "checkmark.shield")
                ]
            }
        } else {
            if isZh {
                return [
                    FinderContextMenuItem(title: "🌟 添加到 \"\(baseName).7z\" (推荐新标准)", actionIdentifier: "compress_quick_7z", iconSystemName: "sparkles"),
                    FinderContextMenuItem(title: "📦 添加到 \"\(baseName).zip\" (兼容传统格式)", actionIdentifier: "compress_quick_zip", iconSystemName: "archivebox"),
                    FinderContextMenuItem(title: "📑 压缩到单独的归档文件 (批量独立打包)", actionIdentifier: "compress_separate", iconSystemName: "doc.on.doc"),
                    FinderContextMenuItem(title: "🧹 压缩并自动删除源文件", actionIdentifier: "compress_and_delete_source", iconSystemName: "trash", isDestructive: true),
                    FinderContextMenuItem(title: "⚙️ 高级加密/分卷/预设压缩...", actionIdentifier: "compress_modal_advanced", iconSystemName: "slider.horizontal.3")
                ]
            } else {
                return [
                    FinderContextMenuItem(title: "🌟 Add to \"\(baseName).7z\" (High Compression)", actionIdentifier: "compress_quick_7z", iconSystemName: "sparkles"),
                    FinderContextMenuItem(title: "📦 Add to \"\(baseName).zip\" (Universal Standard)", actionIdentifier: "compress_quick_zip", iconSystemName: "archivebox"),
                    FinderContextMenuItem(title: "📑 Compress Each Item to Separate Archive", actionIdentifier: "compress_separate", iconSystemName: "doc.on.doc"),
                    FinderContextMenuItem(title: "🧹 Compress and Delete Source Files", actionIdentifier: "compress_and_delete_source", iconSystemName: "trash", isDestructive: true),
                    FinderContextMenuItem(title: "⚙️ Advanced Encryption & Presets...", actionIdentifier: "compress_modal_advanced", iconSystemName: "slider.horizontal.3")
                ]
            }
        }
    }
}
