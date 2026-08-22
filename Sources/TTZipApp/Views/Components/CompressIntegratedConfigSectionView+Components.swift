// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore

extension CompressIntegratedConfigSectionView {
    @ViewBuilder
    var formatSpecificAdvancedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "gearshape.2.fill").font(.system(size: 11)).foregroundStyle(TTZipTheme.bambooGreen)
                Text("\(selectedFormat.rawValue.uppercased()) Engine Parameters").font(.system(size: 11.5, weight: .bold)).foregroundStyle(.primary)
                Spacer()
                Button(action: onShowMatrix) { Text("Algorithm Matrix...").font(.system(size: 10.5)).foregroundStyle(.secondary) }.buttonStyle(.plain)
            }
            
            switch selectedFormat {
            case .sevenZip:
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Text("Algorithm").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary).frame(width: 75, alignment: .trailing)
                        Picker("", selection: $compressionAlgorithm) {
                            Text("LZMA2 (Default)").tag("LZMA2")
                            Text("LZMA (Legacy)").tag("LZMA")
                            Text("PPMd (Text/Code)").tag("PPMd")
                            Text("BZip2 (Parallel)").tag("BZip2")
                            Text("Copy (Store)").tag("Copy")
                        }.pickerStyle(.menu).controlSize(.small)
                    }
                    HStack(spacing: 12) {
                        Text("Dictionary").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary).frame(width: 75, alignment: .trailing)
                        Picker("", selection: $dictionarySizeMB) {
                            Text("16 MB").tag(16); Text("32 MB (Standard)").tag(32); Text("64 MB").tag(64); Text("128 MB").tag(128); Text("256 MB (Ultra)").tag(256)
                        }.pickerStyle(.segmented).tint(TTZipTheme.bambooGreen)
                    }
                    HStack(spacing: 16) {
                        Toggle("Solid Archive", isOn: $enableSolidArchive).tint(TTZipTheme.bambooGreen)
                        Toggle("Encrypt File Names", isOn: $encryptFileNames).disabled(!enableEncryption).tint(TTZipTheme.bambooGreen)
                    }.font(.system(size: 11))
                }
            case .zip:
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Text("Encryption").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary).frame(width: 75, alignment: .trailing)
                        Picker("", selection: $zipEncryptionMethod) {
                            Text("AES-256 (Recommended)").tag("AES-256")
                            Text("ZipCrypto (Legacy)").tag("ZipCrypto")
                        }.pickerStyle(.segmented).tint(TTZipTheme.bambooGreen)
                    }
                    Toggle("Force UTF-8 File Names", isOn: $zipEncodingUTF8).font(.system(size: 11)).tint(TTZipTheme.bambooGreen)
                }
            case .zst, .tarZst:
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Text("ZSTD Level").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary).frame(width: 75, alignment: .trailing)
                        Picker("", selection: $zstdLevel) {
                            Text("Level 1 (Fast)").tag(1); Text("Level 3 (Default)").tag(3); Text("Level 9 (Balanced)").tag(9); Text("Level 19 (Ultra)").tag(19)
                        }.pickerStyle(.segmented).tint(TTZipTheme.bambooGreen)
                    }
                    Toggle("Enable Long Distance Matching (LDM)", isOn: $zstdEnableLDM).font(.system(size: 11)).tint(TTZipTheme.bambooGreen)
                }
            case .tarGz, .gz, .tarBz2, .tarXz, .tar, .bz2, .xz, .lzip, .lz4, .brotli, .lrzip, .aar, .snappy, .wim, .dmg, .iso:
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Preserve UNIX POSIX File Permissions and Owner (chmod/chown)", isOn: $preservePosixAttributes).font(.system(size: 11)).tint(TTZipTheme.bambooGreen)
                }
            }
        }
        .padding(10).background(TTZipTheme.bambooGreen.opacity(0.04)).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    
    func formatTile(format: ArchiveCompressionFormat) -> some View {
        let isSel = selectedFormat == format
        return Button(action: { selectedFormat = format }) {
            VStack(alignment: .center, spacing: 1) {
                Text(format.displayName).font(.system(size: 10, weight: .bold))
                Text(format.shortcutBadge).font(.system(size: 7.5, weight: .semibold)).foregroundStyle(isSel ? TTZipTheme.bambooGreen : Color.secondary.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4).padding(.vertical, 4)
            .background(isSel ? TTZipTheme.bambooGreen.opacity(0.14) : Color.primary.opacity(0.03))
            .foregroundStyle(isSel ? TTZipTheme.bambooGreen : Color.primary)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(isSel ? TTZipTheme.bambooGreen.opacity(0.5) : Color.clear, lineWidth: 1))
        }.buttonStyle(.plain)
    }
    
    func levelTile(level: ArchiveCompressionLevel, name: String) -> some View {
        let isSel = compressionLevel == level
        return Button(action: { compressionLevel = level }) {
            Text(name).font(.system(size: 10.5, weight: isSel ? .bold : .regular))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(isSel ? TTZipTheme.bambooGreen.opacity(0.14) : Color.primary.opacity(0.03))
                .foregroundStyle(isSel ? TTZipTheme.bambooGreen : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(isSel ? TTZipTheme.bambooGreen.opacity(0.4) : Color.clear, lineWidth: 1))
        }.buttonStyle(.plain)
    }
    
    func volTile(size: Int64?, name: String) -> some View {
        let isSel = (size == -1) ? isCustomVolumeSelected : (!isCustomVolumeSelected && splitVolumeOption == size)
        return Button(action: {
            if size == -1 { isCustomVolumeSelected = true; calcCustomVol() } else { isCustomVolumeSelected = false; splitVolumeOption = size }
        }) {
            Text(name).font(.system(size: 10, weight: isSel ? .bold : .regular))
                .padding(.horizontal, 7).padding(.vertical, 4)
                .background(isSel ? TTZipTheme.bambooGreen.opacity(0.14) : Color.primary.opacity(0.03))
                .foregroundStyle(isSel ? TTZipTheme.bambooGreen : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(isSel ? TTZipTheme.bambooGreen.opacity(0.4) : Color.clear, lineWidth: 1))
        }.buttonStyle(.plain)
    }
    
    func compressionLevelSection(fmt: ArchiveCompressionFormat) -> some View {
        let levelsList = fmt.supportedLevels
        return HStack(spacing: 12) {
            Text("Level").font(.system(size: 11.5, weight: .medium)).foregroundStyle(.secondary).frame(width: 85, alignment: .trailing)
            HStack(spacing: 6) {
                ForEach(levelsList, id: \.rawValue) { lvl in
                    self.levelTileView(fmt: fmt, lvl: lvl)
                }
            }
        }
    }
    
    func levelTileView(fmt: ArchiveCompressionFormat, lvl: ArchiveCompressionLevel) -> some View {
        let ratioPct = Int(round(lvl.compressionRatioPercent(for: fmt)))
        let titleName: String
        if fmt == .zip {
            switch lvl {
            case .store: titleName = "Store (0%)"
            case .level1: titleName = "1: 极速 (6.5 GB/s)"
            case .level2: titleName = "2: 极限 (4.2 GB/s)"
            case .level3: titleName = "3: 深度 (160 MB/s)"
            case .level4: titleName = "4: 图论 (20 MB/s)"
            case .level5: titleName = "5: 超级 (5.5 MB/s)"
            case .level6: titleName = "6: 巅峰 (2.0 MB/s)"
            default: titleName = "Level \(lvl.rawValue)"
            }
        } else {
            switch lvl {
            case .store: titleName = "Store (\(ratioPct)%)"
            case .level1: titleName = "Fast (\(ratioPct)%)"
            case .level6: titleName = "Standard (\(ratioPct)%)"
            case .level9: titleName = "Ultra (\(ratioPct)%)"
            default: titleName = "Level \(lvl.rawValue) (\(ratioPct)%)"
            }
        }
        return levelTile(level: lvl, name: titleName)
    }
    
    func calcCustomVol() {
        guard let val = Int64(customVolumeValueString) else { splitVolumeOption = nil; return }
        let mult: Int64 = (customVolumeUnit == "GB") ? 1024 * 1024 * 1024 : 1024 * 1024
        splitVolumeOption = val * mult
    }
}
