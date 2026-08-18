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
        let header = [UInt8](repeating: 0x5A, count: allocatedHeaderBytes)
        try fileHandle.write(contentsOf: Data(header))

        // Seek to end and truncate/write last byte to form sparse hole
        try fileHandle.seek(toOffset: UInt64(virtualSizeBytes - 1))
        let tailByte: UInt8 = 0x5A
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

    /// Generates a deterministic binary executable / machine-code byte stream.
    public static func generateDeterministicBinaryDataset(destinationPath: String, sizeBytes: Int) throws {
        guard let fileHandle = FileHandle(forWritingAtPath: destinationPath) ?? {
            FileManager.default.createFile(atPath: destinationPath, contents: nil)
            return FileHandle(forWritingAtPath: destinationPath)
        }() else {
            throw ArchiveError.readFailed(code: -1)
        }
        defer { try? fileHandle.close() }

        let opcodes: [UInt32] = [
            0xA9BF7BFD, // stp x29, x30, [sp, #-16]!
            0x910003FD, // mov x29, sp
            0x52800000, // mov w0, #0
            0xD65F03C0, // ret
            0x94000004, // bl +16
            0xB94003E0, // ldr w0, [sp]
            0x11000400, // add w0, w0, #1
            0x7100281F  // cmp w0, #10
        ]
        var block = Data()
        block.reserveCapacity(65536)
        while block.count < 65536 {
            let op = opcodes[(block.count / 4) % opcodes.count]
            var val = op
            block.append(Data(bytes: &val, count: 4))
        }

        var remaining = sizeBytes
        while remaining > 0 {
            let chunk = min(remaining, block.count)
            try fileHandle.write(contentsOf: block.subdata(in: 0..<chunk))
            remaining -= chunk
        }
    }

    /// Generates a 100MB 5-Tier compound mixed-modality dataset.
    public static func generateCompoundMixed100MBDataset(destinationPath: String, textSourcePath: String?) throws {
        let tempDir = NSTemporaryDirectory() + "mixed_build_\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let pText = "\(tempDir)/part_text.bin"
        let pBin = "\(tempDir)/part_bin.bin"
        let pJson = "\(tempDir)/part_json.bin"
        let pFloat = "\(tempDir)/part_float.bin"
        let pEntropy = "\(tempDir)/part_entropy.bin"

        let target20MB = 20_000_000

        // 1. Text 20MB
        if let src = textSourcePath, let data = try? Data(contentsOf: URL(fileURLWithPath: src)), data.count >= target20MB {
            try data.subdata(in: 0..<target20MB).write(to: URL(fileURLWithPath: pText))
        } else {
            let cfg = SyntheticXmlCorpusConfig(totalByteCount: Int64(target20MB), repeatDistanceBytes: 4*1024*1024, repeatProbability: 0.7, seed: 0x12345)
            try SyntheticXmlCorpusGenerator.generate(config: cfg, to: URL(fileURLWithPath: pText))
        }

        // 2. Binary 20MB
        try generateDeterministicBinaryDataset(destinationPath: pBin, sizeBytes: target20MB)

        // 3. JSON 20MB
        try generateStructuredJsonDataset(destinationPath: pJson, recordCount: 140_000)

        // 4. Float32 20MB
        try generateFloat32SensorDataset(destinationPath: pFloat, sizeBytes: target20MB)

        // 5. High Entropy 20MB
        try generateHighEntropyBinaryDataset(destinationPath: pEntropy, sizeBytes: target20MB)

        // Concatenate all 5 parts into destinationPath
        FileManager.default.createFile(atPath: destinationPath, contents: nil)
        guard let outHandle = FileHandle(forWritingAtPath: destinationPath) else {
            throw ArchiveError.readFailed(code: -1)
        }
        defer { try? outHandle.close() }

        for p in [pText, pBin, pJson, pFloat, pEntropy] {
            if let d = try? Data(contentsOf: URL(fileURLWithPath: p)) {
                let toWrite = d.count > target20MB ? d.subdata(in: 0..<target20MB) : d
                try outHandle.write(contentsOf: toWrite)
            }
        }
    }
}
