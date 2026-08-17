import SwiftUI
import TTZipCore

public struct BenchmarkConfigSectionView: View {
    @ObservedObject var viewModel: BenchmarkViewModel
    
    public init(viewModel: BenchmarkViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 顶部模式 Pills
            HStack(spacing: 12) {
                Text("测试模式")
                    .font(.system(size: 12, weight: .bold, design: .serif))
                    .foregroundStyle(TTZipTheme.bambooGreen)
                
                HStack(spacing: 4) {
                    ForEach(BenchmarkMode.allCases) { mode in
                        Button(action: { viewModel.testMode = mode }) {
                            HStack(spacing: 6) {
                                Image(systemName: mode == .synthetic ? "sparkles" : (mode == .frontend ? "display" : "folder.fill"))
                                    .font(.system(size: 11, weight: .bold))
                                Text(mode.rawValue)
                                    .font(.system(size: 11.5, weight: viewModel.testMode == mode ? .bold : .medium))
                            }
                            .foregroundStyle(viewModel.testMode == mode ? TTZipTheme.bambooGreen : Color.primary.opacity(0.7))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(viewModel.testMode == mode ? TTZipTheme.bambooGreen.opacity(0.15) : Color.clear)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(Color.primary.opacity(0.04))
                .clipShape(Capsule())
            }
            
            Divider()
                .opacity(0.6)
            
            switch viewModel.testMode {
            case .synthetic:
                syntheticConfigView
            case .customFile:
                customFileConfigView
            case .frontend:
                frontendConfigView
            }
        }
        .padding(18)
        .background(Color.primary.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
    
    private var syntheticConfigView: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("数据规模")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(BenchmarkDataSize.allCases) { sz in
                            Button(action: { viewModel.selectedSize = sz }) {
                                Text(sz.rawValue)
                                    .font(.system(size: 11, weight: viewModel.selectedSize == sz ? .bold : .medium))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(viewModel.selectedSize == sz ? TTZipTheme.bambooGreen.opacity(0.18) : Color.primary.opacity(0.035))
                                    .foregroundStyle(viewModel.selectedSize == sz ? TTZipTheme.bambooGreen : Color.primary)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule().strokeBorder(viewModel.selectedSize == sz ? TTZipTheme.bambooGreen.opacity(0.4) : Color.clear, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("压缩率预设")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ArchiveCompressionLevel.allCases) { lvl in
                            Button(action: { viewModel.selectedLevel = lvl }) {
                                Text(lvl.title)
                                    .font(.system(size: 11, weight: viewModel.selectedLevel == lvl ? .bold : .medium))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(viewModel.selectedLevel == lvl ? TTZipTheme.bambooGreen.opacity(0.18) : Color.primary.opacity(0.035))
                                    .foregroundStyle(viewModel.selectedLevel == lvl ? TTZipTheme.bambooGreen : Color.primary)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule().strokeBorder(viewModel.selectedLevel == lvl ? TTZipTheme.bambooGreen.opacity(0.4) : Color.clear, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                    Text("说明：\(viewModel.selectedLevel.detailDescription)")
                        .font(.system(size: 10.5))
                }
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            }
        }
    }
    
    private var customFileConfigView: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("自选跑分样本")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                
                if let path = viewModel.customPath {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(TTZipTheme.bambooGreen.opacity(0.15))
                                .frame(width: 38, height: 38)
                            Image(systemName: viewModel.customPathIsDirectory ? "folder.fill" : "doc.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(TTZipTheme.bambooGreen)
                        }
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text((path as NSString).lastPathComponent)
                                .font(.system(size: 13, weight: .bold))
                                .lineLimit(1)
                            Text("\(formattedSize(viewModel.customPathSizeBytes)) · \(path)")
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Button("更换样本...") {
                            viewModel.pickCustomPath()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(12)
                    .background(Color.primary.opacity(0.035))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    Button(action: { viewModel.pickCustomPath() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("点击选择本地文件或文件夹进行性能测试...")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(TTZipTheme.bambooGreen)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(TTZipTheme.bambooGreen.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(TTZipTheme.bambooGreen.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4]))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var frontendConfigView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "gauge.with.dots.needle.bottom.100percent")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(TTZipTheme.kintsugiGold)
                Text("前端算法与 UI 渲染性能基准")
                    .font(.system(size: 13, weight: .bold))
            }
            Text("覆盖超大目录树构建、20,000 条目实时搜索防抖过滤、有界 LRU 缓存命中以及 60Hz 进度事件门控节流。")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
            
            if let report = viewModel.frontendReport {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("全项通过状态:")
                            .font(.system(size: 11, weight: .bold))
                        Text(report.isAllPassed ? "🟢 全部达标 (Passed)" : "🔴 未达标")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(report.isAllPassed ? TTZipTheme.bambooGreen : .red)
                    }
                    if let lastTree = report.treeBuildMetrics.last {
                        Text("• 50k 条目树构建: \(String(format: "%.1f", lastTree.durationMs)) ms (\(String(format: "%.0f", lastTree.throughputItemsPerSec)) items/s)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    if let firstSearch = report.searchFilterMetrics.first {
                        Text("• 20k 条目搜索过滤: \(String(format: "%.1f", firstSearch.durationMs)) ms (\(String(format: "%.0f", firstSearch.filterThroughputItemsPerSec)) items/s)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    if let throttle = report.throttleMetrics.first {
                        Text("• 进度事件节流拦截率: \(String(format: "%.1f", throttle.suppressionRatio))%")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background(Color.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
    
    private func formattedSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
