// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore

/// Integrated compression configuration and engine parameters view.
public struct CompressIntegratedConfigSectionView: View {
    @Binding public var outputName: String
    @Binding public var targetDirectory: String
    @Binding public var selectedFormat: ArchiveCompressionFormat
    @Binding public var compressionLevel: ArchiveCompressionLevel
    
    // Dynamic format options
    @Binding public var compressionAlgorithm: String
    @Binding public var dictionarySizeMB: Int
    @Binding public var zipEncryptionMethod: String
    @Binding public var zipEncodingUTF8: Bool
    @Binding public var zstdLevel: Int
    @Binding public var zstdEnableLDM: Bool
    @Binding public var preservePosixAttributes: Bool
    
    // Global parameters
    @Binding public var cpuThreadsOption: String
    @Binding public var splitVolumeOption: Int64?
    @Binding public var isCustomVolumeSelected: Bool
    @Binding public var customVolumeValueString: String
    @Binding public var customVolumeUnit: String
    @Binding public var enableEncryption: Bool
    @Binding public var password: String
    @Binding public var enableSolidArchive: Bool
    @Binding public var encryptFileNames: Bool
    @Binding public var skipMacJunk: Bool
    @Binding public var createSeparateArchives: Bool
    @Binding public var deleteSourceAfterCompress: Bool
    @Binding public var openFinderAfterCompress: Bool
    
    public let cachedTotalCores: Int
    public let onPickDirectory: () -> Void
    public let onOpenPasswordVault: () -> Void
    public let onShowMatrix: () -> Void
    
    public init(
        outputName: Binding<String>, targetDirectory: Binding<String>,
        selectedFormat: Binding<ArchiveCompressionFormat>, compressionLevel: Binding<ArchiveCompressionLevel>,
        compressionAlgorithm: Binding<String>, dictionarySizeMB: Binding<Int>,
        zipEncryptionMethod: Binding<String>, zipEncodingUTF8: Binding<Bool>,
        zstdLevel: Binding<Int>, zstdEnableLDM: Binding<Bool>, preservePosixAttributes: Binding<Bool>,
        cpuThreadsOption: Binding<String>, splitVolumeOption: Binding<Int64?>,
        isCustomVolumeSelected: Binding<Bool>, customVolumeValueString: Binding<String>, customVolumeUnit: Binding<String>,
        enableEncryption: Binding<Bool>, password: Binding<String>,
        enableSolidArchive: Binding<Bool>, encryptFileNames: Binding<Bool>,
        skipMacJunk: Binding<Bool>, createSeparateArchives: Binding<Bool>,
        deleteSourceAfterCompress: Binding<Bool>, openFinderAfterCompress: Binding<Bool>,
        cachedTotalCores: Int, onPickDirectory: @escaping () -> Void,
        onOpenPasswordVault: @escaping () -> Void, onShowMatrix: @escaping () -> Void
    ) {
        self._outputName = outputName
        self._targetDirectory = targetDirectory
        self._selectedFormat = selectedFormat
        self._compressionLevel = compressionLevel
        self._compressionAlgorithm = compressionAlgorithm
        self._dictionarySizeMB = dictionarySizeMB
        self._zipEncryptionMethod = zipEncryptionMethod
        self._zipEncodingUTF8 = zipEncodingUTF8
        self._zstdLevel = zstdLevel
        self._zstdEnableLDM = zstdEnableLDM
        self._preservePosixAttributes = preservePosixAttributes
        self._cpuThreadsOption = cpuThreadsOption
        self._splitVolumeOption = splitVolumeOption
        self._isCustomVolumeSelected = isCustomVolumeSelected
        self._customVolumeValueString = customVolumeValueString
        self._customVolumeUnit = customVolumeUnit
        self._enableEncryption = enableEncryption
        self._password = password
        self._enableSolidArchive = enableSolidArchive
        self._encryptFileNames = encryptFileNames
        self._skipMacJunk = skipMacJunk
        self._createSeparateArchives = createSeparateArchives
        self._deleteSourceAfterCompress = deleteSourceAfterCompress
        self._openFinderAfterCompress = openFinderAfterCompress
        self.cachedTotalCores = cachedTotalCores
        self.onPickDirectory = onPickDirectory
        self.onOpenPasswordVault = onOpenPasswordVault
        self.onShowMatrix = onShowMatrix
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Target & Engine Parameters", systemImage: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .bold, design: .serif))
                    .foregroundStyle(TTZipTheme.bambooGreen)
                Spacer()
            }
            
