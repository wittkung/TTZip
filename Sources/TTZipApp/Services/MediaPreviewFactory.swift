// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import AVKit
import PDFKit
import QuickLookUI
import WebKit
import TTZipCore

/// Media preview view factory for dynamic media previews.
public enum MediaPreviewFactory {
    
    /// Archive extensions.
    public static let archiveExtensions: Set<String> = [
        "7z", "zip", "rar", "tar", "gz", "tgz", "bz2", "xz", "001", "002", "003", "zst", "iso"
    ]
    
    /// E-book extensions.
    public static let ebookExtensions: Set<String> = [
        "mobi", "azw", "azw3", "fb2", "cbz", "cbr", "ibooks"
    ]
    
    /// Image extensions.
    public static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "webp", "heic", "svg", "bmp", "tiff", "ico"
    ]
    
    /// Video extensions.
    public static let videoExtensions: Set<String> = [
        "mp4", "mov", "m4v", "avi", "mkv", "webm", "ogv", "flv", "3gp", "ts"
    ]
    
    /// Audio extensions.
    public static let audioExtensions: Set<String> = [
        "mp3", "wav", "m4a", "aac", "flac", "aifc", "aiff", "ogg", "opus", "m4b", "alac", "wma", "caf"
    ]
    
    /// Document extensions.
    public static let docxExtensions: Set<String> = [
        "docx", "doc", "rtf", "odt"
    ]
    
    /// Text and code extensions.
    public static let textExtensions: Set<String> = [
        "txt", "md", "markdown", "log", "ini", "conf", "cfg", "properties", "env", "plist",
        "swift", "kt", "kts", "java", "rs", "go", "c", "cpp", "h", "hpp", "cs", "m", "mm",
        "js", "jsx", "ts", "tsx", "vue", "svelte", "py", "rb", "php", "sh", "bash", "zsh", "fish",
        "html", "css", "json", "xml", "yaml", "yml", "sql", "gradle", "srt", "ass", "vtt", "lrc", "sub"
    ]
    
    /// Detects MediaPreviewType synchronously for URL.
    public static func detectType(url: URL) -> MediaPreviewType {
        let ext = url.pathExtension.lowercased()
        if archiveExtensions.contains(ext) {
            return .unsupported("Archive loaded. Double-click to browse contents.")
        }
        if imageExtensions.contains(ext), let image = NSImage(contentsOf: url) {
            return .image(image)
        }
        if videoExtensions.contains(ext) {
            return .video(url)
        }
        if audioExtensions.contains(ext) {
            return .audio(url)
        }
        if ext == "pdf" {
            return .pdf(url)
        }
        if ebookExtensions.contains(ext) {
            let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            let sizeStr = ByteCountFormatterFlyweight.shared.string(fromByteCount: Int64(fileSize))
            let meta = EBookMetadata(
                url: url,
                title: url.deletingPathExtension().lastPathComponent,
                formatName: ext.uppercased(),
                fileSizeDescription: sizeStr,
                excerptText: "E-Book ready for full-screen reading.",
                coverImage: nil
            )
            return .ebook(meta)
        }
        return .quickLook(url)
    }

    /// Detects MediaPreviewType asynchronously with deep unpacking.
    public static func detectTypeAsync(url: URL) async -> MediaPreviewType {
        let ext = url.pathExtension.lowercased()
        
        if archiveExtensions.contains(ext) {
            return .unsupported("Archive loaded. Double-click to browse contents.")
        }
        
        if ext == "epub" {
            if let bookModel = EPUBArchiveUnpacker.unpackAndParseEPUB(at: url) {
                return .epubBook(bookModel)
            } else {
                let meta = EBookMetadata(
                    url: url,
                    title: url.deletingPathExtension().lastPathComponent,
                    formatName: "EPUB",
                    fileSizeDescription: "",
                    excerptText: "EPUB open publication format e-book with full structure.",
                    coverImage: nil
                )
                return .ebook(meta)
            }
        }
        
        if ebookExtensions.contains(ext) {
            let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            let sizeStr = ByteCountFormatterFlyweight.shared.string(fromByteCount: Int64(fileSize))
            let meta = EBookMetadata(
                url: url,
                title: url.deletingPathExtension().lastPathComponent,
                formatName: ext.uppercased(),
                fileSizeDescription: sizeStr,
                excerptText: "E-Book ready for full-screen reading.",
                coverImage: nil
            )
            return .ebook(meta)
        }
        
        if imageExtensions.contains(ext) {
            if let image = NSImage(contentsOf: url) {
                return .image(image)
            }
        }
        
        if videoExtensions.contains(ext) {
            return .video(url)
        }
        
        if audioExtensions.contains(ext) {
            return .audio(url)
        }
        
        if ext == "pdf" {
            return .pdf(url)
        }
        
        if docxExtensions.contains(ext) {
            if let attrStr = try? NSAttributedString(url: url, options: [:], documentAttributes: nil) {
                return .docxDocument(attrStr, url)
            }
            return .quickLook(url)
        }
        
        if textExtensions.contains(ext) {
            if let content = MediaPreviewView.readTextContent(from: url) {
                return .text(content)
            }
            return .quickLook(url)
        }
        
        return .quickLook(url)
    }
    
    /// Resolves SF Symbol icon name for file name.
    public static func iconName(for fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        if imageExtensions.contains(ext) { return "photo.fill" }
        if videoExtensions.contains(ext) { return "film.fill" }
        if audioExtensions.contains(ext) { return "music.note" }
        if ext == "pdf" { return "doc.richtext.fill" }
        if ext == "epub" || ebookExtensions.contains(ext) { return "book.closed.fill" }
        if ["srt", "ass", "vtt", "sub", "lrc"].contains(ext) { return "captions.bubble.fill" }
        if textExtensions.contains(ext) {
            if ["txt", "md", "log", "ini", "conf", "cfg", "properties", "env", "plist"].contains(ext) {
                return "doc.text.fill"
            }
            return "chevron.left.forwardslash.chevron.right"
        }
        return "doc.fill"
    }

    @MainActor
    public static func makePreviewView(url: URL, fileName: String = "") async -> AnyView {
        let previewType = await detectTypeAsync(url: url)
        let name = fileName.isEmpty ? url.lastPathComponent : fileName
        return makePreviewView(type: previewType, fileName: name, fileURL: url)
    }

    @MainActor
    public static func makePreviewView(
        type: MediaPreviewType,
        fileName: String,
        fileURL: URL?,
        isFullScreenActive: Bool = false
    ) -> AnyView {
        switch type {
        case .image(let nsImage):
            return AnyView(
                InteractiveZoomImageView(image: nsImage)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            )
            
        case .video(let url):
            if isFullScreenActive {
                return AnyView(
                    ZStack {
                        Color.black
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 24))
                                .foregroundStyle(TTZipTheme.bambooGreen)
                            Text("Full-screen playback active...")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                )
            } else {
                return AnyView(
                    UnifiedVideoPlayerView(url: url)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                )
            }
            
        case .audio(let url):
            return AnyView(
                UnifiedAudioPlayerView(url: url, fileName: fileName)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            )
            
        case .pdf(let url):
            return AnyView(
                InteractivePDFPreviewContainerView(url: url)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            )
            
        case .text(let textContent):
            return AnyView(
                CodeTextEditorContainerView(initialText: textContent, fileURL: fileURL, fileName: fileName)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            )
            
        case .docxDocument(let attrStr, let url):
            return AnyView(
                DocxDocumentReaderView(attributedString: attrStr, url: url)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            )
            
        case .epubBook(let bookModel):
            return AnyView(
                InteractiveEPUBReaderView(bookModel: bookModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            )
            
        case .ebook(let metadata):
            return AnyView(
                EBookReaderPreviewView(metadata: metadata)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            )
            
        case .quickLook(let url):
            return AnyView(
                QuickLookNSView(url: url)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            )
            
        case .unsupported(let msg):
            return AnyView(
                VStack(spacing: 12) {
                    Image(systemName: "doc.viewfinder.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text(msg)
                        .font(.subheadline)
                }
            )
        }
    }
}
