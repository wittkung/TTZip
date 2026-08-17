// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Weitao Kung (Witt Kung) <kevintungs@163.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Lightweight data payload representing an archive inspected for QuickLook preview.
public struct QuickLookPreviewData: Sendable, Equatable {
    public let archivePath: String
    public let archiveName: String
    public let format: ArchiveCompressionFormat
    public let uncompressedSizeBytes: Int64
    public let compressedSizeBytes: Int64
    public let compressionRatioPercent: Double
    public let totalEntriesCount: Int
    public let isEncrypted: Bool
    public let rootNodes: [ArchiveTreeNode]
    
    public init(
        archivePath: String,
        archiveName: String,
        format: ArchiveCompressionFormat,
        uncompressedSizeBytes: Int64,
        compressedSizeBytes: Int64,
        compressionRatioPercent: Double,
        totalEntriesCount: Int,
        isEncrypted: Bool,
        rootNodes: [ArchiveTreeNode]
    ) {
        self.archivePath = archivePath
        self.archiveName = archiveName
        self.format = format
        self.uncompressedSizeBytes = uncompressedSizeBytes
        self.compressedSizeBytes = compressedSizeBytes
        self.compressionRatioPercent = compressionRatioPercent
        self.totalEntriesCount = totalEntriesCount
        self.isEncrypted = isEncrypted
        self.rootNodes = rootNodes
    }
}

/// Out-of-process, non-blocking QuickLook preview and HTML5 rendering engine for all 16 supported archive formats.
public enum QuickLookPreviewEngine: Sendable {
    
    /// Inspects an archive header in-process and builds a lightweight `QuickLookPreviewData` model in milliseconds.
    public static func inspectForPreview(archivePath: String, password: String? = nil) async throws -> QuickLookPreviewData {
        let url = URL(fileURLWithPath: archivePath)
        let archiveName = url.lastPathComponent
        
        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: archivePath, password: password)
        let rootNodes = ArchiveTreeBuilder.buildTree(from: entries)
        
        var fileSize: Int64 = 0
        _ = ttzip_stat_file_info(archivePath, &fileSize, nil, nil)
        
        let uncompressedSize = entries.reduce(0) { $0 + $1.uncompressedSize }
        let compressedSize = fileSize
        let ratio: Double
        if uncompressedSize > 0 && compressedSize > 0 {
            ratio = max(0.0, (1.0 - Double(compressedSize) / Double(uncompressedSize)) * 100.0)
        } else {
            ratio = 0.0
        }
        
        let detectedFormat = ArchiveCompressionFormat.from(extensionOrName: url.pathExtension) ?? .zip
        let isEncrypted = entries.contains { $0.isEncrypted }
        
