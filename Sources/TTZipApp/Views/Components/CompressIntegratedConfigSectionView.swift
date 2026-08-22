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
}
