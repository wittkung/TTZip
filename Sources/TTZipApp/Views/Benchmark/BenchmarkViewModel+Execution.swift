// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore

extension BenchmarkViewModel {
    /// Executes full preset matrix benchmark.
    public func startAllPresetsSuite() {
        if testMode == .frontend {
            isRunning = true
            errorMessage = nil
            currentPresetName = "Frontend Rendering Performance Suite"
            Task {
                let report = await FrontendBenchmarkRunner.shared.runFullFrontendSuite()
                await MainActor.run {
                    self.frontendReport = report
                    self.isRunning = false
                }
            }
            return
        }
        
        if testMode == .customFile {
            guard let path = customPath, !path.isEmpty else {
                errorMessage = "Please select a local file or folder for benchmark."
                return
            }
        }
        
        isRunning = true
        errorMessage = nil
        suiteResults = []
        
        Task {
            let engine = BenchmarkEngine()
            do {
                if testMode == .customFile, let path = customPath {
                    let presets: [(name: String, format: ArchiveCompressionFormat, splitSize: Int64?, rec: String, score: Int)] = [
                        ("7-Zip LZMA2 Parallel", .sevenZip, nil, "📦 Ultra Ratio", 98),
                        ("ZIP libdeflate Fast Engine", .zip, nil, "⚡ High Compatibility", 100),
                        ("TAR POSIX Zero-Copy Stream", .tar, nil, "🚀 Direct Streaming", 99),
                        ("ZSTD RFC8878 Stream", .zst, nil, "⚡ Lightning Throughput", 99),
                        ("GZIP libdeflate SIMD", .gz, nil, "🔥 Fast Legacy", 97),
                        ("BZIP2 pbzip2 Parallel", .bz2, nil, "💎 Classical", 90),
                        ("XZ Parallel LZMA2 Slices", .xz, nil, "📦 Deep Matching", 94),
                        ("LZIP 32-bit CRC Slices", .lzip, nil, "🛡️ Safe Recovery", 91),
                        ("LZ4 Sub-millisecond Frame", .lz4, nil, "⚡ Maximum Speed", 99),
                        ("BROTLI Multi-Block", .brotli, nil, "🌐 Web Resource", 95),
                        ("LRZIP Long Range Match", .lrzip, nil, "📦 Big Corpus", 96),
                        ("AAR Apple Silicon Hardware", .aar, nil, "🍎 macOS Native", 100),
                        ("SNAPPY Google Framed", .snappy, nil, "⚡ Zero-Latency", 98),
                        ("WIM Split Archive", .wim, nil, "💻 Windows Compatibility", 90),
                        ("DMG macOS Disk Image", .dmg, nil, "💿 Apple Mountable", 92),
                        ("ISO Optical Disk Image", .iso, nil, "💿 ISO Standard", 90)
                    ]
                    
                    for (index, preset) in presets.enumerated() {
                        await MainActor.run {
                            self.currentPresetName = preset.name
                            self.currentSuiteIndex = index + 1
                            self.totalSuiteCount = presets.count
                        }
                        
                        let res = try await engine.runCustomFileBenchmark(
                            inputPath: path,
                            format: preset.format,
                            level: self.selectedLevel,
                            splitVolumeSizeBytes: preset.splitSize,
                            recommendation: preset.rec,
                            baseScore: preset.score,
                            progressHandler: { [weak self] prog in
                                Task { @MainActor in
                                    self?.currentProgress = prog
                                }
                            }
                        )
                        
                        await MainActor.run {
                            self.suiteResults.append(res)
                        }
                    }
                    await MainActor.run {
                        self.isRunning = false
                    }
                } else {
                    _ = try await engine.runAllPresetsSuite(
                        size: selectedSize,
                        profile: selectedProfile,
                        level: selectedLevel,
                        onPresetCompleted: { [weak self] currentIdx, total, result in
                            Task { @MainActor in
                                self?.suiteResults.append(result)
                            }
                        },
                        progressHandler: { [weak self] currentIdx, total, name, prog in
                            Task { @MainActor in
                                self?.currentPresetName = name
                                self?.currentSuiteIndex = currentIdx
                                self?.totalSuiteCount = total
                                self?.currentProgress = prog
                            }
                        }
                    )
                    await MainActor.run {
                        self.isRunning = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isRunning = false
                }
            }
        }
    }
    
    /// Runs single algorithm benchmark.
    public func startSingleBenchmark() {
        if testMode == .customFile {
            guard let path = customPath, !path.isEmpty else {
                errorMessage = "Please select a local file or folder for benchmark."
                return
            }
        }
        
        isRunning = true
        errorMessage = nil
        
        Task {
            let engine = BenchmarkEngine()
            do {
                let res: BenchmarkResult
                if testMode == .customFile, let path = customPath {
                    res = try await engine.runCustomFileBenchmark(
                        inputPath: path,
                        format: selectedFormat,
                        level: selectedLevel,
                        progressHandler: { [weak self] prog in
                            Task { @MainActor in
                                self?.currentProgress = prog
                            }
                        }
                    )
                } else {
                    res = try await engine.runBenchmark(
                        size: selectedSize,
                        profile: selectedProfile,
                        format: selectedFormat,
                        level: selectedLevel,
                        progressHandler: { [weak self] prog in
                            Task { @MainActor in
                                self?.currentProgress = prog
                            }
                        }
                    )
                }
                await MainActor.run {
                    self.lastResult = res
                    self.isRunning = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isRunning = false
                }
            }
        }
    }
}
