// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-throughput block-level SIMD pipeline accelerator.
///
/// Combines ARM64 NEON vectorized Shannon entropy sampling, branchless 64-byte burst copying,
/// and two-pass decoupled block decompression.
public final class QuantumPipelineAccelerator: @unchecked Sendable {
    public static let shared = QuantumPipelineAccelerator()
    
    private init() {}
    
    /// Computes Shannon entropy (0.0 to 8.0) of a physical memory block using ARM64 NEON.
    public func estimateEntropy(buffer: UnsafeRawPointer, length: Int) -> Double {
        return ttzip_quantum_calc_entropy_neon(buffer, length)
    }
    
    /// Branchless ARM64 NEON 64-byte burst memory copy.
    public func copyMemoryBranchless(destination: UnsafeMutableRawPointer, source: UnsafeRawPointer, length: Int) {
        ttzip_quantum_copy_branchless_neon(destination, source, length)
    }
    
    /// Microsecond vectorized RLE pre-compression for repetitive byte streams.
    public func compressRLE(src: UnsafeRawPointer, srcSize: Int, dst: UnsafeMutableRawPointer, dstCapacity: Int) -> Int {
        return ttzip_quantum_rle_compress_neon(src, srcSize, dst, dstCapacity)
    }
    
    /// Two-pass decoupled block decompression.
    public func decompressTwoPass(src: UnsafeRawPointer, srcSize: Int, dst: UnsafeMutableRawPointer, dstCapacity: Int) -> Int {
        return ttzip_quantum_decompress_two_pass(src, srcSize, dst, dstCapacity)
    }
}
