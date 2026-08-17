import SwiftUI
import TTZipCore

public struct CompressionProgressModalView: View {
    let outputFileName: String
    let progress: ArchiveProgress
    let onCancel: () -> Void
    let onMinimize: () -> Void
    
    public init(
        outputFileName: String,
        progress: ArchiveProgress,
        onCancel: @escaping () -> Void,
        onMinimize: @escaping () -> Void
    ) {
        self.outputFileName = outputFileName
        self.progress = progress
        self.onCancel = onCancel
        self.onMinimize = onMinimize
    }
    
    private var formattedBytesProcessed: String {
        ByteCountFormatterFlyweight.shared.string(fromByteCount: progress.bytesProcessed)
    }
    
    private var formattedTotalBytes: String {
        ByteCountFormatterFlyweight.shared.string(fromByteCount: max(progress.totalBytes, progress.bytesProcessed))
    }
    
    private var estimatedRemainingSeconds: String {
        guard progress.throughputMBs > 0, progress.totalBytes > progress.bytesProcessed else {
            return "计算中..."
        }
        let remainingBytes = Double(progress.totalBytes - progress.bytesProcessed)
        let remainingMB = remainingBytes / (1024 * 1024)
        let seconds = remainingMB / progress.throughputMBs
        if seconds < 1 { return "即将完成" }
        if seconds < 60 { return "约 \(Int(seconds)) 秒" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return "约 \(mins) 分 \(secs) 秒"
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header 栏 - 顶部对齐高度 52pt
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(TTZipTheme.kintsugiGold)
                    Text("正在极速打包...")
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(TTZipTheme.bambooGreen)
                    Text(outputFileName)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(TTZipTheme.bambooGreen)
                        .lineLimit(1)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(TTZipTheme.bambooGreen.opacity(0.12))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 20)
            .frame(height: 52)
            
            // 统一置顶分割线 (金缮金强调线对齐)
            Rectangle()
                .fill(TTZipTheme.kintsugiGold)
                .frame(height: 1.5)
            
            VStack(alignment: .leading, spacing: 20) {
                // 环形与条形百分比进度
                VStack(spacing: 10) {
                    HStack(alignment: .lastTextBaseline) {
                        Text("总体打包进度")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.1f%%", progress.fractionCompleted * 100))
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .contentTransition(.numericText(value: progress.fractionCompleted * 100))
                            .animation(.snappy, value: progress.fractionCompleted)
                            .foregroundStyle(TTZipTheme.bambooGreen)
                    }
                    
                    ProgressView(value: progress.fractionCompleted)
                        .progressViewStyle(.linear)
                        .tint(TTZipTheme.bambooGreen)
                        .scaleEffect(x: 1, y: 1.5, anchor: .center)
                }
                
                // 详细处理指标卡片 (超薄 Material 材质)
                VStack(spacing: 12) {
                    HStack {
                        Label("当前处理文件:", systemImage: "doc.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text(progress.currentFileName.isEmpty ? outputFileName : progress.currentFileName)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .contentTransition(.identity)
                        Spacer()
                    }
                    
                    Divider()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("已处理体积")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Text("\(formattedBytesProcessed) / \(formattedTotalBytes)")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .contentTransition(.numericText())
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text("实时传输速率")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.1f MB/s", progress.throughputMBs))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .contentTransition(.numericText())
                                .foregroundStyle(TTZipTheme.bambooGreen)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("预计剩余时间")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Text(estimatedRemainingSeconds)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(TTZipTheme.kintsugiGold)
                        }
                    }
                }
                .padding(14)
                .background(Color.primary.opacity(0.02))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8)
                )
                
                // 底部控制按钮 (后台运行 vs 取消)
                HStack(spacing: 12) {
                    Button(action: onMinimize) {
                        Text("后台静默运行")
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(Capsule())
                    
                    Button(role: .destructive, action: onCancel) {
                        Text("取消任务")
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .background(TTZipTheme.cinnabarRed.opacity(0.15))
                    .foregroundStyle(TTZipTheme.cinnabarRed)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().strokeBorder(TTZipTheme.cinnabarRed.opacity(0.3), lineWidth: 0.8)
                    )
                    .keyboardShortcut(.escape, modifiers: [])
                }
            }
            .padding(20)
        }
        .frame(width: 520)
        .background(Color.primary.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}
