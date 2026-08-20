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

    @inlinable
    public var cEnumValue: ttzip_corpus_type_t {
        switch self {
        case .text: return TTZIP_CORPUS_TEXT
        case .shortMatch: return TTZIP_CORPUS_SHORT_MATCH
        case .dna: return TTZIP_CORPUS_DNA
        case .random: return TTZIP_CORPUS_RANDOM
        case .literals: return TTZIP_CORPUS_LITERALS
        case .mixed: return TTZIP_CORPUS_MIXED
        case .realisticRGB: return TTZIP_CORPUS_REALISTIC_RGB
        case .stripedRGB: return TTZIP_CORPUS_STRIPED_RGB
        }
    }

    /// Generate corpus into a caller-allocated raw memory buffer.
    @inlinable
    public func fill(buffer: UnsafeMutableRawPointer, size: Int) {
        ttzip_generate_corpus(cEnumValue, buffer, size)
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
