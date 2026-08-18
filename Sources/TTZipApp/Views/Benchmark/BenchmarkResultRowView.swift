// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore

public struct BenchmarkResultRowView: View {
    let result: BenchmarkResult
    let maxThroughput: Double
    
    public init(result: BenchmarkResult, maxThroughput: Double) {
        self.result = result
        self.maxThroughput = maxThroughput
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(result.formatName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.primary)
                        
                        Text(result.recommendationBadge)
                            .font(.system(size: 9.5, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(TTZipTheme.bambooGreen.opacity(0.14))
                            .foregroundStyle(TTZipTheme.bambooGreen)
                            .clipShape(Capsule())
                    }
                    
                    Text("Size reduced \(String(format: "%.1f", result.spaceSavedPercent))% (\(formatBytes(result.originalSizeBytes)) ➔ \(formatBytes(result.compressedSizeBytes)))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            GeometryReader { geometry in
                let width = geometry.size.width
                let center = width / 2
                
                let compRatio = min(1.0, CGFloat(result.throughputMBs / maxThroughput))
                let decompRatio = min(1.0, CGFloat(result.decompressionThroughputMBs / maxThroughput))
                
                let compWidth = max(4, (center - 12) * compRatio)
                let decompWidth = max(4, (center - 12) * decompRatio)
                
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.12))
                        .frame(width: 1.5, height: 26)
                        .offset(x: center)
                    
                    ZStack(alignment: .trailing) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [TTZipTheme.bambooGreen, TTZipTheme.bambooGreen.opacity(0.75)],
                                    startPoint: .trailing,
                                    endPoint: .leading
                                )
                            )
                            .frame(width: compWidth, height: 24)
                        
                        if compWidth > 90 {
                            HStack(spacing: 4) {
                                Text("\(String(format: "%.1f", result.throughputMBs)) MB/s")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                                Text("(\(String(format: "%.1f", result.speedupMultiplier))x)")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                            .padding(.trailing, 8)
                        }
                    }
                    .frame(width: compWidth, alignment: .trailing)
                    .offset(x: center - compWidth - 1.5)
                    
                    if compWidth <= 90 {
                        HStack(spacing: 3) {
                            Text("\(String(format: "%.0f", result.throughputMBs)) MB/s")
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            Text("(\(String(format: "%.1f", result.speedupMultiplier))x)")
                                .font(.system(size: 8.5))
                        }
                        .foregroundStyle(TTZipTheme.bambooGreen)
                        .offset(x: center - compWidth - 110, y: 0)
                    }
                    
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue, Color.cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: decompWidth, height: 24)
                        
                        if decompWidth > 80 {
                            Text("\(String(format: "%.1f", result.decompressionThroughputMBs)) MB/s")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(.leading, 8)
                        }
                    }
                    .frame(width: decompWidth, alignment: .leading)
                    .offset(x: center + 1.5)
                    
                    if decompWidth <= 80 {
                        Text("\(String(format: "%.0f", result.decompressionThroughputMBs)) MB/s")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.blue)
                            .offset(x: center + decompWidth + 6, y: 0)
                    }
                    
                    Text("Compress ◀")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .offset(x: 4, y: 0)
                    
                    Text("▶ Decompress")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .offset(x: width - 70, y: 0)
                }
            }
            .frame(height: 28)
            
            if !result.installedCompetitorScores.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Empirical Competitor Benchmarks:")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    
                    ForEach(result.installedCompetitorScores) { score in
                        HStack(spacing: 8) {
                            Image(systemName: score.tool.iconSystemName)
                                .font(.system(size: 11))
                                .foregroundStyle(TTZipTheme.kintsugiGold)
                            Text(score.tool.name)
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            Text("\(String(format: "%.1f", score.measuredThroughputMBs)) MB/s")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                            
                            let relativeRatio = max(1.0, result.throughputMBs / max(1.0, score.measuredThroughputMBs))
                            Text("TTZip \(String(format: "%.1f", relativeRatio))x")
                                .font(.system(size: 9.5, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(TTZipTheme.bambooGreen.opacity(0.15))
                                .foregroundStyle(TTZipTheme.bambooGreen)
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.primary.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
