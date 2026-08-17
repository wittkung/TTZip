import SwiftUI
import AppKit
import PDFKit
import QuickLookUI
import TTZipCore

public enum PDFLayoutMode: String, CaseIterable, Identifiable {
    case singleFullWidth = "单页全宽"
    case twoPages = "双页并排"
    case threePages = "三页平铺"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .singleFullWidth: return "doc.text.fill"
        case .twoPages: return "book.fill"
        case .threePages: return "square.grid.3x1.fill"
        }
    }
}

public struct InteractivePDFPreviewContainerView: View {
    public let url: URL
    @State private var layoutMode: PDFLayoutMode = .singleFullWidth
    
    public init(url: URL) {
        self.url = url
    }
    
    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                switch layoutMode {
                case .singleFullWidth, .twoPages:
                    PDFKitView(url: url, layoutMode: layoutMode)
                case .threePages:
                    PDFThreePageTileGridView(url: url)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            HStack(spacing: 6) {
                ForEach(PDFLayoutMode.allCases) { mode in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            layoutMode = mode
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 10))
                            Text(mode.rawValue)
                                .font(.system(size: 10, weight: layoutMode == mode ? .bold : .regular))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(layoutMode == mode ? TTZipTheme.bambooGreen : Color.primary.opacity(0.08))
                        .foregroundStyle(layoutMode == mode ? Color.white : Color.primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
            .padding(12)
        }
    }
}

public struct PDFThreePageTileGridView: View {
    public let url: URL
    @State private var document: PDFDocument?
    
    public init(url: URL) {
        self.url = url
    }
    
    private let columns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4)
    ]
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            if let doc = document, doc.pageCount > 0 {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(0..<doc.pageCount, id: \.self) { pageIndex in
                        if let page = doc.page(at: pageIndex) {
                            PDFPageThumbnailCard(page: page, pageIndex: pageIndex + 1)
                        }
                    }
                }
                .padding(6)
            } else {
                VStack {
                    Spacer()
                    ProgressView("解析三页平铺画布中...")
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: url) {
            self.document = PDFDocument(url: url)
        }
    }
}

public struct PDFPageThumbnailCard: View {
    public let page: PDFPage
    public let pageIndex: Int
    
    @State private var thumbnail: NSImage?
    
    public init(page: PDFPage, pageIndex: Int) {
        self.page = page
        self.pageIndex = pageIndex
    }
    
    public var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Color.white
                
                if let img = thumbnail {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .aspectRatio(0.75, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
            
            Text("第 \(pageIndex) 页")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .task(id: pageIndex) {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        let bounds = page.bounds(for: .cropBox)
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let targetSize = CGSize(width: max(bounds.width * scale * 1.5, 1200), height: max(bounds.height * scale * 1.5, 1600))
        self.thumbnail = page.thumbnail(of: targetSize, for: .cropBox)
    }
}

public final class InteractivePDFView: PDFView {
    public override func magnify(with event: NSEvent) {
        if self.autoScales {
            self.autoScales = false
        }
        let currentScale = self.scaleFactor
        let newScale = currentScale * (1.0 + event.magnification)
        self.scaleFactor = min(max(newScale, minScaleFactor), maxScaleFactor)
    }
    
    public override func smartMagnify(with event: NSEvent) {
        if self.autoScales || abs(self.scaleFactor - 1.0) < 0.2 {
            self.autoScales = false
            self.scaleFactor = 2.5
        } else {
            self.autoScales = true
        }
    }
}

public struct PDFKitView: NSViewRepresentable {
    public let url: URL
    public let layoutMode: PDFLayoutMode
    
    public init(url: URL, layoutMode: PDFLayoutMode) {
        self.url = url
        self.layoutMode = layoutMode
    }
    
    public func makeNSView(context: Context) -> PDFView {
        let pdfView = InteractivePDFView()
        pdfView.document = PDFDocument(url: url)
        pdfView.minScaleFactor = 0.25
        pdfView.maxScaleFactor = 10.0
        pdfView.interpolationQuality = .high
        pdfView.displaysPageBreaks = true
        pdfView.displayBox = .cropBox
        pdfView.wantsLayer = true
        pdfView.layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        
        applyLayoutMode(layoutMode, to: pdfView)
        configurePDFScrollView(pdfView)
        return pdfView
    }
    
    public func updateNSView(_ nsView: PDFView, context: Context) {
        if nsView.document?.documentURL != url {
            nsView.document = PDFDocument(url: url)
        }
        configurePDFScrollView(nsView)
        nsView.layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        applyLayoutMode(layoutMode, to: nsView)
    }
    
    private func configurePDFScrollView(_ pdfView: PDFView) {
        DispatchQueue.main.async {
            if let scrollView = pdfView.subviews.first(where: { $0 is NSScrollView }) as? NSScrollView {
                scrollView.allowsMagnification = true
                scrollView.minMagnification = 0.25
                scrollView.maxMagnification = 10.0
                scrollView.scrollerStyle = .overlay
                scrollView.autohidesScrollers = true
                scrollView.hasVerticalScroller = true
                scrollView.hasHorizontalScroller = true
                scrollView.verticalScroller?.scrollerStyle = .overlay
                scrollView.horizontalScroller?.scrollerStyle = .overlay
                scrollView.verticalScroller?.alphaValue = 0
                scrollView.horizontalScroller?.alphaValue = 0
            }
        }
    }
    
    private func applyLayoutMode(_ mode: PDFLayoutMode, to pdfView: PDFView) {
        switch mode {
        case .singleFullWidth:
            pdfView.displayMode = .singlePageContinuous
            pdfView.displayDirection = .vertical
            pdfView.autoScales = true
            
        case .twoPages:
            pdfView.displayMode = .twoUpContinuous
            pdfView.displayDirection = .vertical
            pdfView.displaysAsBook = false
            pdfView.autoScales = true
            
        case .threePages:
            pdfView.displayMode = .twoUpContinuous
            pdfView.displayDirection = .vertical
            pdfView.displaysAsBook = true
            pdfView.autoScales = true
        }
        
        pdfView.layoutDocumentView()
        
        DispatchQueue.main.async {
            pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
        }
    }
}

public struct QuickLookNSView: NSViewRepresentable {
    public let url: URL
    
    public init(url: URL) {
        self.url = url
    }
    
    public func makeNSView(context: Context) -> QLPreviewView {
        let preview = QLPreviewView(frame: .zero, style: .normal)!
        preview.previewItem = url as QLPreviewItem
        return preview
    }
    
    public func updateNSView(_ nsView: QLPreviewView, context: Context) {
        nsView.previewItem = url as QLPreviewItem
    }
}
