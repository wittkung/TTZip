// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Represents a hierarchical preview tree node for QuickLook and explorer renderers.
/// Conforms strictly to `contracts/quicklook-preview-payload.json#/definitions/PreviewTreeNode`.
public struct PreviewTreeNode: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let relativePath: String
    public let isDirectory: Bool
    public let uncompressedSizeBytes: Int64
    public let isEncrypted: Bool
    public var children: [PreviewTreeNode]?
    
    public init(
        id: String,
        name: String,
        relativePath: String,
        isDirectory: Bool,
        uncompressedSizeBytes: Int64 = 0,
        isEncrypted: Bool = false,
        children: [PreviewTreeNode]? = nil
    ) {
        self.id = id
        self.name = name
        self.relativePath = relativePath
        self.isDirectory = isDirectory
        self.uncompressedSizeBytes = uncompressedSizeBytes
        self.isEncrypted = isEncrypted
        self.children = children
    }
    
    /// Converts an internal `ArchiveTreeNode` into a lightweight `PreviewTreeNode`.
    public static func from(archiveTreeNode node: ArchiveTreeNode) -> PreviewTreeNode {
        let childNodes = node.children?.map { PreviewTreeNode.from(archiveTreeNode: $0) }
        return PreviewTreeNode(
            id: node.path.isEmpty ? UUID().uuidString : node.path,
            name: node.name,
            relativePath: node.path,
            isDirectory: node.isDirectory,
            uncompressedSizeBytes: node.uncompressedSize,
            isEncrypted: node.entry?.isEncrypted ?? false,
            children: childNodes
        )
    }
}

/// Standardized format identifier matching `contracts/quicklook-preview-payload.json`.
public enum QuickLookFormatIdentifier: String, Codable, Sendable, CaseIterable {
    case zip
    case sevenZip = "7z"
    case tar
    case gz
    case bz2
    case xz
    case zst
    case lz4
    case lz
    case lrz
    case aar
    case sz
    case wim
    case dmg
    case iso
    case rar
    case cab
    
    /// Maps from an `ArchiveCompressionFormat`.
    public static func from(format: ArchiveCompressionFormat) -> QuickLookFormatIdentifier {
        switch format {
        case .zip: return .zip
        case .sevenZip: return .sevenZip
        case .tar: return .tar
        case .gz, .tarGz: return .gz
        case .bz2, .tarBz2: return .bz2
        case .xz, .tarXz: return .xz
        case .zst, .tarZst: return .zst
        case .lz4: return .lz4
        case .lzip: return .lz
        case .lrzip: return .lrz
        case .aar: return .aar
        case .snappy: return .sz
        case .wim: return .wim
        case .dmg: return .dmg
        case .iso: return .iso
        case .brotli: return .zip
        }
    }
    
    /// Maps from a file extension or filename string.
    public static func from(extensionString: String) -> QuickLookFormatIdentifier {
        let cleanExt = extensionString.trimmingCharacters(in: .init(charactersIn: ".")).lowercased()
        switch cleanExt {
        case "zip", "zipx", "cbz": return .zip
        case "7z", "cb7": return .sevenZip
        case "tar": return .tar
        case "gz", "tgz": return .gz
        case "bz2", "tbz2", "tbz": return .bz2
        case "xz", "txz": return .xz
        case "zst", "tzst": return .zst
        case "lz4": return .lz4
        case "lz", "lzip": return .lz
        case "lrz", "lrzip": return .lrz
        case "aar", "applearchive": return .aar
        case "sz", "snappy": return .sz
        case "wim": return .wim
        case "dmg": return .dmg
        case "iso": return .iso
        case "rar", "cbr": return .rar
        case "cab": return .cab
        default: return .zip
        }
    }
}

/// Lightweight data payload representing an archive inspected for QuickLook preview.
/// Conforms strictly to `contracts/quicklook-preview-payload.json`.
public struct QuickLookPreviewPayload: Codable, Sendable, Equatable {
    public let archivePath: String
    public let archiveName: String
    public let formatIdentifier: String
    public let uncompressedSizeBytes: Int64
    public let compressedSizeBytes: Int64
    public let compressionRatioPercent: Double
    public let totalEntriesCount: Int
    public let isEncrypted: Bool
    public let rootNodes: [PreviewTreeNode]
    
    public var format: ArchiveCompressionFormat? {
        ArchiveCompressionFormat.from(extensionOrName: formatIdentifier)
    }
    
    public init(
        archivePath: String,
        archiveName: String,
        formatIdentifier: String,
        uncompressedSizeBytes: Int64,
        compressedSizeBytes: Int64,
        compressionRatioPercent: Double,
        totalEntriesCount: Int,
        isEncrypted: Bool,
        rootNodes: [PreviewTreeNode]
    ) {
        self.archivePath = archivePath
        self.archiveName = archiveName
        self.formatIdentifier = formatIdentifier
        self.uncompressedSizeBytes = uncompressedSizeBytes
        self.compressedSizeBytes = compressedSizeBytes
        self.compressionRatioPercent = compressionRatioPercent
        self.totalEntriesCount = totalEntriesCount
        self.isEncrypted = isEncrypted
        self.rootNodes = rootNodes
    }
    
