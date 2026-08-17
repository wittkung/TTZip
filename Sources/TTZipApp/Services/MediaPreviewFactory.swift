import SwiftUI
import AVKit
import PDFKit
import QuickLookUI
import WebKit
import TTZipCore

/// 媒体预览视图工厂 (Factory Pattern & Open-Closed Principle)
public enum MediaPreviewFactory {
    
    /// 归档扩展名集合
    public static let archiveExtensions: Set<String> = [
        "7z", "zip", "rar", "tar", "gz", "tgz", "bz2", "xz", "001", "002", "003", "zst", "iso"
    ]
    
    /// 电子书扩展名集合
    public static let ebookExtensions: Set<String> = [
        "mobi", "azw", "azw3", "fb2", "cbz", "cbr", "ibooks"
    ]
    
    /// 图像扩展名集合
    public static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "webp", "heic", "svg", "bmp", "tiff", "ico"
    ]
    
    /// 视频扩展名集合
    public static let videoExtensions: Set<String> = [
        "mp4", "mov", "m4v", "avi", "mkv", "webm", "ogv", "flv", "3gp", "ts"
    ]
    
    /// 音频扩展名集合
    public static let audioExtensions: Set<String> = [
        "mp3", "wav", "m4a", "aac", "flac", "aifc", "aiff", "ogg", "opus", "m4b", "alac", "wma", "caf"
    ]
    
    /// DOCX/文档扩展名集合
    public static let docxExtensions: Set<String> = [
        "docx", "doc", "rtf", "odt"
    ]
    
    /// 文本与代码扩展名集合
    public static let textExtensions: Set<String> = [
        "txt", "md", "markdown", "log", "ini", "conf", "cfg", "properties", "env", "plist",
        "swift", "kt", "kts", "java", "rs", "go", "c", "cpp", "h", "hpp", "cs", "m", "mm",
        "js", "jsx", "ts", "tsx", "vue", "svelte", "py", "rb", "php", "sh", "bash", "zsh", "fish",
        "html", "css", "json", "xml", "yaml", "yml", "sql", "gradle", "srt", "ass", "vtt", "lrc", "sub"
    ]
    
    /// 动态识别 URL 对应的 MediaPreviewType (同步快速解析)
    public static func detectType(url: URL) -> MediaPreviewType {
        let ext = url.pathExtension.lowercased()
        if archiveExtensions.contains(ext) {
            return .unsupported("压缩包文件已加载，请展开双击或查看包内条目")
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
                excerptText: "电子书文件解析就绪，可在下侧画板中全屏翻阅。",
                coverImage: nil
            )
            return .ebook(meta)
        }
        return .quickLook(url)
    }

    /// 动态识别 URL 对应的 MediaPreviewType (异步深度解包与加载)
    public static func detectTypeAsync(url: URL) async -> MediaPreviewType {
        let ext = url.pathExtension.lowercased()
        
        if archiveExtensions.contains(ext) {
            return .unsupported("压缩包文件已加载，请展开双击或查看包内条目")
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
                    excerptText: "EPUB 开放出版格式电子书，包含完整章节结构与多媒体重排版。",
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
                excerptText: "电子书文件解析就绪，可在下侧画板中全屏翻阅。",
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
    
    /// 根据文件名后缀解析对应的 SFSymbol 图标名称
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

    /// 根据 URL 直接构建动态预览 AnyView
    @MainActor
    public static func makePreviewView(url: URL, fileName: String = "") async -> AnyView {
        let previewType = await detectTypeAsync(url: url)
        let name = fileName.isEmpty ? url.lastPathComponent : fileName
        return makePreviewView(type: previewType, fileName: name, fileURL: url)
    }

    /// 根据已分配的 MediaPreviewType 构建动态预览 AnyView
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
                            Text("真全屏播放中...")
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
