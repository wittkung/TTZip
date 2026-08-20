// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-performance Systematic Cauchy Reed-Solomon Erasure Coding over GF(2^8) / GF(2^16).
///
/// Implements transparent forward error correction (FEC) parity computation and self-healing
/// reconstruction for archival storage resilience against bit-rot and media sector damage.
public final class ReedSolomonFEC: @unchecked Sendable {
    
    // MARK: - GF(2^8) Galois Field Arithmetic Bridge
    
    @inline(__always)
    public static func gfMul(_ a: UInt8, _ b: UInt8) -> UInt8 {
        return ttzip_rs_gf_mul(a, b)
    }
    
    @inline(__always)
    public static func gfDiv(_ a: UInt8, _ b: UInt8) -> UInt8 {
        if a == 0 || b == 0 { return 0 }
        return ttzip_rs_gf_mul(a, ttzip_rs_gf_inv(b))
    }
    
    @inline(__always)
    public static func gfInv(_ a: UInt8) -> UInt8 {
        return ttzip_rs_gf_inv(a)
    }
    
    // MARK: - Cauchy Matrix Generation
    /// Generates an M x K Cauchy generator matrix in GF(2^8).
    /// Element (i, j) = 1 / (X_i XOR Y_j), where X and Y are disjoint sets.
    public static func createCauchyMatrix(rows M: Int, cols K: Int) -> [[UInt8]] {
        var flatMatrix = [UInt8](repeating: 0, count: M * K)
        let res = flatMatrix.withUnsafeMutableBufferPointer { ptr in
            ttzip_rs_create_cauchy_matrix(M, K, ptr.baseAddress)
        }
        if res == 0 {
            var matrix = [[UInt8]](repeating: [UInt8](repeating: 0, count: K), count: M)
            for i in 0..<M {
                for j in 0..<K {
                    matrix[i][j] = flatMatrix[i * K + j]
                }
            }
            return matrix
        }

        var matrix = [[UInt8]](repeating: [UInt8](repeating: 0, count: K), count: M)
        for i in 0..<M {
            let xi = UInt8(i)
            for j in 0..<K {
                let yj = UInt8(M + j)
                let diff = xi ^ yj
                matrix[i][j] = gfInv(diff)
            }
        }
        return matrix
    }
    
    // MARK: - Encode
    /// Computes M parity slices from K data slices of size sliceSize using C11 ARM NEON acceleration.
    public static func encode(dataSlices: [Data], parityCount M: Int) -> [Data] {
        let K = dataSlices.count
        guard K > 0, M > 0 else { return [] }
        let sliceSize = dataSlices[0].count
        
        var flatParity = [UInt8](repeating: 0, count: M * sliceSize)
        var dataPointers = [UnsafePointer<UInt8>?](repeating: nil, count: K)
        
        for j in 0..<K {
            dataSlices[j].withUnsafeBytes { raw in
                dataPointers[j] = raw.baseAddress?.assumingMemoryBound(to: UInt8.self)
            }
        }
        
        let encodeSuccess = flatParity.withUnsafeMutableBufferPointer { pBuf -> Bool in
            guard let pBase = pBuf.baseAddress else { return false }
            var parityPointers = [UnsafeMutablePointer<UInt8>?](repeating: nil, count: M)
            for i in 0..<M {
                parityPointers[i] = pBase.advanced(by: i * sliceSize)
            }
            
            return dataPointers.withUnsafeBufferPointer { dPtrs in
                parityPointers.withUnsafeBufferPointer { pPtrs in
                    guard let dBase = dPtrs.baseAddress, let pBasePtrs = pPtrs.baseAddress else { return false }
                    return ttzip_rs_encode_neon(
                        dBase,
                        K,
                        pBasePtrs,
                        M,
                        sliceSize
                    ) == 0
                }
            }
        }
        
        guard encodeSuccess else { return [] }
        
        var result = [Data]()
        result.reserveCapacity(M)
        for i in 0..<M {
            let start = i * sliceSize
            let sliceData = Data(flatParity[start..<(start + sliceSize)])
            result.append(sliceData)
        }
        return result
    }
    
    // MARK: - Decode & Reconstruct
    /// Reconstructs corrupted data slices given available intact slices and parity slices via C11 ARM NEON.
    public static func decode(
        intactSlices: [Int: Data],
        totalK: Int,
        totalM: Int,
        sliceSize: Int
    ) -> [Int: Data]? {
        let missingIndices = (0..<totalK).filter { intactSlices[$0] == nil }
        if missingIndices.isEmpty {
            return intactSlices
        }
        
        let missingCount = missingIndices.count
        let availableEntries = intactSlices.sorted(by: { $0.key < $1.key })
        if availableEntries.count < totalK {
            return nil // Erasure count exceeds available parity capacity
        }
        
        let chosenAvailable = Array(availableEntries.prefix(totalK))
        let sliceIndices: [Int32] = chosenAvailable.map { Int32($0.key) }
        let missingIndices32: [Int32] = missingIndices.map { Int32($0) }
        
        var availablePointers = [UnsafePointer<UInt8>?](repeating: nil, count: totalK)
        for i in 0..<totalK {
            chosenAvailable[i].value.withUnsafeBytes { raw in
                availablePointers[i] = raw.baseAddress?.assumingMemoryBound(to: UInt8.self)
            }
        }
        
        var flatReconstructed = [UInt8](repeating: 0, count: missingCount * sliceSize)
        
        let decodeSuccess = flatReconstructed.withUnsafeMutableBufferPointer { rBuf -> Bool in
            guard let rBase = rBuf.baseAddress else { return false }
            var reconstructedPointers = [UnsafeMutablePointer<UInt8>?](repeating: nil, count: missingCount)
            for i in 0..<missingCount {
                reconstructedPointers[i] = rBase.advanced(by: i * sliceSize)
            }
            
            return availablePointers.withUnsafeBufferPointer { aPtrs in
                sliceIndices.withUnsafeBufferPointer { sIdxPtrs in
                    missingIndices32.withUnsafeBufferPointer { mIdxPtrs in
                        reconstructedPointers.withUnsafeBufferPointer { rPtrs in
                            guard let aBase = aPtrs.baseAddress,
                                  let sBase = sIdxPtrs.baseAddress,
                                  let mBase = mIdxPtrs.baseAddress,
                                  let rBasePtrs = rPtrs.baseAddress else { return false }
                            return ttzip_rs_decode_neon(
                                aBase,
                                sBase,
                                totalK,
                                totalK,
                                totalM,
                                mBase,
                                missingCount,
                                rBasePtrs,
                                sliceSize
                            ) == 0
                        }
                    }
                }
            }
        }
        
        guard decodeSuccess else { return nil }
        
        var result = intactSlices
        for (idx, missingCol) in missingIndices.enumerated() {
            let start = idx * sliceSize
            result[missingCol] = Data(flatReconstructed[start..<(start + sliceSize)])
        }
        return result
    }
}
