// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// 6-tier standardized test hierarchy (Tier 0 through Tier 5).
public enum TestTier: Int, CaseIterable, Identifiable, Sendable, Comparable {
    /// Tier 0: In-memory micro unit tests (SIMD, algorithms, design patterns, <= 5ms).
    case tier0 = 0
    
    /// Tier 1: Format contracts and integration roundtrip tests (16 formats, AES-256 roundtrip).
    case tier1 = 1
    
    /// Tier 2: System-level differential oracle and golden corpus tests (/usr/bin/tar, /usr/bin/unzip, .uu corpus).
    case tier2 = 2
    
    /// Tier 3: 262-dimension full-format peak throughput regression gates (strictly matching 604d44d baseline).
    case tier3 = 3
    
    /// Tier 4: Crash-first fuzzing and mutation testing against malformed archives.
    case tier4 = 4
    
    /// Tier 5: 1GB/2GB multi-volume high-entropy stress testing and competitor 1v1 PK.
    case tier5 = 5
    
    public var id: Int { rawValue }
    
    public var name: String {
        switch self {
        case .tier0: return "Tier 0 (Micro/Unit)"
        case .tier1: return "Tier 1 (Integration/Contract)"
        case .tier2: return "Tier 2 (Differential Oracle)"
        case .tier3: return "Tier 3 (Performance Gates)"
        case .tier4: return "Tier 4 (Crash-First Fuzzing)"
        case .tier5: return "Tier 5 (Stress & Scale PK)"
        }
    }
    
    public var description: String {
        switch self {
        case .tier0: return "In-memory micro tests, algorithms, SIMD and patterns (<= 5ms)"
        case .tier1: return "16 format roundtrip and AES-256 encryption integrity"
        case .tier2: return "Golden corpus (.uu) and system tool differential oracles"
        case .tier3: return "Strict 262-dimension peak throughput regression gates"
        case .tier4: return "Mutation fuzzing and corrupted archive resilience"
        case .tier5: return "1GB/2GB scale stress tests and 1v1 competitor PK"
        }
    }
    
    public static func < (lhs: TestTier, rhs: TestTier) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}
