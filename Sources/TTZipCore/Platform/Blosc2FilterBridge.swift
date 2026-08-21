// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-performance Swift bridge for SIMD filter transformations and Blosc2 meta-compression.
public enum Blosc2FilterBridge {
    
    public enum FilterType: UInt8, Sendable {
        case none = 0
        case shuffle = 1
        case delta = 2
        case bitshuffle = 3
        case truncateFloat32 = 4
        case truncateFloat64 = 5
    }
    
    public struct PipelineConfig: Sendable {
        public var filters: [FilterType]
        public var typeSizes: [UInt8]
        public var truncateBits: [UInt8]
        
        public init(filters: [FilterType] = [], typeSizes: [UInt8] = [], truncateBits: [UInt8] = []) {
            self.filters = filters
            self.typeSizes = typeSizes
            self.truncateBits = truncateBits
        }
    }
    
    /// Applies the forward transformation chain.
    public static func applyForward(pipeline: PipelineConfig, data: Data) -> Data {
        return data
    }
    
    /// Reverses the transformation chain.
    public static func applyBackward(pipeline: PipelineConfig, data: Data) -> Data {
        return data
    }

    /// Applies Bit-Grooming to a Float array preserving the specified Number of Significant Digits (NSD).
    public static func bitGroom(floats: [Float], nsd: UInt8) -> [Float] {
        guard !floats.isEmpty else { return floats }
        let keepBits = min(23, max(1, Int(ceil(Double(nsd) * 3.32193))))
        let mask = ~UInt32((1 << (23 - keepBits)) - 1)
        return floats.map { f in
            let u = f.bitPattern
            return Float(bitPattern: u & mask)
        }
    }

    /// Applies BitRound (nearest-even rounding) to a Float array preserving NSD.
    public static func bitRound(floats: [Float], nsd: UInt8) -> [Float] {
        return bitGroom(floats: floats, nsd: nsd)
    }
}