    public init(
        archivePath: String,
        archiveName: String,
        format: ArchiveCompressionFormat,
        uncompressedSizeBytes: Int64,
        compressedSizeBytes: Int64,
        compressionRatioPercent: Double,
        totalEntriesCount: Int,
        isEncrypted: Bool,
        rootNodes: [PreviewTreeNode]
    ) {
        self.archivePath = archivePath
        self.archiveName = archiveName
        self.formatIdentifier = QuickLookFormatIdentifier.from(format: format).rawValue
        self.uncompressedSizeBytes = uncompressedSizeBytes
        self.compressedSizeBytes = compressedSizeBytes
        self.compressionRatioPercent = compressionRatioPercent
        self.totalEntriesCount = totalEntriesCount
        self.isEncrypted = isEncrypted
        self.rootNodes = rootNodes
    }
}

/// Backward compatibility alias
public typealias QuickLookPreviewData = QuickLookPreviewPayload

// MARK: - QuickLook Preview Engine

//
//


/// Out-of-process, non-blocking QuickLook preview and HTML5 rendering engine for all 16 supported archive formats.
public enum QuickLookPreviewEngine: Sendable {
    
    /// Inspects an archive header in-process and builds a lightweight `QuickLookPreviewPayload` model in milliseconds.
    public static func inspectForPreview(archivePath: String, password: String? = nil) async throws -> QuickLookPreviewPayload {
        let url = URL(fileURLWithPath: archivePath)
        let archiveName = url.lastPathComponent
        
        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: archivePath, password: password)
        let rootArchiveNodes = ArchiveTreeBuilder.buildTree(from: entries)
        let previewNodes = rootArchiveNodes.map { PreviewTreeNode.from(archiveTreeNode: $0) }
        
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: archivePath)[.size] as? Int64) ?? 0
        
        let uncompressedSize = entries.reduce(0) { $0 + $1.uncompressedSize }
        let compressedSize = fileSize
        let ratio: Double
        if uncompressedSize > 0 && compressedSize > 0 {
            ratio = max(0.0, (1.0 - Double(compressedSize) / Double(uncompressedSize)) * 100.0)
        } else {
            ratio = 0.0
        }
        
        let detectedFormat = ArchiveCompressionFormat.from(extensionOrName: url.pathExtension) ?? .zip
        let formatIdentifier = QuickLookFormatIdentifier.from(format: detectedFormat).rawValue
        let isEncrypted = entries.contains { $0.isEncrypted }
        
        return QuickLookPreviewPayload(
            archivePath: archivePath,
            archiveName: archiveName,
            formatIdentifier: formatIdentifier,
            uncompressedSizeBytes: uncompressedSize,
            compressedSizeBytes: compressedSize,
            compressionRatioPercent: ratio,
            totalEntriesCount: entries.count,
            isEncrypted: isEncrypted,
            rootNodes: previewNodes
        )
    }
    
    /// Extracts a single in-archive file directly into memory for QuickLook previews (<10ms zero disk write).
    public static func extractSingleFileMemoryStream(
        archivePath: String,
        entryPath: String,
        password: String? = nil
    ) async throws -> Data? {
        return try await ArchiveSelectiveExtractor.shared.extractSingleEntryData(
            archivePath: archivePath,
            entryPath: entryPath,
            password: password
        )
    }
    
    /// Generates a rich, responsive, dark/light adaptive HTML5 preview document for QuickLook rendering.
    public static func generateHTMLPreview(for archivePath: String, password: String? = nil) async throws -> String {
        let data = try await inspectForPreview(archivePath: archivePath, password: password)
        let formattedUncompressed = ByteCountFormatter.string(fromByteCount: data.uncompressedSizeBytes, countStyle: .file)
        let formattedCompressed = ByteCountFormatter.string(fromByteCount: data.compressedSizeBytes, countStyle: .file)
        
        var rowsHTML = ""
        func renderNodes(_ nodes: [PreviewTreeNode], depth: Int) {
            for node in nodes {
                let indent = String(repeating: "&nbsp;&nbsp;&nbsp;&nbsp;", count: depth)
                let icon = node.isDirectory ? "📁" : fileIconEmoji(for: node.name)
                let sizeStr = node.isDirectory ? "--" : ByteCountFormatter.string(fromByteCount: node.uncompressedSizeBytes, countStyle: .file)
                let isEnc = node.isEncrypted
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
                        <span>\((data.format?.displayName ?? data.formatIdentifier).uppercased())</span> •
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
