import SwiftUI
import AVKit
import PDFKit
import QuickLookUI
import WebKit
import TTZipCore

/// 全格式原生媒体预览核心调度路由组件
public struct MediaPreviewView: View {
    let fileURL: URL?
    let fileName: String
    
    @State private var previewType: MediaPreviewType = .unsupported("加载中...")
    @State private var isExtractingTemp = false
    @State private var isFullScreenActive = false
    
    public init(fileURL: URL?, fileName: String) {
        self.fileURL = fileURL
        self.fileName = fileName
    }
    
    private var isSupportedMedia: Bool {
        switch previewType {
        case .unsupported: return false
        default: return true
        }
    }
    
    private func toggleFullScreen() {
        if FullScreenMediaWindowController.shared.isPresenting {
            isFullScreenActive = false
            FullScreenMediaWindowController.shared.dismiss()
        } else {
            isFullScreenActive = true
            FullScreenMediaWindowController.shared.present(
                view: AnyView(fullScreenModalView),
                onDismiss: {
                    Task { @MainActor in
                        self.isFullScreenActive = false
                    }
                }
            )
        }
    }
    
    public var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.clear
            
            MediaPreviewFactory.makePreviewView(
                type: previewType,
                fileName: fileName,
                fileURL: fileURL,
                isFullScreenActive: isFullScreenActive
            )
            
            if isSupportedMedia {
                Button(action: { toggleFullScreen() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 11, weight: .bold))
                        Text("全屏")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.black.opacity(0.6)))
                    .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .padding(12)
                .help("切换真全屏沉浸预览 (或双击画面)")
            }
        }
        .task(id: fileURL) {
            previewType = .unsupported("正在加载媒体画板...")
            loadPreview()
        }
        .onChange(of: fileURL) { _, _ in
            if FullScreenMediaWindowController.shared.isPresenting {
                FullScreenMediaWindowController.shared.update(view: AnyView(fullScreenModalView))
            }
        }
        .onDisappear {
            if FullScreenMediaWindowController.shared.isPresenting {
                FullScreenMediaWindowController.shared.dismiss()
            }
        }
    }
    
    @ViewBuilder
    private var fullScreenModalView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            MediaPreviewFactory.makePreviewView(
                type: previewType,
                fileName: fileName,
                fileURL: fileURL,
                isFullScreenActive: false
            )
            
            VStack {
                HStack(alignment: .center) {
                    HStack(spacing: 8) {
                        Image(systemName: mediaIconName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(TTZipTheme.bambooGreen)
                        Text(fileName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    
                    Spacer()
                    
                    Button(action: { FullScreenMediaWindowController.shared.dismiss() }) {
                        HStack(spacing: 5) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                            Text("退出全屏 (Esc)")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.black.opacity(0.65)))
                        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var mediaIconName: String {
        return MediaPreviewFactory.iconName(for: fileName)
    }
    
    private func loadPreview() {
        guard let url = fileURL else {
            previewType = .unsupported("请从列表中选择文件以进行实时媒体预览")
            return
        }
        
        let targetURL = url
        Task.detached(priority: .userInitiated) {
            let type = await MediaPreviewFactory.detectTypeAsync(url: targetURL)
            await MainActor.run {
                self.previewType = type
            }
        }
    }
    
    nonisolated static func readTextContent(from url: URL) -> String? {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
        
        if let s = String(data: data, encoding: .utf8) {
            return s
        }
        
        let gbkEncoding = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
        if let s = String(data: data, encoding: String.Encoding(rawValue: gbkEncoding)) {
            return s
        }
        
        if let s = String(data: data, encoding: .utf16) {
            return s
        }
        
        if let s = String(data: data, encoding: .ascii) {
            return s
        }
        
        if let s = String(data: data, encoding: .isoLatin1) {
            return s
        }
        
        return String(decoding: data, as: UTF8.self)
    }
}
