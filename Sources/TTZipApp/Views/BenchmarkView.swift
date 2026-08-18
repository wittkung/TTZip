// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore

/// Benchmark command center view.
public struct BenchmarkView: View {
    @StateObject private var viewModel = BenchmarkViewModel()
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("BENCHMARK MATRIX")
                        .font(.system(size: 9, weight: .bold, design: .serif))
                        .tracking(2)
                        .foregroundStyle(TTZipTheme.kintsugiGold)
                    Text("Performance & Benchmarks")
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                Button(action: { viewModel.startAllPresetsSuite() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text(viewModel.isRunning ? "Benchmarking..." : "Run Suite (⌘R)")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [TTZipTheme.bambooGreen, TTZipTheme.bambooGreen.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: TTZipTheme.bambooGreen.opacity(0.25), radius: 4, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(viewModel.isRunning || (viewModel.testMode == .customFile && viewModel.customPath == nil))
            }
            .padding(.horizontal, 20)
            .frame(height: 52)
            
            Rectangle()
                .fill(TTZipTheme.kintsugiGold)
                .frame(height: 1.5)
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    BenchmarkHardwareBannerView()
                    
                    BenchmarkCompetitorPanel(viewModel: viewModel)
                    
                    BenchmarkConfigSectionView(viewModel: viewModel)
                    
                    if let err = viewModel.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(TTZipTheme.cinnabarRed)
                            Text(err)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(TTZipTheme.cinnabarRed)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(TTZipTheme.cinnabarRed.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    
                    if viewModel.isRunning {
                        LiveBenchmarkSpeedDialView(
                            itemName: viewModel.currentPresetName,
                            itemIndex: viewModel.currentSuiteIndex,
                            totalItems: viewModel.totalSuiteCount,
                            progress: viewModel.currentProgress,
                            isPaused: viewModel.isPaused,
                            onTogglePause: { viewModel.togglePause() },
                            onStop: { viewModel.stopSuite() }
                        )
                    }
                    
                    if !viewModel.suiteResults.isEmpty {
                        resultsCanvas
                    }
                }
                .padding(20)
            }
        }
        .background(Color.primary.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        )
        .padding(.top, 38)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .frame(minWidth: 320, minHeight: 300)
        .alert("Homebrew Package Manager Installation", isPresented: $viewModel.showHomebrewConsentModal) {
            Button("Agree and Install Homebrew & 7-Zip") {
                viewModel.installSevenZipToolchain(consentedHomebrew: true)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Homebrew is required to install 7-Zip CLI (7zz). Install now?")
        }
    }
    
    private var resultsCanvas: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(TTZipTheme.bambooGreen)
                    Text("Benchmark Results")
                        .font(.system(size: 14, weight: .bold, design: .serif))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                if viewModel.testMode == .synthetic {
                    Text("Synthetic · \(viewModel.selectedSize.rawValue)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                } else if let path = viewModel.customPath {
                    Text("Sample: \((path as NSString).lastPathComponent)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(TTZipTheme.bambooGreen)
                }
            }
            
            let maxThroughput = max(100.0, viewModel.suiteResults.map { max($0.throughputMBs, $0.decompressionThroughputMBs) }.max() ?? 100.0)
            
            VStack(spacing: 12) {
                ForEach(viewModel.suiteResults.indices, id: \.self) { idx in
                    BenchmarkResultRowView(result: viewModel.suiteResults[idx], maxThroughput: maxThroughput)
                }
            }
        }
        .padding(18)
        .background(Color.primary.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
