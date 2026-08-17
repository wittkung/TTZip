import SwiftUI
import TTZipCore

public struct SettingsView: View {
    @State private var licenseKeyInput = ""
    @State private var activationStatus = ""
    @State private var isPro = LicenseManager.shared.isPro
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: TTZipTheme.Spacing.lg) {
                
                // 1. License Card
                VStack(alignment: .leading, spacing: TTZipTheme.Spacing.md) {
                    HStack {
                        Label("商业版授权状态", systemImage: "checkmark.seal.fill")
                            .font(TTZipTheme.Typography.sectionHeader)
                            .foregroundStyle(TTZipTheme.bambooGreen)
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(isPro ? TTZipTheme.bambooGreen : TTZipTheme.bambooGreen)
                                .frame(width: 8, height: 8)
                            Text(isPro ? "Pro 商业专业版" : "Free 免费版")
                                .font(TTZipTheme.Typography.caption)
                                .bold()
                                .foregroundStyle(isPro ? TTZipTheme.bambooGreen : TTZipTheme.bambooGreen)
                        }
                        .padding(.horizontal, TTZipTheme.Spacing.xs)
                        .padding(.vertical, 4)
                        .background(TTZipTheme.bambooGreen.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    
                    Rectangle()
                        .fill(TTZipTheme.hairlineBorder)
                        .frame(height: 0.5)
                    
                    if !isPro {
                        VStack(alignment: .leading, spacing: TTZipTheme.Spacing.xs) {
                            Text("输入激活序列号解除全功能与企业商业使用限制：")
                                .font(TTZipTheme.Typography.subheadline)
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: TTZipTheme.Spacing.xs) {
                                TTSecureTextField("例如: AURA-PRO1-KEY8-2026", text: $licenseKeyInput)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.primary.opacity(0.04))
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                
                                Button(action: activateLicense) {
                                    Text("立即激活 Pro 版")
                                        .font(TTZipTheme.Typography.callout)
                                        .foregroundStyle(Color.white)
                                        .padding(.horizontal, TTZipTheme.Spacing.sm)
                                        .padding(.vertical, TTZipTheme.Spacing.xs)
                                }
                                .buttonStyle(.plain)
                                .background(TTZipTheme.bambooGradient)
                                .clipShape(Capsule())
                            }
                        }
                    } else {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("您已拥有全功能无限商业授权")
                                    .font(TTZipTheme.Typography.bodyMedium)
                                Text("感谢支持 TTZip 独立引擎研发，全核心加速与硬件拓扑调优已全面解锁。")
                                    .font(TTZipTheme.Typography.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("注销授权") {
                                LicenseManager.shared.deactivate()
                                isPro = false
                                activationStatus = "授权已注销"
                            }
                            .buttonStyle(.plain)
                            .font(TTZipTheme.Typography.caption)
                            .padding(.horizontal, TTZipTheme.Spacing.sm)
                            .padding(.vertical, TTZipTheme.Spacing.xxs)
                            .background(Color.primary.opacity(0.05))
                            .clipShape(Capsule())
                        }
                    }
                    
                    if !activationStatus.isEmpty {
                        Text(activationStatus)
                            .font(TTZipTheme.Typography.caption)
                            .foregroundStyle(isPro ? TTZipTheme.bambooGreen : TTZipTheme.cinnabarRed)
                    }
                }
                .padding(.vertical, TTZipTheme.Spacing.xs)
                
                // 2. Hardware Topology Card
                VStack(alignment: .leading, spacing: TTZipTheme.Spacing.md) {
                    HStack {
                        Label("Apple Silicon 硬件加速拓扑", systemImage: "cpu.fill")
                            .font(TTZipTheme.Typography.sectionHeader)
                            .foregroundStyle(TTZipTheme.bambooGreen)
                        Spacer()
                        Text("动态感知引擎")
                            .font(TTZipTheme.Typography.caption)
                            .bold()
                            .foregroundStyle(TTZipTheme.bambooGreen)
                    }
                    
                    Rectangle()
                        .fill(TTZipTheme.hairlineBorder)
                        .frame(height: 0.5)
                    
                    let tuner = AppleSiliconTuner.shared
                    Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                        GridRow {
                            Text("芯片型号:")
                                .font(TTZipTheme.Typography.subheadline)
                                .foregroundStyle(.secondary)
                            Text(tuner.topology.chipName)
                                .font(TTZipTheme.Typography.bodyMedium)
                        }
                        
                        GridRow {
                            Text("核心构架:")
                                .font(TTZipTheme.Typography.subheadline)
                                .foregroundStyle(.secondary)
                            Text("\(tuner.topology.totalCores) Cores (\(tuner.topology.performanceCores) Performance + \(tuner.topology.efficiencyCores) Efficiency)")
                                .font(TTZipTheme.Typography.body)
                        }
                        
                        GridRow {
                            Text("统一内存:")
                                .font(TTZipTheme.Typography.subheadline)
                                .foregroundStyle(.secondary)
                            Text("\(String(format: "%.1f", tuner.topology.unifiedMemoryGB)) GB Unified Memory")
                                .font(TTZipTheme.Typography.body)
                        }
                        
                        GridRow {
                            Text("硬件拓扑概要:")
                                .font(TTZipTheme.Typography.subheadline)
                                .foregroundStyle(.secondary)
                            Text(tuner.hardwareSummary)
                                .font(TTZipTheme.Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, TTZipTheme.Spacing.xs)

                // 3. Smart Store Bypass Card
                VStack(alignment: .leading, spacing: TTZipTheme.Spacing.md) {
                    HStack {
                        Label("智能高熵直通与存储旁路 (Smart Store Bypass)", systemImage: "bolt.badge.automatic.fill")
                            .font(TTZipTheme.Typography.sectionHeader)
                            .foregroundStyle(TTZipTheme.bambooGreen)
                        Spacer()
                    }
                    
                    Rectangle()
                        .fill(TTZipTheme.hairlineBorder)
                        .frame(height: 0.5)
                    
                    VStack(alignment: .leading, spacing: TTZipTheme.Spacing.sm) {
                        Toggle(isOn: Binding(
                            get: { ArchiveEntropyEvaluator.isSmartStoreBypassEnabled },
                            set: { ArchiveEntropyEvaluator.isSmartStoreBypassEnabled = $0 }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("自动跳过物理不可压缩极高熵数据 (实测 Shannon 熵 > 7.90)")
                                    .font(TTZipTheme.Typography.bodyMedium)
                                Text("基于实测字节熵动态评估（而非仅按文件后缀名）。高码率未压缩视频、RAW母带或渲染帧序列等具备压缩空间的数据将正常执行深度压缩；仅当实测达到物理极值（Shannon 熵 > 7.90，如密文/随机数/无冗余预压缩块）时，才触发极速 Store 直通旁路，压缩吞吐提升高达 20x~35x。")
                                    .font(TTZipTheme.Typography.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                    }
                }
                .padding(.vertical, TTZipTheme.Spacing.xs)
            }
            .padding(.top, 38)
            .padding(.horizontal, TTZipTheme.Spacing.xl)
            .padding(.bottom, TTZipTheme.Spacing.xl)
        }
    }
}
    
    private func activateLicense() {
        if LicenseManager.shared.activate(key: licenseKeyInput) {
            isPro = true
            activationStatus = "已成功激活 TTZip Pro 商业版"
        } else {
            activationStatus = "激活码无效，请核对输入格式"
        }
    }
}
