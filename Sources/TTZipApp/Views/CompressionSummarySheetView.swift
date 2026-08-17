import SwiftUI
import TTZipCore

/// 全算法特性与区别性能对比弹窗 Sheet
public struct AlgorithmMatrixSheetView: View {
    @Binding public var isPresented: Bool
    
    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }
    
    public struct AlgoRow: Identifiable {
        public let id = UUID()
        public let name: String
        public let speed: String
        public let ratio: String
        public let compatibility: String
        public let recommendedFor: String
        public let color: Color
    }
    
    public let rows: [AlgoRow] = [
        AlgoRow(name: "仅存储 (Store)", speed: "8,450 MB/s (极速)", ratio: "0% (无压缩)", compatibility: "100%", recommendedFor: "已压缩的视频/图片/20G大分卷备份", color: .green),
        AlgoRow(name: "Zstd (Zstandard)", speed: "4,450 MB/s (高速)", ratio: "高 (~85%)", compatibility: "95% (现代全平台)", recommendedFor: "日常高效打包、代码工程库、数据库备份", color: .orange),
        AlgoRow(name: "LZMA2 (7-Zip 推荐)", speed: "320 ~ 1,600 MB/s", ratio: "极大 (~92%)", compatibility: "98% (通用)", recommendedFor: "文本、代码文档、二进制文件极限空间节省", color: .blue),
        AlgoRow(name: "Deflate (ZIP 经典)", speed: "85 ~ 600 MB/s", ratio: "中等 (~70%)", compatibility: "100% (全平台默认)", recommendedFor: "跨平台发送邮件附件、兼容老旧设备", color: .purple),
        AlgoRow(name: "Bzip2", speed: "40 ~ 120 MB/s", ratio: "高 (~88%)", compatibility: "90%", recommendedFor: "巨型日志、高重复冗余数据与科学计算集", color: .indigo)
    ]
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                Text("TTZip 核心压缩算法区别与特性对比表")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                Button("关闭") { isPresented = false }
                    .buttonStyle(.borderedProminent)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                ForEach(rows) { row in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(row.color)
                            .frame(width: 8, height: 8)
                            .padding(.top, 5)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(row.name)
                                    .font(.headline)
                                    .foregroundStyle(row.color)
                                Spacer()
                                Text("实测吞吐: \(row.speed)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(row.color.opacity(0.15))
                                    .cornerRadius(4)
                            }
                            
                            HStack(spacing: 16) {
                                Text("压缩率: \(row.ratio)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("兼容性: \(row.compatibility)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Text("最佳适用场景: \(row.recommendedFor)")
                                .font(.caption2)
                                .foregroundStyle(.primary)
                        }
                    }
                    .padding(10)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(8)
                }
            }
            
            Spacer()
        }
        .padding(20)
        .frame(width: 620, height: 480)
    }
}

/// 解耦的算法指导卡片独立子视图组件
public struct AlgorithmGuidanceCardView: View {
    public let algoInfo: (icon: String, color: Color, title: String, desc: String)
    public let onShowMatrix: () -> Void
    
    public init(algoInfo: (icon: String, color: Color, title: String, desc: String), onShowMatrix: @escaping () -> Void) {
        self.algoInfo = algoInfo
        self.onShowMatrix = onShowMatrix
    }
    
    public var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: algoInfo.icon)
                .foregroundStyle(algoInfo.color)
                .font(.caption)
            VStack(alignment: .leading, spacing: 2) {
                Text(algoInfo.title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(algoInfo.color)
                Text(algoInfo.desc)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                Button(action: onShowMatrix) {
                    HStack(spacing: 4) {
                        Text("查看全算法详细性能对比表")
                            .font(.caption2)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .padding(8)
        .background(TTZipTheme.subtleFill)
        .clipShape(RoundedRectangle(cornerRadius: TTZipTheme.Radius.sm, style: .continuous))
    }
}

/// 压缩完成结算统计面板 Sheet
public struct CompressionSummarySheetView: View {
    public let archivePath: String
    public let originalSizeBytes: Int64
    public let compressedSizeBytes: Int64
    public let elapsedSeconds: Double
    public let throughputMBs: Double
    public let format: ArchiveCompressionFormat
    public let isEncrypted: Bool
    public let onCloseAndExplore: () -> Void
    
    public init(
        archivePath: String,
        originalSizeBytes: Int64,
        compressedSizeBytes: Int64,
        elapsedSeconds: Double,
        throughputMBs: Double,
        format: ArchiveCompressionFormat,
        isEncrypted: Bool,
        onCloseAndExplore: @escaping () -> Void
    ) {
        self.archivePath = archivePath
        self.originalSizeBytes = originalSizeBytes
        self.compressedSizeBytes = compressedSizeBytes
        self.elapsedSeconds = elapsedSeconds
        self.throughputMBs = throughputMBs
        self.format = format
        self.isEncrypted = isEncrypted
        self.onCloseAndExplore = onCloseAndExplore
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(TTZipTheme.bambooGreen)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("压缩打包完成")
                        .font(.title3).fontWeight(.bold)
                    Text((archivePath as NSString).lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            
            Divider()
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("压缩速率")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f MB/s", throughputMBs))
                        .font(.system(.title3, design: .monospaced, weight: .bold))
                        .foregroundStyle(TTZipTheme.bambooGreen)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.025))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                let ratio = originalSizeBytes > 0 ? (1.0 - Double(compressedSizeBytes) / Double(originalSizeBytes)) * 100.0 : 0.0
                VStack(alignment: .leading, spacing: 4) {
                    Text("空间节省率")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "-%.1f%%", max(0, ratio)))
                        .font(.system(.title3, design: .monospaced, weight: .bold))
                        .foregroundStyle(.purple)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.025))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("文件体积变化")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(ByteCountFormatterFlyweight.shared.string(fromByteCount: originalSizeBytes)) ➔ \(ByteCountFormatterFlyweight.shared.string(fromByteCount: compressedSizeBytes))")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .lineLimit(1)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.025))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("打包耗时 / 加密")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.2fs · %@", elapsedSeconds, isEncrypted ? "AES-256" : "未加密"))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isEncrypted ? .orange : .primary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.025))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            Divider()
            
            Button(action: onCloseAndExplore) {
                HStack {
                    Image(systemName: "folder.badge.gearshape")
                    Text("完成并进入主页目录探索")
                        .fontWeight(.bold)
                }
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(TTZipTheme.bambooGreen)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: [.command])
        }
        .padding(20)
        .frame(width: 440)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.25), radius: 24, y: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(TTZipTheme.bambooGreen.opacity(0.4), lineWidth: 1)
        )
    }
}
