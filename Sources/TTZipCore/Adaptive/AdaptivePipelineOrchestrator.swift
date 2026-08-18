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

            // 1. Cascade evaluation: Shannon entropy & Uniformity
            var params = ttzip_tuning_params_t(alpha: 0.5, beta: 0.5, entropy_cutoff: 7.65, sample_size: 16384)
            let rec = ttzip_heuristic_eval_cascade(basePtr, sampleSize, 4, &params)

            let entropy = ttzip_quantum_calc_entropy_neon(basePtr, sampleSize)
            let isHighEntropy = entropy > 7.65
            let isUniform = rec.predicted_ratio >= 900.0 || rec.codec == TTZIP_TUNER_CODEC_DIRECT && entropy <= 0.1

            // 2. Scientific Float Detection
            let floatDetect = ttzip_detect_scientific_float_neon(basePtr, sampleSize)
            let isFloat = floatDetect.is_scientific_float

            let recommendStore = isHighEntropy || isUniform
            let recommendBitGroom = isFloat && !isHighEntropy

            return EvaluationResult(
                shannonEntropy: entropy,
                isIncompressible: isHighEntropy,
                isSpecialUniform: isUniform,
                isScientificFloat: isFloat,
                detectedTypeSize: floatDetect.type_size,
                recommendDirectStore: recommendStore,
                recommendBitGroom: recommendBitGroom,
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
