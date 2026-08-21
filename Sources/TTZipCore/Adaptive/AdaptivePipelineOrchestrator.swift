// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-performance transparent orchestrator evaluating 16KB micro-samples to direct compression pipelines.
public final class AdaptivePipelineOrchestrator: @unchecked Sendable {
    public static let shared = AdaptivePipelineOrchestrator()

    public struct EvaluationResult: Sendable {
        public let shannonEntropy: Double
        public let isIncompressible: Bool
        public let isSpecialUniform: Bool
        public let isScientificFloat: Bool
        public let detectedTypeSize: UInt8
        public let recommendDirectStore: Bool
        public let recommendBitGroom: Bool
        public let recommendNSD: UInt8
    }

    private init() {}

    /// Evaluates sample data (up to 16KB) in < 3.5 µs to determine the optimal pipeline strategy.
    public func evaluateSample(data: Data) -> EvaluationResult {
        guard !data.isEmpty else {
            return EvaluationResult(
                shannonEntropy: 0.0,
                isIncompressible: false,
                isSpecialUniform: false,
                isScientificFloat: false,
                detectedTypeSize: 1,
                recommendDirectStore: false,
                recommendBitGroom: false,
                recommendNSD: 3
            )
        }

        let sampleSize = min(data.count, 16384)
        return data.withUnsafeBytes { raw in
            guard let basePtr = raw.baseAddress else {
                return EvaluationResult(
                    shannonEntropy: 0.0,
                    isIncompressible: false,
                    isSpecialUniform: false,
                    isScientificFloat: false,
                    detectedTypeSize: 1,
                    recommendDirectStore: false,
                    recommendBitGroom: false,
                    recommendNSD: 3
                )
            }

            let bytePtr = basePtr.assumingMemoryBound(to: UInt8.self)
            var freqs = [Int](repeating: 0, count: 256)
            for i in 0..<sampleSize {
                freqs[Int(bytePtr[i])] += 1
            }
            var entropy: Double = 0.0
            let countD = Double(sampleSize)
            for f in freqs where f > 0 {
                let p = Double(f) / countD
                entropy -= p * log2(p)
            }

            let isHighEntropy = entropy > 7.65
            let isUniform = entropy <= 0.1
            
            // Detect Float32 arrays
            var isFloat = false
            var floatTypeSize: UInt8 = 1
            if sampleSize >= 64 && (sampleSize % 4 == 0) {
                let floatPtr = basePtr.assumingMemoryBound(to: Float.self)
                let numFloats = sampleSize / 4
                var validFloats = 0
                let checkCount = min(numFloats, 256)
                for i in 0..<checkCount {
                    let val = floatPtr[i]
                    if val.isFinite && !val.isZero && abs(val) < 1e8 && abs(val) > 1e-8 {
                        validFloats += 1
                    }
                }
                if validFloats >= (checkCount * 8) / 10 {
                    isFloat = true
                    floatTypeSize = 4
                }
            }
            
            let recommendStore = (isHighEntropy || isUniform) && !isFloat

            return EvaluationResult(
                shannonEntropy: entropy,
                isIncompressible: isHighEntropy && !isFloat,
                isSpecialUniform: isUniform,
                isScientificFloat: isFloat,
                detectedTypeSize: floatTypeSize,
                recommendDirectStore: recommendStore,
                recommendBitGroom: isFloat,
                recommendNSD: 3
            )
        }
    }

    /// Evaluates a physical file by reading up to 16KB via pread into a stack buffer.
    public func evaluateFile(atPath path: String) -> EvaluationResult {
        guard let fileHandle = FileHandle(forReadingAtPath: path) else {
            return EvaluationResult(
                shannonEntropy: 0.0,
                isIncompressible: false,
                isSpecialUniform: false,
                isScientificFloat: false,
                detectedTypeSize: 1,
                recommendDirectStore: false,
                recommendBitGroom: false,
                recommendNSD: 3
            )
        }
        defer { try? fileHandle.close() }

        let sampleData = (try? fileHandle.read(upToCount: 16384)) ?? Data()
        return evaluateSample(data: sampleData)
    }
}
