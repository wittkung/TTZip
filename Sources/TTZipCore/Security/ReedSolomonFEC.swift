// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-performance Systematic Cauchy Reed-Solomon Erasure Coding over GF(2^8).
///
/// Implements transparent forward error correction (FEC) parity computation and self-healing
/// reconstruction with zero pointer escaping and single-scope ContiguousArray memory pinning.
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
    /// Computes M parity slices from K data slices of size sliceSize using SIMD acceleration.
    /// Memory-level single-scope pinning via ContiguousArray completely eliminates pointer escapes and UAF hazards.
    public static func encode(dataSlices: [Data], parityCount M: Int) -> [Data] {
        let K = dataSlices.count
        guard K > 0, M > 0 else { return [] }
        let sliceSize = dataSlices[0].count
        guard sliceSize > 0 else { return [] }

        var contiguousData = ContiguousArray<UInt8>()
        contiguousData.reserveCapacity(K * sliceSize)
        for slice in dataSlices {
            if slice.count == sliceSize {
                contiguousData.append(contentsOf: slice)
            } else if slice.count < sliceSize {
                var padded = slice
                padded.append(contentsOf: [UInt8](repeating: 0, count: sliceSize - slice.count))
                contiguousData.append(contentsOf: padded)
            } else {
                contiguousData.append(contentsOf: slice.prefix(sliceSize))
            }
        }

        var flatParity = ContiguousArray<UInt8>(repeating: 0, count: M * sliceSize)

        let success = contiguousData.withUnsafeBufferPointer { dBuf -> Bool in
            flatParity.withUnsafeMutableBufferPointer { pBuf -> Bool in
                guard let dBase = dBuf.baseAddress, let pBase = pBuf.baseAddress else { return false }

                var dataPointers: [UnsafePointer<UInt8>?] = (0..<K).map { dBase.advanced(by: $0 * sliceSize) }
                var parityPointers: [UnsafeMutablePointer<UInt8>?] = (0..<M).map { pBase.advanced(by: $0 * sliceSize) }

                return dataPointers.withUnsafeBufferPointer { dPtrs in
                    parityPointers.withUnsafeMutableBufferPointer { pPtrs in
                        guard let dPtrsBase = dPtrs.baseAddress, let pPtrsBase = pPtrs.baseAddress else { return false }
                        return ttzip_rust_rs_encode(
                            dPtrsBase,
                            K,
                            pPtrsBase,
                            M,
                            sliceSize
                        ) == 0
                    }
                }
            }
        }

        guard success else { return [] }

        var result = [Data]()
        result.reserveCapacity(M)
        for i in 0..<M {
            let start = i * sliceSize
            let sliceBytes = Array(flatParity[start..<(start + sliceSize)])
            result.append(Data(sliceBytes))
        }
        return result
    }

    // MARK: - Decode & Reconstruct
    /// Reconstructs corrupted data slices given available intact slices and parity slices via Rust C-ABI.
    /// Memory-level single-scope pinning via ContiguousArray completely eliminates pointer escapes and UAF hazards.
    public static func decode(
        intactSlices: [Int: Data],
        totalK: Int,
        totalM: Int,
        sliceSize: Int
    ) -> [Int: Data]? {
        guard sliceSize > 0, totalK > 0, totalM > 0 else { return nil }
        let missingIndices = (0..<totalK).filter { intactSlices[$0] == nil }
        if missingIndices.isEmpty {
            return intactSlices
        }

        let missingCount = missingIndices.count
        if missingCount > totalM {
            return nil // Erasure count exceeds available parity capacity
        }

        let availableEntries = intactSlices.sorted(by: { $0.key < $1.key })
        if availableEntries.count < totalK {
            return nil // Insufficient available shards
        }

        let chosenAvailable = Array(availableEntries.prefix(totalK))
        let sliceIndices: [Int32] = chosenAvailable.map { Int32($0.key) }
        let missingIndices32: [Int32] = missingIndices.map { Int32($0) }

        var contiguousAvailable = ContiguousArray<UInt8>()
        contiguousAvailable.reserveCapacity(totalK * sliceSize)
        for item in chosenAvailable {
            if item.value.count == sliceSize {
                contiguousAvailable.append(contentsOf: item.value)
            } else if item.value.count < sliceSize {
                var padded = item.value
                padded.append(contentsOf: [UInt8](repeating: 0, count: sliceSize - padded.count))
                contiguousAvailable.append(contentsOf: padded)
            } else {
                contiguousAvailable.append(contentsOf: item.value.prefix(sliceSize))
            }
        }

        var flatReconstructed = ContiguousArray<UInt8>(repeating: 0, count: missingCount * sliceSize)

        let decodeSuccess = contiguousAvailable.withUnsafeBufferPointer { aBuf -> Bool in
            flatReconstructed.withUnsafeMutableBufferPointer { rBuf -> Bool in
                sliceIndices.withUnsafeBufferPointer { sIdxBuf -> Bool in
                    missingIndices32.withUnsafeBufferPointer { mIdxBuf -> Bool in
                        guard let aBase = aBuf.baseAddress,
                              let rBase = rBuf.baseAddress,
                              let sIdxBase = sIdxBuf.baseAddress,
                              let mIdxBase = mIdxBuf.baseAddress else { return false }

                        var availablePointers: [UnsafePointer<UInt8>?] = (0..<totalK).map { aBase.advanced(by: $0 * sliceSize) }
                        var reconstructedPointers: [UnsafeMutablePointer<UInt8>?] = (0..<missingCount).map { rBase.advanced(by: $0 * sliceSize) }

                        return availablePointers.withUnsafeBufferPointer { aPtrs in
                            reconstructedPointers.withUnsafeMutableBufferPointer { rPtrs in
                                guard let aPtrsBase = aPtrs.baseAddress,
                                      let rPtrsBase = rPtrs.baseAddress else { return false }
                                return ttzip_rust_rs_decode(
                                    aPtrsBase,
                                    sIdxBase,
                                    totalK,
                                    totalK,
                                    totalM,
                                    mIdxBase,
                                    missingCount,
                                    rPtrsBase,
                                    sliceSize
                                ) == 0
                            }
                        }
                    }
                }
            }
        }

        guard decodeSuccess else { return nil }

        var result = intactSlices
        for (idx, missingCol) in missingIndices.enumerated() {
            let start = idx * sliceSize
            let sliceBytes = Array(flatReconstructed[start..<(start + sliceSize)])
            result[missingCol] = Data(sliceBytes)
        }
        return result
    }
}
