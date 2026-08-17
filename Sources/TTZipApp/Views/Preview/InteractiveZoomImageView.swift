import SwiftUI
import AppKit
import TTZipCore

/// 原生 macOS 图像全能放大缩小/平移手势画板
public struct InteractiveZoomImageView: View {
    public let image: NSImage
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    public init(image: NSImage) {
        self.image = image
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomTrailing) {
                ScrollView([.vertical, .horizontal], showsIndicators: scale > 1.05) {
                    ZStack {
                        Color.clear
                        
                        Image(nsImage: image)
                            .interpolation(.high)
                            .antialiased(true)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScale
                                        lastScale = value
                                        let newScale = scale * delta
                                        scale = min(max(newScale, 0.5), 10.0)
                                    }
                                    .onEnded { _ in
                                        lastScale = 1.0
                                    }
                            )
                            .simultaneousGesture(
                                DragGesture()
                                    .onChanged { value in
                                        if scale > 1.0 {
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                        }
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                            .onTapGesture(count: 2) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    if scale > 1.2 {
                                        scale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    } else {
                                        scale = 2.5
                                    }
                                }
                            }
                    }
                    .frame(
                        width: max(geometry.size.width, geometry.size.width * scale),
                        height: max(geometry.size.height, geometry.size.height * scale)
                    )
                }
                .background(ConfigureNSScrollView())
                
                HStack(spacing: 8) {
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            scale = max(scale - 0.25, 0.5)
                            if scale <= 1.0 {
                                offset = .zero
                                lastOffset = .zero
                            }
                        }
                    }) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .help("缩小 (-)")
                    
                    Text("\(Int(round(scale * 100)))%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(TTZipTheme.bambooGreen)
                        .frame(width: 44)
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            scale = min(scale + 0.25, 10.0)
                        }
                    }) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .help("放大 (+)")
                    
                    if scale != 1.0 || offset != .zero {
                        Divider()
                            .frame(height: 12)
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                scale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            }
                        }) {
                            Text("100%")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("重置 100%")
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(.thinMaterial)
                        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(TTZipTheme.hairlineBorder, lineWidth: 0.5)
                )
                .padding(12)
            }
        }
    }
}
