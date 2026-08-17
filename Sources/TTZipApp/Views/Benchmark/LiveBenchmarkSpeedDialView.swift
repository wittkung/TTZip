import SwiftUI
import TTZipCore

/// 运行中 Live 速度仪表盘与多核调配监控组件
public struct LiveBenchmarkSpeedDialView: View {
    let itemName: String
    let itemIndex: Int
    let totalItems: Int
    let progress: BenchmarkProgress
    let isPaused: Bool
    let onTogglePause: (() -> Void)?
    let onStop: (() -> Void)?
    
    public init(
        itemName: String = "",
        itemIndex: Int = 1,
        totalItems: Int = 4,
        progress: BenchmarkProgress,
        isPaused: Bool = false,
        onTogglePause: (() -> Void)? = nil,
        onStop: (() -> Void)? = nil
    ) {
        self.itemName = itemName
        self.itemIndex = itemIndex
        self.totalItems = totalItems
        self.progress = progress
        self.isPaused = isPaused
        self.onTogglePause = onTogglePause
        self.onStop = onStop
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 当前测试项目提示 Banner + 暂停/停止控制组
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    if isPaused {
                        Image(systemName: "pause.circle.fill")
                            .foregroundStyle(Color.orange)
                    } else {
                        ProgressView()
                            .controlSize(.small)
                            .tint(TTZipTheme.bambooGreen)
                    }
                    
                    Text(isPaused ? "已暂停测试 [\(itemIndex)/\(totalItems)]" : "正在测试项目 [\(itemIndex)/\(totalItems)]")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(isPaused ? Color.orange : TTZipTheme.bambooGreen)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isPaused ? Color.orange.opacity(0.15) : TTZipTheme.bambooGreen.opacity(0.15))
                .clipShape(Capsule())
                
                if !itemName.isEmpty {
                    Text(itemName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                // 暂停 / 继续 & 停止操作按键
                HStack(spacing: 8) {
                    if let toggle = onTogglePause {
                        Button(action: toggle) {
                            HStack(spacing: 4) {
                                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                                    .font(.system(size: 10, weight: .bold))
                                Text(isPaused ? "继续" : "暂停")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(isPaused ? TTZipTheme.bambooGreen : Color.orange.opacity(0.15))
                            .foregroundStyle(isPaused ? Color.white : Color.orange)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if let stop = onStop {
                        Button(action: stop) {
                            HStack(spacing: 4) {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 10, weight: .bold))
                                Text("停止")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.12))
                            .foregroundStyle(Color.red)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text("\(Int(progress.progressPercent * 100))%")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(TTZipTheme.bambooGreen)
                }
            }
            
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 20) {
                    speedGauge
                    speedInfo
                }
                VStack(alignment: .leading, spacing: 14) {
                    speedGauge
                    speedInfo
                }
            }
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(TTZipTheme.bambooGreen.opacity(0.06))
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(TTZipTheme.bambooGreen.opacity(0.3), lineWidth: 1.2)
            }
        )
    }
    
    private var speedGauge: some View {
        ZStack {
            Circle()
                .trim(from: 0.15, to: 0.85)
                .stroke(Color.primary.opacity(0.08), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(90))
                .frame(width: 100, height: 100)
            
            Circle()
                .trim(from: 0.15, to: 0.15 + 0.7 * CGFloat(progress.progressPercent))
                .stroke(
                    LinearGradient(colors: [TTZipTheme.bambooGreen, Color.cyan, Color.purple], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(90))
                .frame(width: 100, height: 100)
                .animation(.spring(response: 0.3), value: progress.progressPercent)
            
            VStack(spacing: 2) {
                Text(String(format: "%.1f", progress.currentThroughputMBs))
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(TTZipTheme.bambooGreen)
                Text("MB/s 实时吞吐")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 100, height: 100)
    }
    
    private var speedInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(progress.statusText)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("已处理流量")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                    Text(formattedSize(progress.bytesProcessed))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                
                Divider().frame(height: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("硬件资源投入")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                    Text("Apple Silicon 全核引擎")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(TTZipTheme.bambooGreen)
                }
            }
            
            ProgressView(value: progress.progressPercent)
                .tint(TTZipTheme.bambooGreen)
        }
    }
    
    private func formattedSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
