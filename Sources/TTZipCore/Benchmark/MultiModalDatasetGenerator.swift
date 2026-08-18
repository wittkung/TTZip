// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-performance deterministic multi-modal dataset generator for benchmark evaluation.
public enum MultiModalDatasetGenerator {

    /// Generates a deterministic Float32 sensor dataset (sinusoids + linear drift) using POSIX streaming.
    public static func generateFloat32SensorDataset(destinationPath: String, sizeBytes: Int) throws {
        guard let fileHandle = FileHandle(forWritingAtPath: destinationPath) ?? {
            FileManager.default.createFile(atPath: destinationPath, contents: nil)
            return FileHandle(forWritingAtPath: destinationPath)
        }() else {
            throw ArchiveError.readFailed(code: -1)
        }
        defer { try? fileHandle.close() }

        let floatCount = sizeBytes / MemoryLayout<Float>.size
        let chunkSize = 16384 // 64KB chunks
        var floats = [Float](repeating: 0, count: chunkSize)

        var writtenFloats = 0
        while writtenFloats < floatCount {
            let countToWrite = min(chunkSize, floatCount - writtenFloats)
            for i in 0..<countToWrite {
                let idx = writtenFloats + i
                floats[i] = sin(Float(idx) * 0.05) * 50.0 + Float(idx % 100) * 0.00314159
            }
            let chunkData = Data(bytes: floats, count: countToWrite * MemoryLayout<Float>.size)
            try fileHandle.write(contentsOf: chunkData)
            writtenFloats += countToWrite
        }
    }

    /// Generates a high-entropy pseudo-random binary stream via SplitMix64 PRNG.
    public static func generateHighEntropyBinaryDataset(destinationPath: String, sizeBytes: Int) throws {
        guard let fileHandle = FileHandle(forWritingAtPath: destinationPath) ?? {
            FileManager.default.createFile(atPath: destinationPath, contents: nil)
            return FileHandle(forWritingAtPath: destinationPath)
        }() else {
            throw ArchiveError.readFailed(code: -1)
        }
        defer { try? fileHandle.close() }

        var state: UInt64 = 0x853c49e6748fea9b
        let chunkSize = 65536
        var chunkBuf = [UInt8](repeating: 0, count: chunkSize)

        var remaining = sizeBytes
        while remaining > 0 {
            let n = min(chunkSize, remaining)
            for i in stride(from: 0, to: n, by: 8) {
                state = state &+ 0x9e3779b97f4a7c15
                var z = state
                z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
                z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
                let rand64 = z ^ (z >> 31)
                
                withUnsafeBytes(of: rand64) { raw in
                    for b in 0..<min(8, n - i) {
                        chunkBuf[i + b] = raw[b]
                    }
                }
            }
            try fileHandle.write(contentsOf: Data(chunkBuf[0..<n]))
            remaining -= n
        }
    }

    /// Generates a sparse file with large unallocated zero holes.
    public static func generateSparseExtentDataset(destinationPath: String, virtualSizeBytes: Int64, allocatedHeaderBytes: Int = 65536) throws {
        FileManager.default.createFile(atPath: destinationPath, contents: nil)
        guard let fileHandle = FileHandle(forWritingAtPath: destinationPath) else {
            throw ArchiveError.readFailed(code: -1)
        }
        defer { try? fileHandle.close() }

        // Write non-zero header
        var header = [UInt8](repeating: 0x5A, count: allocatedHeaderBytes)
        try fileHandle.write(contentsOf: Data(header))

        // Seek to end and truncate/write last byte to form sparse hole
        try fileHandle.seek(toOffset: UInt64(virtualSizeBytes - 1))
        var tailByte: UInt8 = 0x5A
        try fileHandle.write(contentsOf: Data([tailByte]))
    }

    /// Generates a repetitive JSON log stream.
    public static func generateStructuredJsonDataset(destinationPath: String, recordCount: Int) throws {
        guard let fileHandle = FileHandle(forWritingAtPath: destinationPath) ?? {
            FileManager.default.createFile(atPath: destinationPath, contents: nil)
            return FileHandle(forWritingAtPath: destinationPath)
        }() else {
            throw ArchiveError.readFailed(code: -1)
        }
        defer { try? fileHandle.close() }

        let sampleJson = "{\"timestamp\": 1723982400, \"host\": \"m3max-worker-node\", \"service\": \"ingress-proxy\", \"status\": 200, \"latency_ms\": 1.45, \"level\": \"INFO\"}\n"
        let sampleData = sampleJson.data(using: .utf8)!

        var batchData = Data()
        for _ in 0..<min(100, recordCount) {
            batchData.append(sampleData)
        }

        var written = 0
        while written < recordCount {
            let n = min(100, recordCount - written)
            if n == 100 {
                try fileHandle.write(contentsOf: batchData)
            } else {
                var partial = Data()
                for _ in 0..<n { partial.append(sampleData) }
                try fileHandle.write(contentsOf: partial)
            }
            written += n
        }
    }
}
