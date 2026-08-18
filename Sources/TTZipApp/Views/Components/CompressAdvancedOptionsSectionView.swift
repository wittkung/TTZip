// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore

/// Advanced compression settings and hardware dispatch options view.
public struct CompressAdvancedOptionsSectionView: View {
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
    
    public let selectedFormat: ArchiveCompressionFormat
    public let cachedTotalCores: Int
    public let onOpenPasswordVault: () -> Void
    public let onShowMatrix: () -> Void
    
    public init(
        cpuThreadsOption: Binding<String>,
        splitVolumeOption: Binding<Int64?>,
        isCustomVolumeSelected: Binding<Bool>,
        customVolumeValueString: Binding<String>,
        customVolumeUnit: Binding<String>,
        enableEncryption: Binding<Bool>,
        password: Binding<String>,
        enableSolidArchive: Binding<Bool>,
        encryptFileNames: Binding<Bool>,
        skipMacJunk: Binding<Bool>,
        createSeparateArchives: Binding<Bool>,
        deleteSourceAfterCompress: Binding<Bool>,
        openFinderAfterCompress: Binding<Bool>,
        selectedFormat: ArchiveCompressionFormat,
        cachedTotalCores: Int,
        onOpenPasswordVault: @escaping () -> Void,
        onShowMatrix: @escaping () -> Void
    ) {
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
        self.selectedFormat = selectedFormat
        self.cachedTotalCores = cachedTotalCores
        self.onOpenPasswordVault = onOpenPasswordVault
        self.onShowMatrix = onShowMatrix
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Apple Silicon Hardware Acceleration & Engine Settings", systemImage: "cpu.fill")
                    .font(.system(size: 13, weight: .bold, design: .serif))
                    .foregroundStyle(TTZipTheme.kintsugiGold)
                Spacer()
            }
            
