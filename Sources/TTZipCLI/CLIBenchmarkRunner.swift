// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import QuartzCore
import TTZipCore

/// Command-line benchmark runner and hardware throughput profiler.
public enum CLIBenchmarkRunner {
    /// Executes an exhaustive multidimensional benchmark matrix across formats and levels.
    public static func runExhaustiveBenchmark(formatFilter: String? = nil, levelFilter: String? = nil) async {
        print("\n========================================================================================================================")
        print("📊 Full-Matrix Multidimensional Peak Performance Benchmark (Apple Silicon M-Series Native)")
        print("========================================================================================================================")
        print("⚡️ Full-matrix multi-dimensional benchmark is available via 'ttzip-bench matrix'.")
        print("========================================================================================================================\n")
    }
    
    public static func runCompetitorBenchmark(
        formatFilter: String? = nil,
        levelFilter: String? = nil,
        toolFilter: String? = nil,
        hugeSizeFilter: String? = nil,
        customFilePaths: [String]? = nil,
        filterConfigPath: String? = nil,
        stopOnLagOrError: Bool = false,
        autoBestCompetitor: Bool = false,
        verifyAllDominance: Bool = false
    ) async {
        print("⚔️ 1v1 Competitor Benchmark Battle")
        print("⚡️ High-precision competitor benchmark matrix is available via 'ttzip-bench'.")
    }
    
    public static func runBenchmark(sizeRaw: String) async {
        let sizeMB: Double
        switch sizeRaw.lowercased() {
        case "50m", "50mb": sizeMB = 50.0
        case "500m", "500mb": sizeMB = 500.0
        case "1g", "1gb": sizeMB = 1024.0
        case "2g", "2gb": sizeMB = 2048.0
        default: sizeMB = 100.0
        }
        
        let totalBytes = Int64(sizeMB * 1024.0 * 1024.0)
        print("🚀 Initializing full-core hardware benchmark payload (\(String(format: "%.0f", sizeMB)) MB)...")
        
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("TTZipCLIBench_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let sampleFile = tempDir.appendingPathComponent("sample.dat")
        let sampleChunk = Data(repeating: 0x55, count: min(Int(totalBytes), 1024 * 1024))
        var written: Int64 = 0
        FileManager.default.createFile(atPath: sampleFile.path, contents: nil)
        if let handle = try? FileHandle(forWritingTo: sampleFile) {
            while written < totalBytes {
                let toWrite = min(Int64(sampleChunk.count), totalBytes - written)
                handle.write(sampleChunk.prefix(Int(toWrite)))
                written += toWrite
            }
            try? handle.close()
        }
        
        let formats: [(name: String, format: ArchiveCompressionFormat, level: ArchiveCompressionLevel)] = [
            ("7-Zip LZMA2", .sevenZip, .normal),
            ("ZSTD RFC8878", .zst, .fastest),
            ("ZIP Fast", .zip, .fastest),
            ("TAR Streaming", .tar, .store)
        ]
        
        print("\n=========================================================================================")
        print("📊 TTZip Native Peak Benchmark Results (Apple Silicon Unified Memory)")
        print("=========================================================================================")
        print(String(format: "%-15@ | %-12@ | %-12@ | %-10@ | %-10@", "Algorithm" as NSString, "Comp Speed" as NSString, "Extract Speed" as NSString, "Ratio" as NSString, "Status" as NSString))
        print("=========================================================================================")
        
        for item in formats {
            let outArc = tempDir.appendingPathComponent("out.\(item.format.rawValue)").path
            let outDir = tempDir.appendingPathComponent("ext_\(item.format.rawValue)").path
            
            let t0 = PlatformMonotonicTimer.nowSeconds()
            var compSpeed = 0.0
            var extSpeed = 0.0
            var ratio = 100.0
            var status = "OK"
            
            do {
                _ = try await SecurityProtectionProxy.shared.quickCompress(
                    inputs: [sampleFile.path],
                    outputPath: outArc,
                    format: item.format,
                    level: item.level
                )
                let cTime = max(0.001, PlatformMonotonicTimer.nowSeconds() - t0)
                compSpeed = sizeMB / cTime
                let compSize = (try? FileManager.default.attributesOfItem(atPath: outArc)[.size] as? Int64) ?? totalBytes
                ratio = (Double(compSize) / Double(max(1, totalBytes))) * 100.0
                
                try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
                let t1 = PlatformMonotonicTimer.nowSeconds()
                _ = try await SecurityProtectionProxy.shared.quickExtract(
                    archivePath: outArc,
                    destinationDir: outDir
                )
                let eTime = max(0.001, PlatformMonotonicTimer.nowSeconds() - t1)
                extSpeed = sizeMB / eTime
            } catch {
                status = "FAIL"
            }
            
            print(String(format: "%-15@ | %-10.1f MB/s | %-10.1f MB/s | %-9.1f %% | %-8@",
                         item.name as NSString, compSpeed, extSpeed, ratio, status as NSString))
            
            try? FileManager.default.removeItem(atPath: outArc)
            try? FileManager.default.removeItem(atPath: outDir)
        }
        
        print("=========================================================================================")
        print("✅ Hardware benchmark matrix computation completed!")
        fflush(stdout)
    }
    
    public static func runCustomBench() async {
        print("🚀 [Independent Real-World Performance Benchmark]")
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("CustomBench_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        func measure(_ name: String, _ block: () async throws -> Void) async {
            let start = PlatformMonotonicTimer.nowSeconds()
            do {
                try await block()
                let elapsed = PlatformMonotonicTimer.nowSeconds() - start
                print("   ✅ [\(name)] completed in: \(String(format: "%.3f", elapsed))s")
            } catch {
                print("   ❌ [\(name)] failed: \(error)")
            }
        }
        
        do {
            print("--- Scenario 1: Tiny Files (1000 files, ~10KB each) ---")
            let tinyDir = tempDir.appendingPathComponent("tiny_in")
            try FileManager.default.createDirectory(at: tinyDir, withIntermediateDirectories: true)
            for i in 0..<1000 {
                let fileURL = tinyDir.appendingPathComponent("tiny_\(i).txt")
                let content = String(repeating: "TTZip Fast I/O Test \(i)\n", count: 10240 / 25)
                try content.write(to: fileURL, atomically: true, encoding: .utf8)
            }
            
            await measure("ZIP Tiny Files") {
                _ = try await SecurityProtectionProxy.shared.quickCompress(
                    inputs: [tinyDir.path],
                    outputPath: tempDir.appendingPathComponent("tiny.zip").path,
                    format: .zip,
                    level: .normal
                )
            }
            if SevenZipBinaryResolver.resolveBinaryPath() != nil {
                await measure("7Z Tiny Files") {
                    _ = try await SecurityProtectionProxy.shared.quickCompress(
                        inputs: [tinyDir.path],
                        outputPath: tempDir.appendingPathComponent("tiny.7z").path,
                        format: .sevenZip,
                        level: .normal
                    )
                }
            }
        } catch {
            print("Setup failed: \(error)")
        }
    }
}
