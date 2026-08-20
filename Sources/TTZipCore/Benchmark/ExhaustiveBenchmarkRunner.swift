// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CryptoKit


/// Metrics row representing a single benchmark permutation.
// ExhaustiveBenchmarkRow imported from TTZipCore

/// Exhaustive matrix benchmark runner across formats, levels, encryption modes, and datasets.
public final class ExhaustiveBenchmarkRunner: @unchecked Sendable {
    public init() {}

    /// Executes full matrix benchmark permutations (Format x Level x Encryption x Payload).
    public static func runExhaustiveMatrix(
        selectedFormats: [ArchiveCompressionFormat]? = nil,
        selectedLevels: [ArchiveCompressionLevel]? = nil,
        isQuickTest: Bool = false,
        progressHandler: (@Sendable (String) -> Void)? = nil
    ) async throws -> [ExhaustiveBenchmarkRow] {
        let cacheDir = FileManager.default.temporaryDirectory.appendingPathComponent("TTZipExhaustiveDatasetCache")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        var results: [ExhaustiveBenchmarkRow] = []

        // 1. Prepare benchmark payload datasets
        let dim1Dir = cacheDir.appendingPathComponent("small_files")
        let dim2LogFile = cacheDir.appendingPathComponent("sample_log.log")
        let dim3EntropyFile = cacheDir.appendingPathComponent("high_entropy_100m.bin")
        let dim4HugeFile = cacheDir.appendingPathComponent("huge_5g.bin")

        if isQuickTest {
            if !FileManager.default.fileExists(atPath: dim1Dir.path) {
                try? FileManager.default.createDirectory(at: dim1Dir, withIntermediateDirectories: true)
                let sampleText = String(repeating: "Apple Silicon M-Series Ultra High Throughput Test Log Line...\n", count: 20)
                for i in 0..<5 {
                    let fURL = dim1Dir.appendingPathComponent("file_\(i).txt")
                    try? sampleText.data(using: .utf8)?.write(to: fURL)
                }
            }
        } else {
            let isDatasetCached = FileManager.default.fileExists(atPath: dim1Dir.path) &&
                                  FileManager.default.fileExists(atPath: dim2LogFile.path) &&
                                  FileManager.default.fileExists(atPath: dim3EntropyFile.path) &&
                                  FileManager.default.fileExists(atPath: dim4HugeFile.path)

            if isDatasetCached {
                progressHandler?("[Cache Hit] Existing benchmark datasets detected, launching immediately...")
            } else {
                progressHandler?("[Initial Setup] Generating exhaustive physical datasets...")
                
                try? FileManager.default.createDirectory(at: dim1Dir, withIntermediateDirectories: true)
                let sampleText = String(repeating: "Apple Silicon M-Series Ultra High Throughput Test Log Line...\n", count: 2000)
                for i in 0..<100 {
                    let fURL = dim1Dir.appendingPathComponent("file_\(i).txt")
                    try? sampleText.data(using: .utf8)?.write(to: fURL)
                }

                let logChunk = String(repeating: "[2026-08-08 14:00:00.123] [INFO] [192.168.1.100] User authentication token validated successfully for session 123456\n", count: 1000).data(using: .utf8)!
                FileManager.default.createFile(atPath: dim2LogFile.path, contents: nil)
                if let logHandle = try? FileHandle(forWritingTo: dim2LogFile) {
                    for _ in 0..<100 { logHandle.write(logChunk) }
                    try? logHandle.close()
                }

                var randData = Data(count: 100 * 1024 * 1024)
                randData.withUnsafeMutableBytes { ptr in
                    arc4random_buf(ptr.baseAddress!, ptr.count)
                }
                try? randData.write(to: dim3EntropyFile)

                let mkfileBin = FileManager.default.fileExists(atPath: "/usr/sbin/mkfile") ? "/usr/sbin/mkfile" : "/usr/bin/mkfile"
                if FileManager.default.fileExists(atPath: mkfileBin) {
                    let mkProc = Process()
                    mkProc.executableURL = URL(fileURLWithPath: mkfileBin)
                    mkProc.arguments = ["500m", dim4HugeFile.path]
                    try? mkProc.run()
                    mkProc.waitUntilExit()
                }
            }
        }

        let srcSha256 = (!isQuickTest && FileManager.default.fileExists(atPath: dim3EntropyFile.path))
            ? (try await ArchiveEngineFactory.makeHashCalculator().computeHash(filePath: dim3EntropyFile.path, type: .sha256))
            : ""

        let formats: [ArchiveCompressionFormat] = selectedFormats ?? [.zip, .sevenZip, .zst, .tarGz, .tarZst]
        let levels: [ArchiveCompressionLevel] = selectedLevels ?? ArchiveCompressionLevel.allCases

        let allPayloads: [(name: String, path: String, bytes: Int64, sha: String?)] = isQuickTest
            ? [("Small Files (Quick)", dim1Dir.path, Self.getFolderBytes(dim1Dir.path), nil)]
            : [
                ("Small Files (10MB/100 files)", dim1Dir.path, Self.getFolderBytes(dim1Dir.path), nil),
                ("Log Text (10MB)", dim2LogFile.path, (try? FileManager.default.attributesOfItem(atPath: dim2LogFile.path)[.size] as? Int64) ?? 0, nil),
                ("High-Entropy Binary (100MB)", dim3EntropyFile.path, (try? FileManager.default.attributesOfItem(atPath: dim3EntropyFile.path)[.size] as? Int64) ?? 0, srcSha256),
                ("Huge File (5GB)", dim4HugeFile.path, 5 * 1024 * 1024 * 1024, nil)
            ]
        let payloads = allPayloads

        let writer = ArchiveEngineFactory.makeWriter()
        let extractor = ArchiveEngineFactory.makeExtractor()

        var totalSteps = 0
        for payload in payloads {
            for fmt in formats {
                for lvl in levels {
                    if payload.bytes >= 1024 * 1024 * 1024 && !lvl.isQuickPreset { continue }
                    let encOpts: [Bool] = (fmt == .tarGz || fmt == .tarZst || fmt == .zst || payload.bytes >= 1024 * 1024 * 1024) ? [false] : [false, true]
                    totalSteps += encOpts.count
                }
            }
        }

        var currentStep = 0
        progressHandler?("[Benchmark Matrix] Starting dedicated benchmark run... Total: \(totalSteps) permutations")

        for payload in payloads {
            for fmt in formats {
                for lvl in levels {
                    if payload.bytes >= 1024 * 1024 * 1024 && !lvl.isQuickPreset {
                        continue
                    }
                    let encryptionOptions: [Bool] = (fmt == .tarGz || fmt == .tarZst || fmt == .zst || payload.bytes >= 1024 * 1024 * 1024) ? [false] : [false, true]

                    for isEnc in encryptionOptions {
                        currentStep += 1
                        let passwordStr = isEnc ? "P@ssw0rd2026!" : nil
                        let outArc = cacheDir.appendingPathComponent("arc_\(UUID().uuidString).\(fmt.rawValue)")
                        let extractDest = cacheDir.appendingPathComponent("out_\(UUID().uuidString)")
                        defer {
                            try? FileManager.default.removeItem(at: outArc)
                            try? FileManager.default.removeItem(at: extractDest)
                        }

                        progressHandler?("[\(currentStep)/\(totalSteps)] Testing [\(payload.name)] - Format: \(fmt.rawValue) | Level: \(lvl.rawValue) | Encrypted: \(isEnc)")

                        let t0 = PlatformMonotonicTimer.nowSeconds()
                        do {
                            _ = try await ArchivePipelineBuilder()
                                .withWriter(writer)
                                .withOutputPath(outArc.path)
                                .withFormat(fmt)
                                .withLevel(lvl)
                                .addInputPath(payload.path)
                                .withPassword(passwordStr)
                                .executeCreate()
                            let t1 = PlatformMonotonicTimer.nowSeconds()
                            let compDuration = max(0.001, t1 - t0)
                            let compThroughput = (Double(payload.bytes) / (1024.0 * 1024.0)) / compDuration
                            let archiveBytes = (try? FileManager.default.attributesOfItem(atPath: outArc.path)[.size] as? Int64) ?? 0
                            let ratio = payload.bytes > 0 ? (Double(archiveBytes) / Double(payload.bytes)) * 100.0 : 100.0

                            let t2 = PlatformMonotonicTimer.nowSeconds()
                            _ = try await ArchivePipelineBuilder()
                                .withExtractor(extractor)
                                .withArchivePath(outArc.path)
                                .withDestinationDir(extractDest.path)
                                .withPassword(passwordStr)
                                .executeExtract()
                            let t3 = PlatformMonotonicTimer.nowSeconds()
                            let extractDuration = max(0.001, t3 - t2)
                            let extractThroughput = (Double(payload.bytes) / (1024.0 * 1024.0)) / extractDuration

                            BenchmarkSpeedCache.shared.record(
                                format: fmt,
                                level: lvl,
                                compressMBs: compThroughput,
                                extractMBs: extractThroughput,
                                ratioPercent: ratio
                            )

                            var shaMatch = true
                            let targetFileName = URL(fileURLWithPath: payload.path).lastPathComponent
                            var extractedFile = extractDest.appendingPathComponent(targetFileName).path
                            if !FileManager.default.fileExists(atPath: extractedFile) {
                                let altFile = extractDest.appendingPathComponent("decompressed_file").path
                                if FileManager.default.fileExists(atPath: altFile) {
                                    extractedFile = altFile
                                } else if let files = try? FileManager.default.contentsOfDirectory(atPath: extractDest.path), let first = files.first(where: { !$0.hasPrefix(".") }) {
                                    extractedFile = extractDest.appendingPathComponent(first).path
                                }
                            }
                            
                            if FileManager.default.fileExists(atPath: extractedFile) {
                                if let expectedSha = payload.sha {
                                    let outSha = try await ArchiveEngineFactory.makeHashCalculator().computeHash(filePath: extractedFile, type: .sha256)
                                    shaMatch = (outSha == expectedSha)
                                }
                            } else {
                                shaMatch = false
                            }

                            let row = ExhaustiveBenchmarkRow(
                                dimensionName: payload.name,
                                format: fmt,
                                level: lvl,
                                isEncrypted: isEnc,
                                datasetSizeBytes: payload.bytes,
                                archiveSizeBytes: archiveBytes,
                                compressDurationSeconds: compDuration,
                                compressThroughputMBs: compThroughput,
                                extractDurationSeconds: extractDuration,
                                extractThroughputMBs: extractThroughput,
                                compressionRatioPercent: ratio,
                                sha256Matched: shaMatch
                            )
                            results.append(row)

                            let fmtStr = fmt.rawValue.uppercased()
                            let lvlStr = lvl.title
                            let encStr = isEnc ? "AES-256" : "None"
                            let compSpeed = String(format: "%.1f MB/s", compThroughput)
                            let decompSpeed = String(format: "%.1f MB/s", extractThroughput)
                            let timeStr = String(format: "%.3fs / %.3fs", compDuration, extractDuration)
                            let ratioStr = String(format: "%.1f %%", ratio)
                            let shaStr = shaMatch ? "MATCH" : "MISMATCH"

                            let formattedLine = "\(payload.name.padding(toLength: 26, withPad: " ", startingAt: 0)) | \(fmtStr.padding(toLength: 6, withPad: " ", startingAt: 0)) | \(lvlStr.padding(toLength: 10, withPad: " ", startingAt: 0)) | \(encStr.padding(toLength: 6, withPad: " ", startingAt: 0)) | \(compSpeed.padding(toLength: 14, withPad: " ", startingAt: 0)) | \(decompSpeed.padding(toLength: 14, withPad: " ", startingAt: 0)) | \(timeStr.padding(toLength: 18, withPad: " ", startingAt: 0)) | \(ratioStr.padding(toLength: 10, withPad: " ", startingAt: 0)) | \(shaStr)"

                            progressHandler?("ROW:" + formattedLine)
                        } catch {
                            progressHandler?("Warning [Permutation failed] \(payload.name) - \(fmt.rawValue) L\(lvl.rawValue): \(error.localizedDescription)")
                            continue
                        }
                    }
                }
            }
        }

        BenchmarkSpeedCache.shared.saveFullReport(rows: results)
        return results
    }

    private static func getFolderBytes(_ path: String) -> Int64 {
        var total: Int64 = 0
        if let files = try? FileManager.default.contentsOfDirectory(atPath: path) {
            for f in files {
                let p = (path as NSString).appendingPathComponent(f)
                total += (try? FileManager.default.attributesOfItem(atPath: p)[.size] as? Int64) ?? 0
            }
        }
        return total
    }
}
