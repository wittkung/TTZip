// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore

public struct SettingsView: View {
    @ObservedObject private var l10n = AppLocalizationState.shared
    
    public enum SettingsTab: String, CaseIterable, Identifiable {
        case general
        case localization
        case presets
        case vault
        case license
        
        public var id: String { rawValue }
        
        public func displayName(isZh: Bool) -> String {
            switch self {
            case .general: return isZh ? "通用" : "General"
            case .localization: return isZh ? "语言与单位" : "Localization"
            case .presets: return isZh ? "默认预设" : "Presets"
            case .vault: return isZh ? "密码保险箱" : "Vault"
            case .license: return isZh ? "授权与硬件" : "Hardware & Pro"
            }
        }
        
        public var systemImage: String {
            switch self {
            case .general: return "gearshape"
            case .localization: return "globe"
            case .presets: return "slider.horizontal.3"
            case .vault: return "lock.shield"
            case .license: return "cpu"
            }
        }
    }
    
    @State private var selectedTab: SettingsTab = .general
    @State private var licenseKeyInput = ""
    @State private var activationStatus = ""
    @State private var isPro = LicenseManager.shared.isPro
    @State private var defaultFormat: ArchiveCompressionFormat = .zip
    @State private var defaultLevel: ArchiveCompressionLevel = .normal
    
    public init() {}
    
