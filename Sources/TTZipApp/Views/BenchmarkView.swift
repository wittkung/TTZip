import SwiftUI
import TTZipCore

/// 性能测试 Command Center - 旗舰高透社论美学 UI
public struct BenchmarkView: View {
    @StateObject private var viewModel = BenchmarkViewModel()
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header 栏 - 顶部对齐高度 52pt
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("BENCHMARK MATRIX")
                        .font(.system(size: 9, weight: .bold, design: .serif))
                        .tracking(2)
                        .foregroundStyle(TTZipTheme.kintsugiGold)
                    Text("性能测试与算法比对")
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                Button(action: { viewModel.startAllPresetsSuite() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text(viewModel.isRunning ? "压测中..." : "开始全套压测 (⌘R)")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [TTZipTheme.bambooGreen, TTZipTheme.bambooGreen.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: TTZipTheme.bambooGreen.opacity(0.25), radius: 4, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(viewModel.isRunning || (viewModel.testMode == .customFile && viewModel.customPath == nil))
            }
            .padding(.horizontal, 20)
            .frame(height: 52)
            
            // 统一置顶分割线 (金缮金强调线对齐)
            Rectangle()
                .fill(TTZipTheme.kintsugiGold)
                .frame(height: 1.5)
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    // 1. 顶部 Apple Silicon 硬件感知 Banner
                    BenchmarkHardwareBannerView()
                    
                    // 2. 竞品软件检测与工具链管理面板
                    BenchmarkCompetitorPanel(viewModel: viewModel)
                    
                    // 3. 双模式配置面板
                    BenchmarkConfigSectionView(viewModel: viewModel)
                    
                    if let err = viewModel.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(TTZipTheme.cinnabarRed)
                            Text(err)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(TTZipTheme.cinnabarRed)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(TTZipTheme.cinnabarRed.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    
                    // 4. 运行中实时跑分指示器
                    if viewModel.isRunning {
                        LiveBenchmarkSpeedDialView(
                            itemName: viewModel.currentPresetName,
                            itemIndex: viewModel.currentSuiteIndex,
                            totalItems: viewModel.totalSuiteCount,
                            progress: viewModel.currentProgress,
                            isPaused: viewModel.isPaused,
                            onTogglePause: { viewModel.togglePause() },
                            onStop: { viewModel.stopSuite() }
                        )
                    }
                    
                    // 5. 跑分可视化画布
                    if !viewModel.suiteResults.isEmpty {
                        resultsCanvas
                    }
                }
                .padding(20)
            }
        }
        .background(Color.primary.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        )
        .padding(.top, 38)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .frame(minWidth: 320, minHeight: 300)
        .alert("授权安装 Homebrew 包管理器", isPresented: $viewModel.showHomebrewConsentModal) {
            Button("同意并安装 Homebrew 及 7-Zip 工具链") {
                viewModel.installSevenZipToolchain(consentedHomebrew: true)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("检测到当前系统尚未安装 Homebrew。自动化部署 7-Zip (7zz) 高性能 CLI 工具链依赖 Homebrew。\n\n是否同意自动为您安装 Homebrew 包管理器及 7-Zip 工具链？")
        }
    }
    
    // MARK: - 跑分结果画布
    
    private var resultsCanvas: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(TTZipTheme.bambooGreen)
                    Text("测试结果与算法对比")
                        .font(.system(size: 14, weight: .bold, design: .serif))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                if viewModel.testMode == .synthetic {
                    Text("合成数据 · \(viewModel.selectedSize.rawValue)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                } else if let path = viewModel.customPath {
                    Text("样本: \((path as NSString).lastPathComponent)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(TTZipTheme.bambooGreen)
                }
            }
            
            let maxThroughput = max(100.0, viewModel.suiteResults.map { max($0.throughputMBs, $0.decompressionThroughputMBs) }.max() ?? 100.0)
            
            VStack(spacing: 12) {
                ForEach(viewModel.suiteResults.indices, id: \.self) { idx in
                    BenchmarkResultRowView(result: viewModel.suiteResults[idx], maxThroughput: maxThroughput)
                }
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
}
