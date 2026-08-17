import SwiftUI
import AppKit

public struct DocxDocumentReaderView: View {
    public let attributedString: NSAttributedString
    public let url: URL
    
    public init(attributedString: NSAttributedString, url: URL) {
        self.attributedString = attributedString
        self.url = url
    }
    
    public var body: some View {
        DocxTextEditorNSView(attributedString: attributedString)
    }
}

public struct DocxTextEditorNSView: NSViewRepresentable {
    public let attributedString: NSAttributedString
    
    public init(attributedString: NSAttributedString) {
        self.attributedString = attributedString
    }
    
    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .white
        
        let textView = NSTextView()
        textView.autoresizingMask = [.width]
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = .white
        textView.textContainerInset = NSSize(width: 32, height: 28)
        
        if let container = textView.textContainer {
            container.widthTracksTextView = true
            container.containerSize = NSSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)
        }
        
        let mutableAttrStr = NSMutableAttributedString(attributedString: attributedString)
        let fullRange = NSRange(location: 0, length: mutableAttrStr.length)
        
        mutableAttrStr.enumerateAttribute(.foregroundColor, in: fullRange, options: []) { value, range, _ in
            if value == nil {
                mutableAttrStr.addAttribute(.foregroundColor, value: NSColor.black, range: range)
            }
        }
        
        textView.textStorage?.setAttributedString(mutableAttrStr)
        scrollView.documentView = textView
        return scrollView
    }
    
    public func updateNSView(_ nsView: NSScrollView, context: Context) {}
}
