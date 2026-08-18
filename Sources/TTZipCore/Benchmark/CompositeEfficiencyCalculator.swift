// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// 5-Tier 多语料加权几何平均数与综合效能指数 (CEI / SPECScore) 计算引擎
public enum CompositeEfficiencyCalculator {
    
    /// 从 5 大 Tier 实测数据计算加权几何平均综合得分
    public static func computeScore(
        algorithm: String,
        level: Int,
        measurements: [TierBenchmarkMeasurement],
        profile: BenchmarkScenarioProfile = .balanced,
        referenceBaseline: (compMBs: Double, decompMBs: Double, ratio: Double) = (1000.0, 5000.0, 2.70)
    ) -> AlgorithmCompositeScore {
        guard !measurements.isEmpty else {
            return AlgorithmCompositeScore(
                algorithm: algorithm,
                level: level,
                geomCompSpeedMBs: 0,
                geomDecompSpeedMBs: 0,
                geomCompressionRatio: 1.0,
                geomSpaceSavingsPct: 0,
                compositeEfficiencyIndex: 0,
                normalizedSpecScore: 0,
                profile: profile,
                isParetoOptimal: false,
                paretoRank: 999,
                tierMeasurements: []
            )
        }
        
        // 1. 归一化各 Tier 权重 (总和为 1.0)
        let totalWeight = measurements.reduce(0.0) { $0 + $1.tier.defaultWeight }
        let effectiveTotal = totalWeight > 0 ? totalWeight : Double(measurements.count)
        
        var sumWeightedLnComp = 0.0
        var sumWeightedLnDecomp = 0.0
        var sumWeightedLnRatio = 0.0
        
        for m in measurements {
            let normalizedWeight = m.tier.defaultWeight / effectiveTotal
            sumWeightedLnComp += normalizedWeight * log(max(0.001, m.compressionSpeedMBs))
            sumWeightedLnDecomp += normalizedWeight * log(max(0.001, m.decompressionSpeedMBs))
            sumWeightedLnRatio += normalizedWeight * log(max(1.0, m.compressionRatio))
        }
        
        let geomCompSpeed = exp(sumWeightedLnComp)
        let geomDecompSpeed = exp(sumWeightedLnDecomp)
        let geomRatio = exp(sumWeightedLnRatio)
        let geomSavings = max(0.0, (1.0 - 1.0 / geomRatio) * 100.0)
        
        // 2. Cobb-Douglas 综合效能指数 (CEI)
        let w = profile.weights
        let cei = pow(geomCompSpeed, w.alpha) * pow(geomDecompSpeed, w.beta) * pow(geomRatio, w.gamma)
        
        // 3. SPEC-Score (以 Deflate-L6 为 1000 分参考系)
        let refComp = max(0.001, referenceBaseline.compMBs)
        let refDecomp = max(0.001, referenceBaseline.decompMBs)
        let refRatio = max(1.0, referenceBaseline.ratio)
        
        let relComp = geomCompSpeed / refComp
        let relDecomp = geomDecompSpeed / refDecomp
        let relRatio = geomRatio / refRatio
        
        let specScore = pow(relComp, w.alpha) * pow(relDecomp, w.beta) * pow(relRatio, w.gamma) * 1000.0
        
        return AlgorithmCompositeScore(
            algorithm: algorithm,
            level: level,
            geomCompSpeedMBs: geomCompSpeed,
            geomDecompSpeedMBs: geomDecompSpeed,
            geomCompressionRatio: geomRatio,
            geomSpaceSavingsPct: geomSavings,
            compositeEfficiencyIndex: cei,
            normalizedSpecScore: specScore,
            profile: profile,
            isParetoOptimal: false,
            paretoRank: 1,
            tierMeasurements: measurements
        )
    }
    
    /// 计算并标记多算法综合效能帕累托前沿 (Skyline 2D/3D Dominance)
    public static func computeParetoFrontier(
        scores: [AlgorithmCompositeScore]
    ) -> [AlgorithmCompositeScore] {
        guard !scores.isEmpty else { return [] }
        
        var results = scores
        
        for i in 0..<results.count {
            var isDominated = false
            let p1 = results[i]
            
            for j in 0..<results.count where i != j {
                let p2 = results[j]
                
                // p2 支配 p1: 速度 >= p1 且 压缩比 >= p1，且至少一项严格大于
                let speedGreaterOrEqual = p2.geomCompSpeedMBs >= p1.geomCompSpeedMBs
                let ratioGreaterOrEqual = p2.geomCompressionRatio >= p1.geomCompressionRatio
                let strictlyBetter = (p2.geomCompSpeedMBs > p1.geomCompSpeedMBs) || (p2.geomCompressionRatio > p1.geomCompressionRatio)
                
                if speedGreaterOrEqual && ratioGreaterOrEqual && strictlyBetter {
                    isDominated = true
                    break
                }
            }
            
            results[i].isParetoOptimal = !isDominated
            results[i].paretoRank = isDominated ? 2 : 1
        }
        
        return results
    }
}
