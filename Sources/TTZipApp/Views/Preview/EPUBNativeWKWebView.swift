import SwiftUI
import WebKit

public struct EPUBNativeWKWebView: NSViewRepresentable {
    public let chapterURL: URL
    public let baseDirectory: URL
    public let fontSize: Double
    public let fontStyle: String
    public let readerTheme: String
    
    public init(chapterURL: URL, baseDirectory: URL, fontSize: Double, fontStyle: String, readerTheme: String) {
        self.chapterURL = chapterURL
        self.baseDirectory = baseDirectory
        self.fontSize = fontSize
        self.fontStyle = fontStyle
        self.readerTheme = readerTheme
    }
    
    public func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }
    
    public func updateNSView(_ webView: WKWebView, context: Context) {
        let bgColor: String
        let textColor: String
        switch readerTheme {
        case "sepia":
            bgColor = "#fbf0d9"
            textColor = "#5f4b32"
        case "dark":
            bgColor = "#1c1c1e"
            textColor = "#e5e5ea"
        default:
            bgColor = "#ffffff"
            textColor = "#1c1c1e"
        }
        
        let fontFamilyCSS: String
        switch fontStyle {
        case "sans":
            fontFamilyCSS = "-apple-system, BlinkMacSystemFont, \"PingFang SC\", \"Hiragino Sans GB\", \"Microsoft YaHei\", sans-serif"
        case "kaiti":
            fontFamilyCSS = "\"STKaiti\", \"KaiTi\", \"Kaiti SC\", \"Source Han Serif SC\", serif"
        case "fangsong":
            fontFamilyCSS = "\"STFangsong\", \"FangSong\", \"Fangsong SC\", \"Source Han Serif SC\", serif"
        default:
            fontFamilyCSS = "\"Source Han Serif CN\", \"Source Han Serif SC\", \"Noto Serif CJK SC\", \"Songti SC\", \"SimSun\", serif"
        }
        
        let customCSS = """
        <style>
            body {
                background-color: \(bgColor) !important;
                color: \(textColor) !important;
                font-family: \(fontFamilyCSS) !important;
                font-size: \(fontSize)px !important;
                line-height: 1.7 !important;
                padding: 20px 30px !important;
                margin: 0 auto !important;
                max-width: 800px !important;
            }
            img {
                max-width: 100% !important;
                height: auto !important;
                border-radius: 6px !important;
            }
        </style>
        """
        
        if let rawHTML = try? String(contentsOf: chapterURL, encoding: .utf8) {
            let injectedHTML: String
            if rawHTML.contains("</head>") {
                injectedHTML = rawHTML.replacingOccurrences(of: "</head>", with: "\(customCSS)</head>")
            } else {
                injectedHTML = customCSS + rawHTML
            }
            webView.loadHTMLString(injectedHTML, baseURL: baseDirectory)
        } else {
            webView.loadFileURL(chapterURL, allowingReadAccessTo: baseDirectory)
        }
    }
}
