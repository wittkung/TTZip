// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

extension CompetitorBenchmarkRunner {
    public static func prepareDatasets(hugeSizeBytes: Int64, customFilePaths: [String]?, progressHandler: (@Sendable (String) -> Void)?) throws -> (payloads: [(name: String, path: String, bytes: Int64)], hugeSizeName: String) {
        let cacheDir = FileManager.default.temporaryDirectory.appendingPathComponent("TTZipExhaustiveDatasetCache")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        let dim1Dir = cacheDir.appendingPathComponent("small_files")
        let dim2LogFile = cacheDir.appendingPathComponent("sample_log.log")
        let dim3EntropyFile = cacheDir.appendingPathComponent("high_entropy_100m.bin")
        let dim4HugeFile = cacheDir.appendingPathComponent("huge_file.bin")

        let megabytes = hugeSizeBytes / (1024 * 1024)
        let hugeSizeStr: String
        let hugeSizeName: String
        if megabytes >= 1024 {
            let giga = megabytes / 1024
            hugeSizeStr = "\(giga)g"
            hugeSizeName = "\(giga)GB Huge Payload (\(giga)GB)"
        } else {
            let hugeMb = megabytes
            hugeSizeStr = "\(hugeMb)m"
            hugeSizeName = "\(hugeMb)MB Large Dataset (\(hugeMb)MB)"
        }

        let isDatasetCached = FileManager.default.fileExists(atPath: dim1Dir.path) &&
                              FileManager.default.fileExists(atPath: dim2LogFile.path) &&
                              FileManager.default.fileExists(atPath: dim3EntropyFile.path) &&
                              FileManager.default.fileExists(atPath: dim4HugeFile.path) &&
                              (try? FileManager.default.attributesOfItem(atPath: dim4HugeFile.path)[.size] as? Int64) == hugeSizeBytes

        if !isDatasetCached && (customFilePaths == nil || customFilePaths!.isEmpty) {
            progressHandler?("🛠 [Preparing Benchmark Datasets] Generating test datasets (huge payload size: \(hugeSizeStr))...")
            try? FileManager.default.createDirectory(at: dim1Dir, withIntermediateDirectories: true)
            let sampleText = String(repeating: "Apple Silicon M-Series Ultra High Throughput Test Log Line...\n", count: 2000)
            for i in 0..<100 {
                let fURL = dim1Dir.appendingPathComponent("file_\(i).txt")
                try? sampleText.data(using: .utf8)?.write(to: fURL)
            }

            let logChunk = String(repeating: "[2026-08-08 14:00:00.123] [INFO] [192.168.1.100] User authentication token validated successfully\n", count: 1000).data(using: .utf8)!
            FileManager.default.createFile(atPath: dim2LogFile.path, contents: nil)
            if let logHandle = try? FileHandle(forWritingTo: dim2LogFile) {
                for _ in 0..<100 { logHandle.write(logChunk) }
                try? logHandle.close()
            }

            let randChunk = Data((0..<1024*1024).map { _ in UInt8.random(in: 0...255) })
            FileManager.default.createFile(atPath: dim3EntropyFile.path, contents: nil)
            if let randHandle = try? FileHandle(forWritingTo: dim3EntropyFile) {
                for _ in 0..<100 { randHandle.write(randChunk) }
                try? randHandle.close()
            }

            try? FileManager.default.removeItem(at: dim4HugeFile)
            let mkProc = Process()
            mkProc.executableURL = URL(fileURLWithPath: "/usr/sbin/mkfile")
            mkProc.arguments = [hugeSizeStr, dim4HugeFile.path]
            try? mkProc.run()
            mkProc.waitUntilExit()
        }

        var payloads: [(name: String, path: String, bytes: Int64)] = []
        if let customPaths = customFilePaths, !customPaths.isEmpty {
            for p in customPaths {
                let name = (p as NSString).lastPathComponent
                let bytes = (try? FileManager.default.attributesOfItem(atPath: p)[.size] as? Int64) ?? 0
                payloads.append((name, p, bytes))
            }
        } else {
            payloads = [
                ("Small Files (10MB/100 files)", dim1Dir.path, (try? folderSize(dim1Dir.path)) ?? 0),
                ("Log Text (10MB)", dim2LogFile.path, (try? FileManager.default.attributesOfItem(atPath: dim2LogFile.path)[.size] as? Int64) ?? 0),
                ("High-Entropy Payload (100MB)", dim3EntropyFile.path, (try? FileManager.default.attributesOfItem(atPath: dim3EntropyFile.path)[.size] as? Int64) ?? 0),
                (hugeSizeName, dim4HugeFile.path, hugeSizeBytes)
            ]
        }
        return (payloads, hugeSizeName)
    }
}
