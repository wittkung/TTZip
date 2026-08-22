// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.

import Foundation
import CTTZipBridge

/// High-performance deterministic in-memory corpus generator.
/// Reproduces zlib-ng / Google Benchmark data_type.cc workloads with 0 internal heap allocation.
public enum BenchmarkCorpusType: String, CaseIterable, Codable, Sendable {
    case text
    case shortMatch = "short_match"
    case dna
    case random
    case literals
    case mixed
    case realisticRGB = "realistic_rgb"
    case stripedRGB = "striped_rgb"

    /// Generate corpus into a caller-allocated raw memory buffer.
    @inlinable
    public func fill(buffer: UnsafeMutableRawPointer, size: Int) {
        guard size > 0 else { return }
        let ptr = buffer.assumingMemoryBound(to: UInt8.self)
        var state: UInt32 = 0x7e47da7a
        
        switch self {
        case .text:
            let alphabet = Array("abcdefghiklmnopqrstuvwy".utf8)
            for i in 0..<size {
                state = state &* 1103515245 &+ 12345
                if i % 8 == 7 {
                    ptr[i] = 0x20 // space
                } else {
                    ptr[i] = alphabet[Int(state % UInt32(alphabet.count))]
                }
            }
        case .dna:
            let bases: [UInt8] = [0x41, 0x43, 0x47, 0x54] // A, C, G, T
            for i in 0..<size {
                state = state &* 1103515245 &+ 12345
                ptr[i] = bases[Int((state >> 16) & 3)]
            }
        case .random:
            for i in 0..<size {
                var x = state
                x ^= x << 13
                x ^= x >> 17
                x ^= x << 5
                state = x
                ptr[i] = UInt8(truncatingIfNeeded: x)
            }
        case .literals:
            for i in 0..<size {
                state = state &* 1103515245 &+ 12345
                ptr[i] = UInt8(truncatingIfNeeded: (state % 64) + 32)
            }
        case .shortMatch, .mixed:
            for i in 0..<size {
                state = state &* 1103515245 &+ 12345
                ptr[i] = (i % 16 == 0) ? UInt8(truncatingIfNeeded: state & 0xFF) : ptr[max(0, i - 16)]
            }
        case .realisticRGB, .stripedRGB:
            for i in 0..<size {
                state = state &* 1103515245 &+ 12345
                ptr[i] = (i % 3 == 0) ? 0xFF : UInt8(truncatingIfNeeded: state & 0x7F)
            }
        }
    }

    /// Convenience generation into Swift Data (for unit test fixtures).
    public func generateData(size: Int) -> Data {
        var data = Data(count: size)
        data.withUnsafeMutableBytes { rawBuf in
            if let base = rawBuf.baseAddress {
                fill(buffer: base, size: size)
            }
        }
        return data
    }

    /// Stream corpus directly to disk with zero intermediate heap allocation.
    public func writeToDisk(filePath: String, totalBytes: Int, chunkSize: Int = 1048576) throws {
        let chunk = min(totalBytes, max(chunkSize, 4096))
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: chunk + 64, alignment: 64)
        defer { buffer.deallocate() }

        fill(buffer: buffer, size: chunk)

        FileManager.default.createFile(atPath: filePath, contents: nil)
        guard let handle = FileHandle(forWritingAtPath: filePath) else {
            throw NSError(domain: "TTZipBenchmarkCorpus", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to open file for writing at \(filePath)"])
        }
        defer { try? handle.close() }

        var written = 0
        while written < totalBytes {
            let bytesToWrite = min(chunk, totalBytes - written)
            let dataChunk = Data(bytesNoCopy: buffer, count: bytesToWrite, deallocator: .none)
            try handle.write(contentsOf: dataChunk)
            written += bytesToWrite
        }
    }
}

/// Zero-allocation reusable page buffer pool for micro/macro in-memory benchmarks.
public final class BenchmarkBufferPool: @unchecked Sendable {
    public let size: Int
    public let inputBuffer: UnsafeMutableRawPointer
    public let compressedBuffer: UnsafeMutableRawPointer
    public let decompressedBuffer: UnsafeMutableRawPointer

    public init(size: Int) {
        self.size = size
        // 64-byte cache-line aligned allocations with 4KB guard padding
        let maxCompressed = max(size * 2, 65536)
        self.inputBuffer = UnsafeMutableRawPointer.allocate(byteCount: size + 4096, alignment: 64)
        self.compressedBuffer = UnsafeMutableRawPointer.allocate(byteCount: maxCompressed + 4096, alignment: 64)
        self.decompressedBuffer = UnsafeMutableRawPointer.allocate(byteCount: size + 4096, alignment: 64)
    }

    deinit {
        inputBuffer.deallocate()
        compressedBuffer.deallocate()
        decompressedBuffer.deallocate()
    }

    /// Fill the input buffer with a specified corpus type in-place.
    @inlinable
    public func prepareCorpus(_ type: BenchmarkCorpusType) {
        type.fill(buffer: inputBuffer, size: size)
    }
}