    private var isZh: Bool {
        l10n.currentLanguage == .zhHans || l10n.currentLanguage == .zhHant
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top Tab Switcher
            HStack(spacing: 4) {
                ForEach(SettingsTab.allCases) { tab in
                    Button(action: { selectedTab = tab }) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.systemImage)
                            Text(tab.displayName(isZh: isZh))
                        }
                        .font(TTZipTheme.Typography.caption)
                        .bold()
                        .padding(.horizontal, TTZipTheme.Spacing.sm)
                        .padding(.vertical, 6)
                        .background(selectedTab == tab ? Color.primary.opacity(0.12) : Color.clear)
                        .foregroundStyle(selectedTab == tab ? Color.primary : Color.secondary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, TTZipTheme.Spacing.xl)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: TTZipTheme.Spacing.lg) {
                    switch selectedTab {
                    case .general:
                        generalSection
                    case .localization:
                        localizationSection
                    case .presets:
                        presetsSection
                    case .vault:
                        vaultSection
                    case .license:
                        licenseAndHardwareSection
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, TTZipTheme.Spacing.xl)
                .padding(.bottom, TTZipTheme.Spacing.xl)
            }
        }
    }
    
    // MARK: - 1. General Section
    
    @ViewBuilder
    private var generalSection: some View {
        VStack(alignment: .leading, spacing: TTZipTheme.Spacing.md) {
            Label(isZh ? "智能高熵直通与存储旁路 (Smart Store Bypass)" : "Smart Store Bypass", systemImage: "bolt.badge.automatic.fill")
                .font(TTZipTheme.Typography.sectionHeader)
                .foregroundStyle(TTZipTheme.bambooGreen)
            
            Rectangle()
                .fill(TTZipTheme.hairlineBorder)
                .frame(height: 0.5)
            
            Toggle(isOn: Binding(
                get: { ArchiveEntropyEvaluator.isSmartStoreBypassEnabled },
                set: { ArchiveEntropyEvaluator.isSmartStoreBypassEnabled = $0 }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isZh ? "自动跳过物理不可压缩极高熵数据 (实测 Shannon 熵 > 7.90)" : "Bypass incompressible high-entropy data (Shannon entropy > 7.90)")
                        .font(TTZipTheme.Typography.bodyMedium)
                    Text(isZh ? "基于实测字节熵动态评估。仅当实测达到物理极值（密文/随机数/无冗余预压缩块）时触发 Store 直通旁路，压缩吞吐提升高达 20x~35x。" : "Dynamically detects already-compressed and encrypted blocks to avoid wasting CPU cycles.")
                        .font(TTZipTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
        }
    }
    
    // MARK: - 2. Localization Section
    
    @ViewBuilder
    private var localizationSection: some View {
        VStack(alignment: .leading, spacing: TTZipTheme.Spacing.md) {
            Label(isZh ? "界面语言与度量单位" : "Language & Measurement Units", systemImage: "globe")
                .font(TTZipTheme.Typography.sectionHeader)
                .foregroundStyle(TTZipTheme.bambooGreen)
            
            Rectangle()
                .fill(TTZipTheme.hairlineBorder)
                .frame(height: 0.5)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(isZh ? "应用界面语言:" : "App Language:")
                        .font(TTZipTheme.Typography.bodyMedium)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { l10n.currentLanguage },
                        set: { l10n.setLanguage($0) }
                    )) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .frame(width: 160)
                }
                
                Text(isZh ? "切换语言将即时生效，无需重启应用。" : "Language switch applies immediately without restarting TTZip.")
                    .font(TTZipTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - 3. Presets Section
    
    @ViewBuilder
    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: TTZipTheme.Spacing.md) {
            Label(isZh ? "默认新建归档预设" : "Default Archive Presets", systemImage: "slider.horizontal.3")
                .font(TTZipTheme.Typography.sectionHeader)
                .foregroundStyle(TTZipTheme.bambooGreen)
            
            Rectangle()
                .fill(TTZipTheme.hairlineBorder)
                .frame(height: 0.5)
            
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                GridRow {
                    Text(isZh ? "默认格式:" : "Default Format:")
                        .font(TTZipTheme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $defaultFormat) {
                        Text("ZIP (PKWARE)").tag(ArchiveCompressionFormat.zip)
                        Text("7Z (LZMA2)").tag(ArchiveCompressionFormat.sevenZip)
                        Text("TAR.ZST (Direct)").tag(ArchiveCompressionFormat.tarZst)
                    }
                    .frame(width: 180)
                }
                
                GridRow {
                    Text(isZh ? "压缩级别:" : "Compression Level:")
                        .font(TTZipTheme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $defaultLevel) {
                        Text(isZh ? "极速压缩 (Fast)" : "Fast").tag(ArchiveCompressionLevel.fast)
                        Text(isZh ? "标准均衡 (Normal)" : "Normal").tag(ArchiveCompressionLevel.normal)
                        Text(isZh ? "极限压缩 (Maximum)" : "Maximum").tag(ArchiveCompressionLevel.maximum)
                    }
                    .frame(width: 180)
                }
            }
        }
    }
    
    // MARK: - 4. Vault Section
    
    @ViewBuilder
    private var vaultSection: some View {
        VStack(alignment: .leading, spacing: TTZipTheme.Spacing.md) {
            Label(isZh ? "密码保险箱 v4 安全策略" : "Password Vault v4 Security", systemImage: "lock.shield.fill")
                .font(TTZipTheme.Typography.sectionHeader)
                .foregroundStyle(TTZipTheme.bambooGreen)
            
            Rectangle()
                .fill(TTZipTheme.hairlineBorder)
                .frame(height: 0.5)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(isZh ? "• 密钥派生: PBKDF2-SHA256 (600,000 轮 OWASP 强化迭代)" : "• Key Derivation: PBKDF2-SHA256 (600,000 OWASP iterations)")
                    .font(TTZipTheme.Typography.caption)
                Text(isZh ? "• 物理安全: 密码内存释放使用 volatile 指针强制清零 (Dead-Store 免疫)" : "• Memory Security: Volatile zeroing prevents dead-store elimination")
                    .font(TTZipTheme.Typography.caption)
                Text(isZh ? "• 存储加密: AES-256-GCM 硬件加密存储" : "• Vault Storage: AES-256-GCM hardware encryption")
                    .font(TTZipTheme.Typography.caption)
            }
            .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - 5. License & Hardware Section
    
    @ViewBuilder
    private var licenseAndHardwareSection: some View {
        VStack(alignment: .leading, spacing: TTZipTheme.Spacing.md) {
            HStack {
                Label(isZh ? "商业版授权状态" : "Commercial License Status", systemImage: "checkmark.seal.fill")
                    .font(TTZipTheme.Typography.sectionHeader)
                    .foregroundStyle(TTZipTheme.bambooGreen)
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(TTZipTheme.bambooGreen)
                        .frame(width: 8, height: 8)
                    Text(isPro ? (isZh ? "Pro 商业专业版" : "Pro License") : (isZh ? "Free 免费版" : "Free Edition"))
                        .font(TTZipTheme.Typography.caption)
                        .bold()
                        .foregroundStyle(TTZipTheme.bambooGreen)
                }
                .padding(.horizontal, TTZipTheme.Spacing.xs)
                .padding(.vertical, 4)
                .background(TTZipTheme.bambooGreen.opacity(0.12))
                .clipShape(Capsule())
            }
            
            Rectangle()
                .fill(TTZipTheme.hairlineBorder)
                .frame(height: 0.5)
            
            #if MAS_BUILD
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isZh ? "Mac App Store 正版授权 (全功能已解锁)" : "Mac App Store Full License (Active)")
                        .font(TTZipTheme.Typography.bodyMedium)
                    Text(isZh ? "已通过 Mac App Store 购买激活，所有 16 种格式与 Apple Silicon 硬件加速已全部解锁。" : "Purchased from Mac App Store. All vector pipelines and 16 formats unlocked.")
                        .font(TTZipTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(TTZipTheme.bambooGreen)
            }
            #else
            if !isPro {
                VStack(alignment: .leading, spacing: TTZipTheme.Spacing.xs) {
                    Text(isZh ? "输入激活序列号解除全功能与企业商业使用限制：" : "Enter activation license key:")
                        .font(TTZipTheme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: TTZipTheme.Spacing.xs) {
                        TTSecureTextField(isZh ? "例如: AURA-PRO1-KEY8-2026" : "e.g. AURA-PRO1-KEY8-2026", text: $licenseKeyInput)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        
                        Button(action: activateLicense) {
                            Text(isZh ? "立即激活 Pro 版" : "Activate Pro")
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
                        Text(isZh ? "您已拥有全功能无限商业授权" : "Commercial License Active")
                            .font(TTZipTheme.Typography.bodyMedium)
                        Text(isZh ? "感谢支持 TTZip 独立研发，硬件拓扑调优已全面解锁。" : "All hardware vector pipelines unlocked.")
                            .font(TTZipTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(isZh ? "注销授权" : "Deactivate") {
                        LicenseManager.shared.deactivate()
                        isPro = false
                        activationStatus = isZh ? "授权已注销" : "Deactivated"
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
            #endif
            
            Spacer().frame(height: 12)
            
            Label(isZh ? "Apple Silicon 硬件加速拓扑" : "Apple Silicon Hardware Topology", systemImage: "cpu.fill")
                .font(TTZipTheme.Typography.sectionHeader)
                .foregroundStyle(TTZipTheme.bambooGreen)
            
            Rectangle()
                .fill(TTZipTheme.hairlineBorder)
                .frame(height: 0.5)
            
            let tuner = AppleSiliconTuner.shared
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 10) {
                GridRow {
                    Text(isZh ? "芯片型号:" : "Chip Model:")
                        .font(TTZipTheme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                    Text(tuner.topology.chipName)
                        .font(TTZipTheme.Typography.bodyMedium)
                }
                
                GridRow {
                    Text(isZh ? "核心构架:" : "Cores:")
                        .font(TTZipTheme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(tuner.topology.totalCores) Cores (\(tuner.topology.performanceCores)P + \(tuner.topology.efficiencyCores)E)")
                        .font(TTZipTheme.Typography.body)
                }
                
                GridRow {
                    Text(isZh ? "统一内存:" : "Unified Memory:")
                        .font(TTZipTheme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(String(format: "%.1f", tuner.topology.unifiedMemoryGB)) GB Unified Memory")
                        .font(TTZipTheme.Typography.body)
                }
            }
        }
    }
    
    private func activateLicense() {
        if LicenseManager.shared.activate(key: licenseKeyInput) {
            isPro = true
            activationStatus = isZh ? "已成功激活 TTZip Pro 商业版" : "Activated TTZip Pro successfully"
        } else {
            activationStatus = isZh ? "激活码无效，请核对输入格式" : "Invalid license key format"
        }
    }
}
