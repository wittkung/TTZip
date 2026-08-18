// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore

public struct CompressionProInspectorPanel: View {
    @Binding public var isProInspectorPresented: Bool
    @Binding public var cpuThreadsOption: String
    @Binding public var dictionarySizeMB: Int
    @Binding public var compressionAlgorithm: String
    @Binding public var zipEncryptionMethod: String
    @Binding public var zipEncodingUTF8: Bool
    @Binding public var zstdLevel: Int
    @Binding public var zstdEnableLDM: Bool
    @Binding public var preservePosixAttributes: Bool
    @Binding public var enableSolidArchive: Bool
    @Binding public var encryptFileNames: Bool
    @Binding public var enableEncryption: Bool
    @Binding public var isPasswordVaultPresented: Bool
    
    public let selectedFormat: ArchiveCompressionFormat
    public let cachedTotalCores: Int
    public let onShowMatrix: () -> Void
    
    public init(
        isProInspectorPresented: Binding<Bool>,
        cpuThreadsOption: Binding<String>,
        dictionarySizeMB: Binding<Int>,
        compressionAlgorithm: Binding<String>,
        zipEncryptionMethod: Binding<String>,
        zipEncodingUTF8: Binding<Bool>,
        zstdLevel: Binding<Int>,
        zstdEnableLDM: Binding<Bool>,
        preservePosixAttributes: Binding<Bool>,
        enableSolidArchive: Binding<Bool>,
        encryptFileNames: Binding<Bool>,
        enableEncryption: Binding<Bool>,
        isPasswordVaultPresented: Binding<Bool>,
        selectedFormat: ArchiveCompressionFormat,
        cachedTotalCores: Int,
        onShowMatrix: @escaping () -> Void
    ) {
        self._isProInspectorPresented = isProInspectorPresented
        self._cpuThreadsOption = cpuThreadsOption
        self._dictionarySizeMB = dictionarySizeMB
        self._compressionAlgorithm = compressionAlgorithm
        self._zipEncryptionMethod = zipEncryptionMethod
        self._zipEncodingUTF8 = zipEncodingUTF8
        self._zstdLevel = zstdLevel
        self._zstdEnableLDM = zstdEnableLDM
        self._preservePosixAttributes = preservePosixAttributes
        self._enableSolidArchive = enableSolidArchive
        self._encryptFileNames = encryptFileNames
        self._enableEncryption = enableEncryption
        self._isPasswordVaultPresented = isPasswordVaultPresented
        self.selectedFormat = selectedFormat
        self.cachedTotalCores = cachedTotalCores
        self.onShowMatrix = onShowMatrix
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Apple Silicon Hardware Acceleration", systemImage: "cpu.fill")
                    .font(.system(size: 13, weight: .bold, design: .serif))
                    .foregroundStyle(TTZipTheme.kintsugiGold)
                Spacer()
                Button(action: { withAnimation { isProInspectorPresented = false } }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Parallel CPU Thread Allocation")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Picker("", selection: $cpuThreadsOption) {
                    Text("All Cores (\(cachedTotalCores) Threads)").tag("All Cores")
                    Text("Half Cores (\(max(1, cachedTotalCores / 2)) Threads)").tag("Half Cores")
                    Text("Single Thread (1 Thread)").tag("Single Core")
                }
                .pickerStyle(.segmented)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Label("Compression Strategy & Security", systemImage: "lock.shield.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(TTZipTheme.bambooGreen)
                
                Toggle("Enable Solid Archive", isOn: $enableSolidArchive)
                    .disabled(selectedFormat != .sevenZip)
                    .help("Solid archiving packs multiple files into a continuous stream to improve ratio")
                
                Toggle("Encrypt File Names and Headers", isOn: $encryptFileNames)
                    .disabled(!enableEncryption || selectedFormat != .sevenZip)
                    .help("Encrypts the archive directory index and filenames")
                
                Toggle("AES-256 Bit Encryption", isOn: $enableEncryption)
                
                if enableEncryption {
                    Button(action: { isPasswordVaultPresented = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "key.fill")
                            Text("Open Password Vault...")
                        }
                        .font(.caption)
                        .foregroundStyle(TTZipTheme.kintsugiGold)
                    }
                    .buttonStyle(.plain)
                }
            }
            .tint(TTZipTheme.bambooGreen)
            .font(.caption)
            
            Divider()
            
            AlgorithmGuidanceCardView(
                algoInfo: formatGuidanceInfo(selectedFormat),
                onShowMatrix: onShowMatrix
            )
        }
        .padding(14)
        .background(TTZipTheme.subtleFill)
        .clipShape(RoundedRectangle(cornerRadius: TTZipTheme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TTZipTheme.Radius.md, style: .continuous)
                .strokeBorder(TTZipTheme.hairlineBorder, lineWidth: 0.8)
        )
    }
    
    private func formatGuidanceInfo(_ format: ArchiveCompressionFormat) -> (icon: String, color: Color, title: String, desc: String) {
        switch format {
        case .sevenZip:
            return ("sparkles", .blue, "7-Zip (LZMA2)", "Highest compression ratio, recommended for documents and code repositories.")
        case .zip:
            return ("doc.zipper", .purple, "ZIP Standard", "Universal cross-platform compatibility across macOS, Windows, and mobile.")
        case .zst:
            return ("bolt.circle.fill", .orange, "Zstandard (.zst)", "RFC 8878 high-throughput multi-GB/s parallel decompression.")
        case .tarZst:
            return ("bolt.fill", .orange, "TAR.ZST Meta Engine", "Fast parallel tarball packing with streaming Zstd throughput.")
        case .tarGz, .gz:
            return ("terminal.fill", .green, "TAR.GZ Linux / DevOps", "Standard Unix tarball format for software distribution.")
        case .tar:
            return ("folder.fill", .brown, "TAR POSIX Direct I/O", "Uncompressed archive packaging at disk physical I/O speeds.")
        case .bz2, .tarBz2:
            return ("shippingbox.fill", .indigo, "BZIP2 Block Parallel", "Parallel bzip2 block processing for archival storage.")
        case .xz, .tarXz:
            return ("cpu.fill", .cyan, "XZ Multithreaded", "Parallel LZMA2 slicing for source distributions.")
        case .lzip:
            return ("shield.checkerboard", .pink, "LZIP Fault-Tolerant", "High-reliability archival format with 32-bit CRC integrity checks.")
        case .lz4:
            return ("bolt.horizontal.fill", .teal, "LZ4 Sub-Millisecond", "Ultra-fast low-latency streaming compression.")
        case .brotli:
            return ("globe", .orange, "Brotli Web Compression", "Google Brotli engine optimized for web assets and text.")
        case .lrzip:
            return ("slider.horizontal.below.square.filled.and.arrow.between.any.capsule", .mint, "LRZIP Long Range", "Gigabyte-window long range string preprocessing for large datasets.")
        case .aar:
            return ("apple.logo", .red, "AAR Apple Native", "100% macOS Apple Silicon hardware acceleration (LZFSE / PBZX).")
        case .snappy:
            return ("paperplane.fill", .yellow, "Snappy Framed Stream", "Google Snappy low-latency in-memory streaming engine.")
        case .wim:
            return ("window.vertical.closed", .blue, "WIM Windows Image", "Windows Imaging Format deployment container.")
        case .dmg:
            return ("disc.fill", .gray, "DMG Apple Disk Image", "macOS mountable disk image format (APFS / UDZO).")
        case .iso:
            return ("opticaldisc.fill", .purple, "ISO Optical Image", "ISO9660 / Joliet / UDF disc image container.")
        }
    }
}
