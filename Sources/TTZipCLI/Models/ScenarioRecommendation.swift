// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Smart compression codec recommendation profile.
public struct ScenarioRecommendation: Codable, Sendable, Equatable {
    public let scenario: String
    public let measuredEntropy: Double
    public let trialCompressibilityRatio: Double
    public let recommendedAlgorithm: String
    public let recommendedLevel: Int
    public let rationale: String
    public let projectedThroughputMBs: Double
    public let projectedSpaceSavingsPct: Double
    public let probeDurationMs: Double

    public init(
        scenario: String,
        measuredEntropy: Double,
        trialCompressibilityRatio: Double,
        recommendedAlgorithm: String,
        recommendedLevel: Int,
        rationale: String,
        projectedThroughputMBs: Double,
        projectedSpaceSavingsPct: Double,
        probeDurationMs: Double
    ) {
        self.scenario = scenario
        self.measuredEntropy = measuredEntropy
        self.trialCompressibilityRatio = trialCompressibilityRatio
        self.recommendedAlgorithm = recommendedAlgorithm
        self.recommendedLevel = recommendedLevel
        self.rationale = rationale
        self.projectedThroughputMBs = projectedThroughputMBs
        self.projectedSpaceSavingsPct = projectedSpaceSavingsPct
        self.probeDurationMs = probeDurationMs
    }
}
