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
    
    /// Applies the forward transformation chain with zero dynamic heap allocation.
    public static func applyForward(pipeline: PipelineConfig, data: Data) -> Data {
        guard !data.isEmpty, !pipeline.filters.isEmpty else { return data }
        
        var cPipeline = ttzip_filter_pipeline_t()
        cPipeline.count = min(pipeline.filters.count, 4)
        for i in 0..<cPipeline.count {
            let fVal = ttzip_filter_type_t(UInt32(pipeline.filters[i].rawValue))
            if i == 0 { cPipeline.filters.0 = fVal }
            else if i == 1 { cPipeline.filters.1 = fVal }
            else if i == 2 { cPipeline.filters.2 = fVal }
            else if i == 3 { cPipeline.filters.3 = fVal }
            
            let ts = pipeline.typeSizes.indices.contains(i) ? pipeline.typeSizes[i] : 1
            if i == 0 { cPipeline.type_sizes.0 = ts }
            else if i == 1 { cPipeline.type_sizes.1 = ts }
            else if i == 2 { cPipeline.type_sizes.2 = ts }
            else if i == 3 { cPipeline.type_sizes.3 = ts }
            
            let tb = pipeline.truncateBits.indices.contains(i) ? pipeline.truncateBits[i] : 0
            if i == 0 { cPipeline.truncate_bits.0 = tb }
            else if i == 1 { cPipeline.truncate_bits.1 = tb }
            else if i == 2 { cPipeline.truncate_bits.2 = tb }
            else if i == 3 { cPipeline.truncate_bits.3 = tb }
        }
        
        var output = Data(count: data.count)
        let count = data.count
        let success = data.withUnsafeBytes { rawIn -> Bool in
            guard let inPtr = rawIn.bindMemory(to: UInt8.self).baseAddress else { return false }
            return output.withUnsafeMutableBytes { rawOut -> Bool in
                guard let outPtr = rawOut.bindMemory(to: UInt8.self).baseAddress else { return false }
                return ttzip_filter_pipeline_apply_forward(&cPipeline, inPtr, outPtr, count) == 0
            }
        }
        return success ? output : data
    }
    
    /// Reverses the transformation chain with zero dynamic heap allocation.
    public static func applyBackward(pipeline: PipelineConfig, data: Data) -> Data {
        guard !data.isEmpty, !pipeline.filters.isEmpty else { return data }
        
        var cPipeline = ttzip_filter_pipeline_t()
        cPipeline.count = min(pipeline.filters.count, 4)
        for i in 0..<cPipeline.count {
            let fVal = ttzip_filter_type_t(UInt32(pipeline.filters[i].rawValue))
            if i == 0 { cPipeline.filters.0 = fVal }
            else if i == 1 { cPipeline.filters.1 = fVal }
            else if i == 2 { cPipeline.filters.2 = fVal }
            else if i == 3 { cPipeline.filters.3 = fVal }
            
            let ts = pipeline.typeSizes.indices.contains(i) ? pipeline.typeSizes[i] : 1
            if i == 0 { cPipeline.type_sizes.0 = ts }
            else if i == 1 { cPipeline.type_sizes.1 = ts }
            else if i == 2 { cPipeline.type_sizes.2 = ts }
            else if i == 3 { cPipeline.type_sizes.3 = ts }
            
            let tb = pipeline.truncateBits.indices.contains(i) ? pipeline.truncateBits[i] : 0
            if i == 0 { cPipeline.truncate_bits.0 = tb }
            else if i == 1 { cPipeline.truncate_bits.1 = tb }
            else if i == 2 { cPipeline.truncate_bits.2 = tb }
            else if i == 3 { cPipeline.truncate_bits.3 = tb }
        }
        
        var output = Data(count: data.count)
        let count = data.count
        let success = data.withUnsafeBytes { rawIn -> Bool in
            guard let inPtr = rawIn.bindMemory(to: UInt8.self).baseAddress else { return false }
            return output.withUnsafeMutableBytes { rawOut -> Bool in
                guard let outPtr = rawOut.bindMemory(to: UInt8.self).baseAddress else { return false }
                return ttzip_filter_pipeline_apply_backward(&cPipeline, inPtr, outPtr, count) == 0
            }
        }
        return success ? output : data
    }

    /// Applies Bit-Grooming to a Float array preserving the specified Number of Significant Digits (NSD).
    public static func bitGroom(floats: [Float], nsd: UInt8) -> [Float] {
        guard !floats.isEmpty else { return floats }
        var result = [Float](repeating: 0, count: floats.count)
        floats.withUnsafeBufferPointer { srcPtr in
            result.withUnsafeMutableBufferPointer { dstPtr in
                ttzip_filter_bitgroom_float32_neon(
                    srcPtr.baseAddress!,
                    dstPtr.baseAddress!,
                    floats.count,
                    nsd
                )
            }
        }
        return result
    }

    /// Applies BitRound (nearest-even rounding) to a Float array preserving NSD.
    public static func bitRound(floats: [Float], nsd: UInt8) -> [Float] {
        guard !floats.isEmpty else { return floats }
        var result = [Float](repeating: 0, count: floats.count)
        floats.withUnsafeBufferPointer { srcPtr in
            result.withUnsafeMutableBufferPointer { dstPtr in
                ttzip_filter_bitround_float32_neon(
                    srcPtr.baseAddress!,
                    dstPtr.baseAddress!,
                    floats.count,
                    nsd
                )
            }
        }
        return result
    }
}
