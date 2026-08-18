// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore

/// Compression algorithms, container formats, and advanced parameters guide sheet.
public struct CompressionGuideSheetView: View {
    @Binding var isPresented: Bool
    @State private var selectedTab = 0
    
    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "book.pages.fill")
                            .foregroundStyle(TTZipTheme.kintsugiGold)
                        Text("COMPRESSION ENCYCLOPEDIA")
                            .font(.system(size: 9, weight: .bold, design: .serif))
                            .tracking(2)
                            .foregroundStyle(TTZipTheme.kintsugiGold)
                    }
                    Text("Compression Algorithms, Formats & Advanced Guide")
                        .font(.system(size: 15, weight: .bold, design: .serif))
                        .foregroundStyle(.primary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.primary.opacity(0.025))
            
            Divider()
            
            HStack(spacing: 6) {
                tabButton(title: "📦 Formats", index: 0)
                tabButton(title: "⚡ Algorithms", index: 1)
                tabButton(title: "🎛 Parameters", index: 2)
                tabButton(title: "🔒 Security & Splits", index: 3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.015))
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedTab {
                    case 0: formatsGuideSection
                    case 1: algorithmsGuideSection
                    case 2: advancedParamsSection
                    case 3: securityAndSplitSection
                    default: EmptyView()
                    }
                }
                .padding(20)
            }
            
            Divider()
            
            HStack {
                Text("TTZip Architecture Whitepaper & HIG Reference")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Done") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .tint(TTZipTheme.bambooGreen)
                .controlSize(.regular)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .frame(width: 660, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func tabButton(title: String, index: Int) -> some View {
        let isSelected = selectedTab == index
        return Button(action: { selectedTab = index }) {
            Text(title)
                .font(.system(size: 11.5, weight: isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? TTZipTheme.bambooGreen : Color.primary.opacity(0.04))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    private var formatsGuideSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            guideCard(
                icon: "archivebox.fill",
                title: ".7z (7-Zip High Compression)",
                badge: "High Ratio",
                content: "Open architecture format designed by Igor Pavlov. Supports multithreaded LZMA2, Solid Archive block packing, header encryption (-mhe=on), and dictionaries up to 512MB. Ideal for source code, large documents, and maximum space savings."
            )
            
            guideCard(
                icon: "doc.zipper",
                title: ".zip (ZIP Standard)",
                badge: "Universal",
                content: "Universal cross-platform standard with built-in support on macOS, Windows, Linux, iOS, and Android. Features Deflate, AES-256 encryption, and UTF-8 encoding flags to prevent filename corruption across platforms."
            )
            
            guideCard(
                icon: "bolt.horizontal.fill",
                title: ".tar.zst / .zst (Zstandard)",
                badge: "Ultra-Fast",
                content: "Next-generation high-throughput algorithm developed by Meta (Facebook). Combined with POSIX streaming, delivers 600-900 MB/s compression and extraction speeds, ideal for large datasets and backups."
            )
            
            guideCard(
                icon: "terminal.fill",
                title: ".tar.gz / .tar.bz2 / .tar.xz (Unix Tarball)",
                badge: "POSIX",
                content: "Standard Unix archive packaging paired with streaming compression (Gzip, Bzip2, or XZ). Preserves POSIX file modes, timestamps, and extended attributes."
            )
        }
    }
    
    private var algorithmsGuideSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            guideCard(
                icon: "cpu",
                title: "LZMA2 (High Ratio & Multithreading)",
                badge: "7z Default",
                content: "Enhanced LZMA algorithm with parallel chunking and dictionary buffers up to 512MB. Delivers top-tier compression ratios across documents, binaries, and code."
            )
            
            guideCard(
                icon: "doc.text.fill",
                title: "PPMd (Text / Code Prediction)",
                badge: "Text Specialist",
                content: "Prediction by Partial Matching algorithm designed by Dmitry Shkarin. Optimized for pure text, source code, HTML, and JSON data structures."
            )
            
            guideCard(
                icon: "square.stack.3d.down.right.fill",
                title: "Deflate / Deflate64 (Standard)",
                badge: "ZIP / GZIP",
                content: "Classic LZ77 and Huffman coding pipeline. Fast hardware decoding and universal compatibility across all operating systems."
            )
            
            guideCard(
                icon: "bolt.fill",
                title: "Zstd / Zstandard (High Throughput)",
                badge: "Modern Standard",
                content: "Finite State Entropy (FSE) based compressor delivering ratios comparable to Deflate with 3x to 5x higher decompression throughput."
            )
            
            guideCard(
                icon: "shippingbox.fill",
                title: "Copy / Store (0% Compression)",
                badge: "Passthrough",
                content: "Direct I/O passthrough without compression compute overhead. Ideal for pre-compressed media like MP4, JPG, MP3, and disk images."
            )
        }
    }
    
    private var advancedParamsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            guideCard(
                icon: "memorychip",
                title: "Dictionary Size",
                badge: "Memory Window",
                content: "Sliding window memory buffer used for matching duplicate data strings. Larger dictionaries (e.g., 64MB, 128MB) improve ratio on repetitive data at the cost of additional RAM usage."
            )
            
            guideCard(
                icon: "cube.transparent.fill",
                title: "Solid Archive",
                badge: "7z Feature",
                content: "Packs multiple files into a single continuous stream for cross-file dictionary matching. Increases ratio by 20%-50% for batches of similar files."
            )
            
            guideCard(
                icon: "arrow.triangle.2.circlepath",
                title: "Long Distance Matching (--long=27)",
                badge: "Zstd Feature",
                content: "Zstandard LDM window extending up to 128MB+ to detect redundancy across distant large files and log batches."
            )
        }
    }
    
    private var securityAndSplitSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            guideCard(
                icon: "lock.shield.fill",
                title: "AES-256 vs ZipCrypto",
                badge: "Security",
                content: "AES-256 utilizes 256-bit symmetric encryption with hardware SIMD acceleration. ZipCrypto is a legacy algorithm with known cryptographic vulnerabilities."
            )
            
            guideCard(
                icon: "eye.slash.fill",
                title: "Encrypt File Names (-mhe=on)",
                badge: "7z Header Security",
                content: "Encrypts the central archive directory index and filenames. Directory contents remain completely hidden until unlocked with the correct password."
            )
            
            guideCard(
                icon: "square.split.2x2.fill",
                title: "Volume Splitting",
                badge: "Multi-Part",
                content: "Splits large archives into defined volume segments (e.g., 25MB email limit, 4GB FAT32). Selecting the primary volume automatically reassembles the complete archive."
            )
        }
    }
    
    private func guideCard(icon: String, title: String, badge: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(TTZipTheme.bambooGreen)
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer()
                Text(badge)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(TTZipTheme.kintsugiGold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(TTZipTheme.kintsugiGold.opacity(0.12))
                    .clipShape(Capsule())
            }
            Text(content)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
        }
        .padding(12)
        .background(Color.primary.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8)
        )
    }
}
