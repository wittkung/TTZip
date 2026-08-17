import Foundation

/// 6 大标准分层测试体系枚举 (Tier 0 - Tier 5)
public enum TestTier: Int, CaseIterable, Identifiable, Sendable, Comparable {
    /// Tier 0: 纯内存微单元测试 (SIMD、算法、模式、快速单测，<= 5ms)
    case tier0 = 0
    
    /// Tier 1: 格式契约与集成往返测试 (16 种格式编码/解码往返、AES-256 加密往返)
    case tier1 = 1
    
    /// Tier 2: 系统级差分预言机与黄金缺陷语料库测试 (/usr/bin/tar、/usr/bin/unzip、.uu 语料)
    case tier2 = 2
    
    /// Tier 3: 全格式 262 维度历史最优性能与吞吐硬门禁 (严格对标 604d44d 最优基线)
    case tier3 = 3
    
    /// Tier 4: 崩溃现场优先落盘变异模糊测试 (Fuzzing、畸变包防御)
    case tier4 = 4
    
    /// Tier 5: 1GB/2GB 巨型分卷高熵高压压力测试与竞品 1v1 PK
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