        return QuickLookPreviewData(
            archivePath: archivePath,
            archiveName: archiveName,
            format: detectedFormat,
            uncompressedSizeBytes: uncompressedSize,
            compressedSizeBytes: compressedSize,
            compressionRatioPercent: ratio,
            totalEntriesCount: entries.count,
            isEncrypted: isEncrypted,
            rootNodes: rootNodes
        )
    }
    
    /// Generates a rich, responsive, dark/light adaptive HTML5 preview document for QuickLook rendering.
    public static func generateHTMLPreview(for archivePath: String, password: String? = nil) async throws -> String {
        let data = try await inspectForPreview(archivePath: archivePath, password: password)
        let formattedUncompressed = ByteCountFormatter.string(fromByteCount: data.uncompressedSizeBytes, countStyle: .file)
        let formattedCompressed = ByteCountFormatter.string(fromByteCount: data.compressedSizeBytes, countStyle: .file)
        
        var rowsHTML = ""
        func renderNodes(_ nodes: [ArchiveTreeNode], depth: Int) {
            for node in nodes {
                let indent = String(repeating: "&nbsp;&nbsp;&nbsp;&nbsp;", count: depth)
                let icon = node.isDirectory ? "📁" : fileIconEmoji(for: node.name)
                let sizeStr = node.isDirectory ? "--" : ByteCountFormatter.string(fromByteCount: node.uncompressedSize, countStyle: .file)
                let isEnc = node.entry?.isEncrypted ?? false
                let encBadge = isEnc ? "<span class='badge enc'>🔒</span>" : ""
                
                rowsHTML += """
                <tr>
                    <td class="name-col">\(indent)<span class="icon">\(icon)</span> \(escapeHTML(node.name)) \(encBadge)</td>
                    <td class="size-col">\(sizeStr)</td>
                </tr>
                """
                if node.isDirectory, let children = node.children, !children.isEmpty {
                    renderNodes(children, depth: depth + 1)
                }
            }
        }
        renderNodes(data.rootNodes, depth: 0)
        
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>\(escapeHTML(data.archiveName)) — TTZip QuickLook</title>
            <style>
                :root {
                    --bg-color: #FFFFFF;
                    --text-color: #1D1D1F;
                    --secondary-text: #86868B;
                    --border-color: #E5E5EA;
                    --header-bg: #F5F5F7;
                    --badge-bg: #0071E3;
                    --badge-text: #FFFFFF;
                    --accent-gold: #D4AF37;
                }
                @media (prefers-color-scheme: dark) {
                    :root {
                        --bg-color: #1C1C1E;
                        --text-color: #F5F5F7;
                        --secondary-text: #98989D;
                        --border-color: #2C2C2E;
                        --header-bg: #2C2C2E;
                        --badge-bg: #0A84FF;
                        --badge-text: #FFFFFF;
                    }
                }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif;
                    background-color: var(--bg-color);
                    color: var(--text-color);
                    margin: 0;
                    padding: 24px;
                    font-size: 13px;
                    line-height: 1.5;
                }
                .header {
                    display: flex;
                    align-items: center;
                    justify-content: space-between;
                    border-bottom: 1px solid var(--border-color);
                    padding-bottom: 16px;
                    margin-bottom: 16px;
                }
                .title-section h1 {
                    font-size: 18px;
                    font-weight: 600;
                    margin: 0 0 4px 0;
                    letter-spacing: -0.01em;
                }
                .meta-stats {
                    font-size: 12px;
                    color: var(--secondary-text);
                    display: flex;
                    gap: 12px;
                }
                .badge {
                    display: inline-block;
                    padding: 2px 8px;
                    border-radius: 6px;
                    font-size: 11px;
                    font-weight: 600;
                    background-color: var(--badge-bg);
                    color: var(--badge-text);
                }
                .badge.enc {
                    background-color: var(--accent-gold);
                }
                table {
                    width: 100%;
                    border-collapse: collapse;
                }
                th {
                    text-align: left;
                    font-size: 11px;
                    font-weight: 600;
                    color: var(--secondary-text);
                    text-transform: uppercase;
                    border-bottom: 1px solid var(--border-color);
                    padding: 6px 12px;
                }
                td {
                    padding: 6px 12px;
                    border-bottom: 1px solid var(--border-color);
                }
                .name-col {
                    width: 75%;
                }
                .size-col {
                    width: 25%;
                    text-align: right;
                    color: var(--secondary-text);
                    font-variant-numeric: tabular-nums;
                }
                .icon {
                    margin-right: 6px;
                }
                .footer {
                    margin-top: 20px;
                    text-align: center;
                    font-size: 11px;
                    color: var(--secondary-text);
                }
            </style>
        </head>
        <body>
            <div class="header">
                <div class="title-section">
                    <h1>\(escapeHTML(data.archiveName))</h1>
                    <div class="meta-stats">
                        <span>\(data.format.displayName.uppercased())</span> •
                        <span>\(data.totalEntriesCount) items</span> •
                        <span>\(formattedUncompressed) (Compressed: \(formattedCompressed))</span>
                        \(data.isEncrypted ? "• <span class='badge enc'>Encrypted</span>" : "")
                    </div>
                </div>
                <div class="badge">TTZip ⚡️</div>
            </div>
            <table>
                <thead>
                    <tr>
                        <th class="name-col">Name</th>
                        <th class="size-col">Size</th>
                    </tr>
                </thead>
                <tbody>
                    \(rowsHTML)
                </tbody>
            </table>
            <div class="footer">
                Rendered with TTZip High-Performance In-Process Engine
            </div>
        </body>
        </html>
        """
    }
    
    private static func fileIconEmoji(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "gif", "webp", "heic", "svg":
            return "🖼️"
        case "mp4", "mov", "mkv", "avi", "webm":
            return "🎬"
        case "mp3", "m4a", "wav", "flac", "aac":
            return "🎵"
        case "swift", "c", "h", "cpp", "rs", "go", "py", "js", "ts", "html", "css", "json", "xml", "yaml", "yml":
            return "💻"
        case "pdf":
            return "📕"
        case "zip", "7z", "tar", "gz", "xz", "zst", "rar", "bz2":
            return "📦"
        default:
            return "📄"
        }
    }
    
    private static func escapeHTML(_ str: String) -> String {
        return str
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
