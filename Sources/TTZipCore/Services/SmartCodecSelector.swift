// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// 3 阶段级联快速熵与压缩比探针及场景智能算法推荐器 (Smart Codec Scenario Selector)
public final class SmartCodecSelector: @unchecked Sendable {
    public static let shared = SmartCodecSelector()
    private init() {}

    /// 推荐场景定义
    public enum Scenario: String, Sendable, CaseIterable {
        case instantTransfer = "Instant Transfer (AirDrop/10G LAN)"
        case balancedDaily = "Balanced Daily Archive"
        case coldStorage = "Cold Storage / Maximum Ratio"

        public static func from(string: String) -> Scenario {
            let lower = string.lowercased().trimmingCharacters(in: .whitespaces)
            if lower.contains("airdrop") || lower.contains("instant") || lower.contains("lan") || lower.contains("fast") {
                return .instantTransfer
            } else if lower.contains("cold") || lower.contains("max") || lower.contains("backup") || lower.contains("archive") {
                return .coldStorage
            } else {
                return .balancedDaily
            }
        }

        var ffiCode: Int32 {
            switch self {
            case .instantTransfer: return Int32(TTZIP_SCENARIO_INSTANT_TRANSFER.rawValue)
            case .balancedDaily: return Int32(TTZIP_SCENARIO_BALANCED_DAILY.rawValue)
            case .coldStorage: return Int32(TTZIP_SCENARIO_COLD_STORAGE.rawValue)
            }
        }
    }

    /// 对数据执行 $<10\text{ ms}$ 的快速探针分析并生成推荐结果
    public func recommend(
        for buffer: UnsafePointer<UInt8>,
        length: Int,
        scenario: Scenario = .balancedDaily
    ) -> ScenarioRecommendation {
        var rawResult = TTZipRecommendationResult()
        let status = ttzip_rust_recommend_codec(buffer, length, scenario.ffiCode, &rawResult)

        if status == TTZIP_STATUS_OK {
            let algo = withUnsafeBytes(of: &rawResult.recommended_algorithm) { ptr -> String in
                guard let base = ptr.baseAddress?.assumingMemoryBound(to: CChar.self) else { return "ZIP-Deflate" }
                return String(cString: base)
            }
            let rationale = withUnsafeBytes(of: &rawResult.rationale) { ptr -> String in
                guard let base = ptr.baseAddress?.assumingMemoryBound(to: CChar.self) else { return "" }
                return String(cString: base)
            }
            return ScenarioRecommendation(
                scenario: scenario.rawValue,
                measuredEntropy: rawResult.measured_entropy,
                trialCompressibilityRatio: rawResult.trial_compressibility_ratio,
                recommendedAlgorithm: algo,
                recommendedLevel: Int(rawResult.recommended_level),
                rationale: rationale,
                projectedThroughputMBs: rawResult.projected_throughput_mbs,
                projectedSpaceSavingsPct: rawResult.projected_space_savings_pct,
                probeDurationMs: rawResult.probe_duration_ms
            )
        }

        // Fallback default
        return ScenarioRecommendation(
            scenario: scenario.rawValue,
            measuredEntropy: 0.0,
            trialCompressibilityRatio: 1.0,
            recommendedAlgorithm: "ZIP-Deflate",
            recommendedLevel: 6,
            rationale: "Default fallback recommendation.",
            projectedThroughputMBs: 1200.0,
            projectedSpaceSavingsPct: 0.0,
            probeDurationMs: 0.0
        )
    }
}
