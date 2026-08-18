// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore

/// Algorithm characteristics and performance comparison matrix sheet.
public struct AlgorithmMatrixSheetView: View {
    @Binding public var isPresented: Bool
    
    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }
    
    public struct AlgoRow: Identifiable {
        public let id = UUID()
        public let name: String
        public let speed: String
        public let ratio: String
        public let compatibility: String
        public let recommendedFor: String
        public let color: Color
    }
    
    public let rows: [AlgoRow] = [
        AlgoRow(name: "Store (No Compression)", speed: "8,450 MB/s", ratio: "0% (Store)", compatibility: "100%", recommendedFor: "Pre-compressed media, large archive packaging", color: .green),
        AlgoRow(name: "Zstd (Zstandard)", speed: "4,450 MB/s", ratio: "High (~85%)", compatibility: "95% (Modern platforms)", recommendedFor: "Daily backups, source code repos, databases", color: .orange),
        AlgoRow(name: "LZMA2 (7-Zip Default)", speed: "320 ~ 1,600 MB/s", ratio: "Maximum (~92%)", compatibility: "98% (Universal)", recommendedFor: "Documents, software binaries, maximum space savings", color: .blue),
        AlgoRow(name: "Deflate (ZIP Standard)", speed: "85 ~ 600 MB/s", ratio: "Standard (~70%)", compatibility: "100% (Universal default)", recommendedFor: "Cross-platform email attachments, legacy devices", color: .purple),
        AlgoRow(name: "Bzip2", speed: "40 ~ 120 MB/s", ratio: "High (~88%)", compatibility: "90%", recommendedFor: "Large repetitive logs, scientific datasets", color: .indigo)
    ]
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                Text("TTZip Compression Algorithm Matrix")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                Button("Close") { isPresented = false }
                    .buttonStyle(.borderedProminent)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                ForEach(rows) { row in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(row.color)
                            .frame(width: 8, height: 8)
                            .padding(.top, 5)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(row.name)
                                    .font(.headline)
                                    .foregroundStyle(row.color)
                                Spacer()
                                Text("Throughput: \(row.speed)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(row.color.opacity(0.15))
                                    .cornerRadius(4)
                            }
                            
                            HStack(spacing: 16) {
                                Text("Ratio: \(row.ratio)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Compatibility: \(row.compatibility)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Text("Best For: \(row.recommendedFor)")
                                .font(.caption2)
                                .foregroundStyle(.primary)
                        }
                    }
                    .padding(10)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(8)
                }
            }
            
            Spacer()
        }
        .padding(20)
        .frame(width: 620, height: 480)
    }
}

/// Algorithm guidance card subview.
public struct AlgorithmGuidanceCardView: View {
    public let algoInfo: (icon: String, color: Color, title: String, desc: String)
    public let onShowMatrix: () -> Void
    
    public init(algoInfo: (icon: String, color: Color, title: String, desc: String), onShowMatrix: @escaping () -> Void) {
        self.algoInfo = algoInfo
        self.onShowMatrix = onShowMatrix
    }
    
    public var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: algoInfo.icon)
                .foregroundStyle(algoInfo.color)
                .font(.caption)
            VStack(alignment: .leading, spacing: 2) {
                Text(algoInfo.title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(algoInfo.color)
                Text(algoInfo.desc)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                Button(action: onShowMatrix) {
                    HStack(spacing: 4) {
                        Text("View Algorithm Comparison Matrix")
                            .font(.caption2)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .padding(8)
        .background(TTZipTheme.subtleFill)
        .clipShape(RoundedRectangle(cornerRadius: TTZipTheme.Radius.sm, style: .continuous))
    }
}

/// Compression summary statistics sheet view.
public struct CompressionSummarySheetView: View {
    public let archivePath: String
    public let originalSizeBytes: Int64
    public let compressedSizeBytes: Int64
    public let elapsedSeconds: Double
    public let throughputMBs: Double
    public let format: ArchiveCompressionFormat
    public let isEncrypted: Bool
    public let onCloseAndExplore: () -> Void
    
    public init(
        archivePath: String,
        originalSizeBytes: Int64,
        compressedSizeBytes: Int64,
        elapsedSeconds: Double,
        throughputMBs: Double,
        format: ArchiveCompressionFormat,
        isEncrypted: Bool,
        onCloseAndExplore: @escaping () -> Void
    ) {
        self.archivePath = archivePath
        self.originalSizeBytes = originalSizeBytes
        self.compressedSizeBytes = compressedSizeBytes
        self.elapsedSeconds = elapsedSeconds
        self.throughputMBs = throughputMBs
        self.format = format
        self.isEncrypted = isEncrypted
        self.onCloseAndExplore = onCloseAndExplore
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(TTZipTheme.bambooGreen)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Compression Completed")
                        .font(.title3).fontWeight(.bold)
                    Text((archivePath as NSString).lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            
            Divider()
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Throughput")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f MB/s", throughputMBs))
                        .font(.system(.title3, design: .monospaced, weight: .bold))
                        .foregroundStyle(TTZipTheme.bambooGreen)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.025))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                let ratio = originalSizeBytes > 0 ? (1.0 - Double(compressedSizeBytes) / Double(originalSizeBytes)) * 100.0 : 0.0
                VStack(alignment: .leading, spacing: 4) {
                    Text("Space Savings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "-%.1f%%", max(0, ratio)))
                        .font(.system(.title3, design: .monospaced, weight: .bold))
                        .foregroundStyle(.purple)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.025))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Size Delta")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(ByteCountFormatterFlyweight.shared.string(fromByteCount: originalSizeBytes)) ➔ \(ByteCountFormatterFlyweight.shared.string(fromByteCount: compressedSizeBytes))")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .lineLimit(1)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.025))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Elapsed / Encryption")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.2fs · %@", elapsedSeconds, isEncrypted ? "AES-256" : "None"))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isEncrypted ? .orange : .primary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.025))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            Divider()
            
            Button(action: onCloseAndExplore) {
                HStack {
                    Image(systemName: "folder.badge.gearshape")
                    Text("Done and Explore Archive")
                        .fontWeight(.bold)
                }
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(TTZipTheme.bambooGreen)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: [.command])
        }
        .padding(20)
        .frame(width: 440)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.25), radius: 24, y: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(TTZipTheme.bambooGreen.opacity(0.4), lineWidth: 1)
        )
    }
}
