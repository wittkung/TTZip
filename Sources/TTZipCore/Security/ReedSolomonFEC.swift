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
    
    // MARK: - GF(2^8) Galois Field Arithmetic Tables
    private static let expTable: [UInt8] = {
        var table = [UInt8](repeating: 0, count: 512)
        var x: UInt16 = 1
        for i in 0..<255 {
            table[i] = UInt8(x)
            table[i + 255] = UInt8(x)
            x = (x << 1) ^ (x >= 128 ? 0x11D : 0)
        }
        return table
    }()
    
    private static let logTable: [UInt8] = {
        var table = [UInt8](repeating: 0, count: 256)
        for i in 0..<255 {
            table[Int(expTable[i])] = UInt8(i)
        }
        return table
    }()
    
    @inline(__always)
    public static func gfMul(_ a: UInt8, _ b: UInt8) -> UInt8 {
        if a == 0 || b == 0 { return 0 }
        let logSum = Int(logTable[Int(a)]) + Int(logTable[Int(b)])
        return expTable[logSum]
    }
    
    @inline(__always)
    public static func gfDiv(_ a: UInt8, _ b: UInt8) -> UInt8 {
        if a == 0 { return 0 }
        if b == 0 { return 0 }
        let logDiff = Int(logTable[Int(a)]) - Int(logTable[Int(b)]) + 255
        return expTable[logDiff]
    }
    
    @inline(__always)
    public static func gfInv(_ a: UInt8) -> UInt8 {
        if a == 0 { return 0 }
        return expTable[255 - Int(logTable[Int(a)])]
    }
    
    // MARK: - Cauchy Matrix Generation
    /// Generates an M x K Cauchy generator matrix in GF(2^8).
    /// Element (i, j) = 1 / (X_i XOR Y_j), where X and Y are disjoint sets.
    public static func createCauchyMatrix(rows M: Int, cols K: Int) -> [[UInt8]] {
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
    /// Computes M parity slices from K data slices of size sliceSize.
    public static func encode(dataSlices: [Data], parityCount M: Int) -> [Data] {
        let K = dataSlices.count
        guard K > 0, M > 0 else { return [] }
        let sliceSize = dataSlices[0].count
        
        let matrix = createCauchyMatrix(rows: M, cols: K)
        var paritySlices = [Data]()
        paritySlices.reserveCapacity(M)
        
        for i in 0..<M {
            var parity = [UInt8](repeating: 0, count: sliceSize)
            let rowCoeffs = matrix[i]
            
            for j in 0..<K {
                let coeff = rowCoeffs[j]
                if coeff == 0 { continue }
                dataSlices[j].withUnsafeBytes { dataRaw in
                    guard let dataPtr = dataRaw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
                    for byteIdx in 0..<sliceSize {
                        parity[byteIdx] ^= gfMul(dataPtr[byteIdx], coeff)
                    }
                }
            }
            paritySlices.append(Data(parity))
        }
        
        return paritySlices
    }
    
    // MARK: - Decode & Reconstruct
    /// Reconstructs corrupted data slices given available intact slices and parity slices.
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
        let availableParities = (0..<totalM).compactMap { pIdx -> (Int, Data)? in
            let globalParityKey = totalK + pIdx
            if let pData = intactSlices[globalParityKey] {
                return (pIdx, pData)
            }
            return nil
        }
        
        if availableParities.count < missingCount {
            return nil // Erasure count exceeds parity capacity
        }
        
        let fullMatrix = createCauchyMatrix(rows: totalM, cols: totalK)
        
        // Build submatrix for missing variables
        var subMatrix = [[UInt8]](repeating: [UInt8](repeating: 0, count: missingCount), count: missingCount)
        var rhsSlices = [Data]()
        
        for (subRow, (parityIdx, parityData)) in availableParities.prefix(missingCount).enumerated() {
            var rhs = [UInt8](parityData)
            
            // Subtract contributions from available data slices
            for col in 0..<totalK {
                if let knownData = intactSlices[col] {
                    let coeff = fullMatrix[parityIdx][col]
                    knownData.withUnsafeBytes { knownRaw in
                        guard let knownPtr = knownRaw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
                        for byteIdx in 0..<sliceSize {
                            rhs[byteIdx] ^= gfMul(knownPtr[byteIdx], coeff)
                        }
                    }
                }
            }
            rhsSlices.append(Data(rhs))
            
            for (subCol, missingCol) in missingIndices.enumerated() {
                subMatrix[subRow][subCol] = fullMatrix[parityIdx][missingCol]
            }
        }
        
        // Invert submatrix using Gaussian Elimination
        guard let invertedMatrix = invertMatrix(subMatrix, n: missingCount) else {
            return nil
        }
        
        var reconstructed = intactSlices
        for (i, missingCol) in missingIndices.enumerated() {
            var recoveredSlice = [UInt8](repeating: 0, count: sliceSize)
            for j in 0..<missingCount {
                let coeff = invertedMatrix[i][j]
                rhsSlices[j].withUnsafeBytes { rhsRaw in
                    guard let rhsPtr = rhsRaw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
                    for byteIdx in 0..<sliceSize {
                        recoveredSlice[byteIdx] ^= gfMul(rhsPtr[byteIdx], coeff)
                    }
                }
            }
            reconstructed[missingCol] = Data(recoveredSlice)
        }
        
        return reconstructed
    }
    
    // MARK: - Matrix Inversion via Gauss-Jordan in GF(2^8)
    private static func invertMatrix(_ input: [[UInt8]], n: Int) -> [[UInt8]]? {
        var a = input
        var inv = [[UInt8]](repeating: [UInt8](repeating: 0, count: n), count: n)
        for i in 0..<n { inv[i][i] = 1 }
        
        for i in 0..<n {
            // Find pivot
            var pivotRow = i
            while pivotRow < n && a[pivotRow][i] == 0 {
                pivotRow += 1
            }
            if pivotRow == n { return nil } // Singular matrix
            
            if pivotRow != i {
                a.swapAt(i, pivotRow)
                inv.swapAt(i, pivotRow)
            }
            
            let pivotVal = a[i][i]
            let pivotInv = gfInv(pivotVal)
            
            for j in 0..<n {
                a[i][j] = gfMul(a[i][j], pivotInv)
                inv[i][j] = gfMul(inv[i][j], pivotInv)
            }
            
            for k in 0..<n {
                if k != i {
                    let factor = a[k][i]
                    if factor != 0 {
                        for j in 0..<n {
                            a[k][j] ^= gfMul(a[i][j], factor)
                            inv[k][j] ^= gfMul(inv[i][j], factor)
                        }
                    }
                }
            }
        }
        return inv
    }
}
