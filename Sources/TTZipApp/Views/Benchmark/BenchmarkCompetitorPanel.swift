import SwiftUI
import TTZipCore

public struct BenchmarkCompetitorPanel: View {
    @ObservedObject var viewModel: BenchmarkViewModel
    
    public init(viewModel: BenchmarkViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass.circle.fill")
                        .foregroundStyle(TTZipTheme.kintsugiGold)
                    Text("竞品软件感知与真实验证")
                        .font(.system(size: 12, weight: .bold, design: .serif))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                Button(action: { viewModel.refreshCompetitors() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                        Text("重新检测")
                            .font(.system(size: 10.5, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.detectedCompetitors) { tool in
                        HStack(spacing: 6) {
                            Image(systemName: tool.iconSystemName)
                                .font(.system(size: 11))
                                .foregroundStyle(tool.isInstalled ? TTZipTheme.bambooGreen : Color.secondary.opacity(0.6))
                            Text(tool.name)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(tool.isInstalled ? Color.primary : Color.secondary)
                            
                            Text(tool.isInstalled ? "已检测" : "未安装")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(tool.isInstalled ? TTZipTheme.bambooGreen.opacity(0.15) : Color.primary.opacity(0.06))
                                .foregroundStyle(tool.isInstalled ? TTZipTheme.bambooGreen : Color.secondary)
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.035))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
            
            let hasSevenZip = viewModel.detectedCompetitors.contains(where: { ($0.toolId == "7zip_cli" || $0.toolId == "keka") && $0.isInstalled })
            if !hasSevenZip {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("需要对比 Keka / 7-Zip 真实性能？")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundStyle(TTZipTheme.kintsugiGold)
                        Text("当前未检测到 Keka 或 7-Zip CLI。拒绝假数据，可一键部署 7-Zip (7zz) 工具链以开启真实对比。")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: { viewModel.installSevenZipToolchain() }) {
                        HStack(spacing: 5) {
                            if viewModel.isInstallingToolchain {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "square.and.arrow.down.fill")
                                    .font(.system(size: 11))
                            }
                            Text(viewModel.isInstallingToolchain ? "部署中..." : "一键部署 7-Zip 工具链")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(TTZipTheme.kintsugiGold)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isInstallingToolchain)
                }
                .padding(12)
                .background(TTZipTheme.kintsugiGold.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(TTZipTheme.kintsugiGold.opacity(0.25), lineWidth: 1)
                )
            }
            
            if let msg = viewModel.toolchainStatusMessage {
                Text(msg)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(TTZipTheme.bambooGreen)
                    .padding(.top, 2)
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