            AlgorithmGuidanceCardView(
                algoInfo: formatGuidanceInfo(selectedFormat),
                onShowMatrix: onShowMatrix
            )
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Parallel CPU Thread Allocation")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Picker("", selection: $cpuThreadsOption) {
                    Text("All Cores (\(cachedTotalCores) Threads)").tag("全核")
                    Text("Half Load (\(max(1, cachedTotalCores / 2)) Threads)").tag("半核")
                    Text("Single Thread (\(1) Thread)").tag("单核")
                }
                .pickerStyle(.segmented)
                .tint(TTZipTheme.bambooGreen)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Split Volume Size Limit")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 8) {
                    volumeOptionTile(size: nil, name: "No Split")
                    volumeOptionTile(size: 700 * 1024 * 1024, name: "CD (700MB)")
                    volumeOptionTile(size: 4700 * 1024 * 1024, name: "DVD (4.7GB)")
                    volumeOptionTile(size: 4000 * 1024 * 1024, name: "FAT32 (4GB)")
                    volumeOptionTile(size: -1, name: "Custom")
                }
                
                if isCustomVolumeSelected {
                    HStack(spacing: 6) {
                        TextField("Value", text: $customVolumeValueString)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11.5))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.035))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8))
                            .frame(width: 100)
                        
                        Picker("", selection: $customVolumeUnit) {
                            Text("MB").tag("MB")
                            Text("GB").tag("GB")
                        }
                        .pickerStyle(.segmented)
                        .tint(TTZipTheme.bambooGreen)
                        .frame(width: 100)
                    }
                    .padding(.top, 4)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Toggle("Enable AES-256 Encryption", isOn: $enableEncryption)
                        .font(.system(size: 11.5, weight: .bold))
                        .tint(TTZipTheme.bambooGreen)
                    
                    Spacer()
                    
                    Button(action: onOpenPasswordVault) {
                        HStack(spacing: 4) {
                            Image(systemName: "key.fill")
                            Text("🔑 Choose from Vault...")
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(TTZipTheme.kintsugiGold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(TTZipTheme.kintsugiGold.opacity(0.14))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                
                if enableEncryption {
                    TTSecureTextField("Enter encryption password", text: $password)
                        .font(.system(size: 12))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.035))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8))
                }
                
                Toggle("Solid Archive (Optimized for small files)", isOn: $enableSolidArchive)
                    .disabled(selectedFormat != .sevenZip)
                    .tint(TTZipTheme.bambooGreen)
                
                Toggle("Encrypt File Names and Directory Structure", isOn: $encryptFileNames)
                    .disabled(!enableEncryption || selectedFormat != .sevenZip)
                    .tint(TTZipTheme.bambooGreen)
            }
            .font(.system(size: 11))
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Cleanup & Automation Policies")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    Toggle("Filter macOS Junk (.DS_Store / __MACOSX)", isOn: $skipMacJunk)
                        .tint(TTZipTheme.bambooGreen)
                    
                    Toggle("Create Separate Archives per Item", isOn: $createSeparateArchives)
                        .tint(TTZipTheme.bambooGreen)
                    
                    Toggle("Move Source Files to Trash After Compression", isOn: $deleteSourceAfterCompress)
                        .tint(TTZipTheme.bambooGreen)
                    
                    Toggle("Reveal in Finder Upon Completion", isOn: $openFinderAfterCompress)
                        .tint(TTZipTheme.bambooGreen)
                }
                .font(.system(size: 11))
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }
    
    private func volumeOptionTile(size: Int64?, name: String) -> some View {
        let isSelected: Bool
        if size == -1 {
            isSelected = isCustomVolumeSelected
        } else {
            isSelected = !isCustomVolumeSelected && splitVolumeOption == size
        }
        
        return Button(action: {
            if size == -1 {
                isCustomVolumeSelected = true
                calculateCustomVolume()
            } else {
                isCustomVolumeSelected = false
                splitVolumeOption = size
            }
        }) {
            Text(name)
                .font(.system(size: 10.5, weight: isSelected ? .bold : .regular))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(isSelected ? TTZipTheme.bambooGreen.opacity(0.14) : Color.primary.opacity(0.03))
                .foregroundStyle(isSelected ? TTZipTheme.bambooGreen : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(isSelected ? TTZipTheme.bambooGreen.opacity(0.4) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    private func calculateCustomVolume() {
        guard let val = Int64(customVolumeValueString) else {
            splitVolumeOption = nil
            return
        }
        let multiplier: Int64 = (customVolumeUnit == "GB") ? 1024 * 1024 * 1024 : 1024 * 1024
        splitVolumeOption = val * multiplier
    }
    
    private func formatGuidanceInfo(_ format: ArchiveCompressionFormat) -> (icon: String, color: Color, title: String, desc: String) {
        switch format {
        case .sevenZip:
            return ("sparkles", .blue, "7-Zip (LZMA2) Standard", "High compression ratio, recommended for documents and code repositories.")
        case .zip:
            return ("doc.zipper", .purple, "ZIP Universal", "Maximum cross-platform compatibility across Windows, Linux, and mobile devices.")
        case .zst:
            return ("bolt.circle.fill", .orange, "Zstandard (.zst) Fast Stream", "RFC 8878 high-throughput multi-GB/s parallel decompression.")
        case .tarZst:
            return ("bolt.fill", .orange, "TAR.ZST Meta Stream", "Ultra-fast multi-core parallel streaming archive.")
        case .tarGz, .gz:
            return ("terminal.fill", .green, "TAR.GZ Linux/DevOps", "Standard Unix server distribution and code archive format.")
        case .tar:
            return ("folder.fill", .brown, "TAR POSIX Zero-Copy", "Uncompressed fast archiving maximizing raw disk throughput.")
        case .bz2, .tarBz2:
            return ("shippingbox.fill", .indigo, "BZIP2 High Density", "Parallel pbzip2 block-level compression for Unix archives.")
        case .xz, .tarXz:
            return ("cpu.fill", .cyan, "XZ Source Archive", "Parallel LZMA2 slicing for software release distributions.")
        case .lzip:
            return ("shield.checkerboard", .pink, "LZIP Resilient Archive", "CRC32 protected slicing for robust long-term backup.")
        case .lz4:
            return ("bolt.horizontal.fill", .teal, "LZ4 Sub-millisecond Frame", "Ultra-fast frame compression exceeding multi-GB/s throughput.")
        case .brotli:
            return ("globe", .orange, "BROTLI Web Compression", "Google Brotli algorithm optimized for web resources.")
        case .lrzip:
            return ("slider.horizontal.below.square.filled.and.arrow.between.any.capsule", .mint, "LRZIP Long Range Match", "Gigabyte-window matching for large multi-gigabyte corpora.")
        case .aar:
            return ("apple.logo", .red, "AAR Apple Native Archive", "100% macOS Apple Silicon hardware acceleration (LZFSE/PBZX).")
        case .snappy:
            return ("paperplane.fill", .yellow, "SNAPPY Framed Stream", "Google Snappy low-latency memory stream compression.")
        case .wim:
            return ("window.vertical.closed", .blue, "WIM Windows Image", "Windows deployment image packaging standard.")
        case .dmg:
            return ("disc.fill", .gray, "DMG Apple Disk Image", "macOS standard mountable virtual disk format.")
        case .iso:
            return ("opticaldisc.fill", .purple, "ISO Optical Image", "ISO9660 / Joliet / UDF universal optical disc image.")
        }
    }
}
