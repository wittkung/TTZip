// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore

public struct SettingsView: View {
    @ObservedObject var l10n = AppLocalizationState.shared
    
    public enum SettingsTab: String, CaseIterable, Identifiable {
        case general
        case localization
        case presets
        case vault
        case license
        
        public var id: String { rawValue }
        
        public var titleKey: any LocaleKeyProtocol {
            switch self {
            case .general: return L10n.Settings.general
            case .localization: return L10n.Settings.localization
            case .presets: return L10n.Presets.title
            case .vault: return L10n.Vault.title
            case .license: return L10n.Settings.licenseStatus
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
    
    @State var selectedTab: SettingsTab = .general
    @State var licenseKeyInput = ""
    @State var activationStatus = ""
    @State var defaultFormat: ArchiveCompressionFormat = .zip
    @State var defaultLevel: ArchiveCompressionLevel = .normal
    @State var isPro = LicenseManager.shared.isPro
    @AppStorage("isSmartStoreBypassEnabled") var isSmartStoreBypassEnabled: Bool = true
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                ForEach(SettingsTab.allCases) { tab in
                    Button(action: { selectedTab = tab }) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.systemImage)
                            Text(l10n.t(tab.titleKey))
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
    
    func activateLicense() {
        if LicenseManager.shared.activate(key: licenseKeyInput) {
            isPro = true
            activationStatus = l10n.t(L10n.Settings.proLicenseActive)
        } else {
            activationStatus = l10n.t(L10n.Settings.invalidKeyError)
        }
    }
}