            // 1. Output Settings
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Text("Output Name").font(.system(size: 11.5, weight: .medium)).foregroundStyle(.secondary).frame(width: 85, alignment: .trailing)
                    TextField("Output Name", text: $outputName)
                        .textFieldStyle(.plain).font(.system(size: 12, weight: .medium)).padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.primary.opacity(0.035)).clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                
                HStack(spacing: 12) {
                    Text("Destination").font(.system(size: 11.5, weight: .medium)).foregroundStyle(.secondary).frame(width: 85, alignment: .trailing)
                    HStack(spacing: 6) {
                        TextField("Destination folder path", text: $targetDirectory)
                            .textFieldStyle(.plain).font(.system(size: 11.5)).padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.primary.opacity(0.035)).clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        Button("Browse...") { onPickDirectory() }.buttonStyle(.bordered).controlSize(.small)
                    }
                }
                
                HStack(alignment: .top, spacing: 12) {
                    Text("Format").font(.system(size: 11.5, weight: .medium)).foregroundStyle(.secondary).frame(width: 85, alignment: .trailing).padding(.top, 4)
                    let all16Formats: [ArchiveCompressionFormat] = [
                        .sevenZip, .zip, .tar, .zst, .gz, .bz2, .xz, .lzip,
                        .lz4, .brotli, .lrzip, .aar, .snappy, .wim, .dmg, .iso
                    ]
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 46), spacing: 5), count: 8), spacing: 6) {
                        ForEach(all16Formats, id: \.rawValue) { fmt in
                            formatTile(format: fmt)
                        }
                    }
                }
                
                compressionLevelSection(fmt: selectedFormat)
            }
            
            Divider()
            
            // 2. Format specific parameters
            formatSpecificAdvancedSection
            
            Divider()
            
            // 3. Hardware & Automation policies
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Text("CPU Threads").font(.system(size: 11.5, weight: .medium)).foregroundStyle(.secondary).frame(width: 85, alignment: .trailing)
                    Picker("", selection: $cpuThreadsOption) {
                        Text("All Cores (\(cachedTotalCores) Threads)").tag("全核")
                        Text("Half Load (\(max(1, cachedTotalCores / 2)) Threads)").tag("半核")
                        Text("Single Thread").tag("单核")
                    }
                    .pickerStyle(.segmented).tint(TTZipTheme.bambooGreen)
                }
                
                HStack(spacing: 12) {
                    Text("Split Volume").font(.system(size: 11.5, weight: .medium)).foregroundStyle(.secondary).frame(width: 85, alignment: .trailing)
                    HStack(spacing: 6) {
                        volTile(size: nil, name: "No Split")
                        volTile(size: 700 * 1024 * 1024, name: "700MB")
                        volTile(size: 4700 * 1024 * 1024, name: "4.7GB")
                        volTile(size: 4000 * 1024 * 1024, name: "4GB (FAT32)")
                        volTile(size: -1, name: "Custom")
                    }
                    if isCustomVolumeSelected {
                        HStack(spacing: 4) {
                            TextField("Value", text: $customVolumeValueString).textFieldStyle(.plain).font(.system(size: 11))
                                .padding(.horizontal, 6).padding(.vertical, 3).background(Color.primary.opacity(0.035)).clipShape(RoundedRectangle(cornerRadius: 6)).frame(width: 60)
                            Picker("", selection: $customVolumeUnit) { Text("MB").tag("MB"); Text("GB").tag("GB") }.pickerStyle(.segmented).tint(TTZipTheme.bambooGreen).frame(width: 70)
                        }
                    }
                }
                
                HStack(spacing: 12) {
                    Text("Encryption").font(.system(size: 11.5, weight: .medium)).foregroundStyle(.secondary).frame(width: 85, alignment: .trailing)
                    HStack(spacing: 10) {
                        Toggle("Enable Encryption", isOn: $enableEncryption).font(.system(size: 11, weight: .bold)).tint(TTZipTheme.bambooGreen)
                        if enableEncryption {
                            TTSecureTextField("Password", text: $password).font(.system(size: 11)).padding(.horizontal, 8).padding(.vertical, 4).background(Color.primary.opacity(0.035)).clipShape(RoundedRectangle(cornerRadius: 6))
                            Button(action: onOpenPasswordVault) {
                                HStack(spacing: 3) { Image(systemName: "key.fill"); Text("Vault...") }
                                    .font(.system(size: 10.5, weight: .semibold)).foregroundStyle(TTZipTheme.kintsugiGold).padding(.horizontal, 7).padding(.vertical, 3).background(TTZipTheme.kintsugiGold.opacity(0.12)).clipShape(Capsule())
                            }.buttonStyle(.plain)
                        }
                    }
                }
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    Toggle("Filter macOS Junk (.DS_Store)", isOn: $skipMacJunk).tint(TTZipTheme.bambooGreen)
                    Toggle("Create Separate Archives per Item", isOn: $createSeparateArchives).tint(TTZipTheme.bambooGreen)
                    Toggle("Move Source Files to Trash After Compression", isOn: $deleteSourceAfterCompress).tint(TTZipTheme.bambooGreen)
                    Toggle("Reveal in Finder Upon Completion", isOn: $openFinderAfterCompress).tint(TTZipTheme.bambooGreen)
                }
                .font(.system(size: 11)).padding(.top, 4)
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.primary.opacity(0.07), lineWidth: 1))
    }
    
    @ViewBuilder
    private var formatSpecificAdvancedSection: some View {
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
    
    private func formatTile(format: ArchiveCompressionFormat) -> some View {
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
    
    private func levelTile(level: ArchiveCompressionLevel, name: String) -> some View {
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
    
    private func volTile(size: Int64?, name: String) -> some View {
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
    
    private func compressionLevelSection(fmt: ArchiveCompressionFormat) -> some View {
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
    
    private func levelTileView(fmt: ArchiveCompressionFormat, lvl: ArchiveCompressionLevel) -> some View {
        let ratioPct = Int(round(lvl.compressionRatioPercent(for: fmt)))
        let titleName: String
        if fmt == .zip {
            switch lvl {
            case .store: titleName = "Store (0%)"
            case .level1: titleName = "1: 极速 (6.0 GB/s)"
            case .level2: titleName = "2: 标准 (5.5 GB/s)"
            case .level3: titleName = "3: 极限 (4.5 GB/s)"
            case .level4: titleName = "4: 深度 (200 MB/s)"
            case .level5: titleName = "5: 图论 (20 MB/s)"
            case .level6: titleName = "6: 超级 (10 MB/s)"
            case .level7: titleName = "7: 巅峰 (5.0 MB/s)"
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
    
    private func calcCustomVol() {
        guard let val = Int64(customVolumeValueString) else { splitVolumeOption = nil; return }
        let mult: Int64 = (customVolumeUnit == "GB") ? 1024 * 1024 * 1024 : 1024 * 1024
        splitVolumeOption = val * mult
    }
}
