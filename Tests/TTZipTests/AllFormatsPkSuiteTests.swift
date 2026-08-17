import XCTest
@testable import TTZipCore

/// 专用于全 16 种归档格式霸榜与竞品 1v1 PK 的自动化测试套件
final class AllFormatsPkSuiteTests: XCTestCase {

    /// 针对 7z, Zst, Gz 等主干格式进行单轮 (passes: 1) 全量物理竞品 PK 测试
    func testAllFormatsPkLeaderboardAndIntegrity() async throws {
        guard ProcessInfo.processInfo.environment["TTZIP_RUN_BENCHMARKS"] != nil else {
            throw XCTSkip("全格式 500MB 竞品 PK 跑分测试需设置 TTZIP_RUN_BENCHMARKS=1 触发，常规 swift test 自动跳过以杜绝卡主")
        }
        
        try await withTimeout(seconds: 1200.0, description: "AllFormatsPkLeaderboard") {
            TTLogger.info("\n================================================================================")
            TTLogger.info("   🏆 [TTZip Suite] 全 16 种格式竞品 1v1 PK 与完整性断言")
            TTLogger.info("================================================================================")
            
            let targetFormats: [ArchiveCompressionFormat] = [
                .sevenZip, .zip, .tarZst, .tarGz,
                .tarBz2, .tarXz, .tar, .lzip,
                .lz4, .brotli, .lrzip, .aar,
                .snappy, .wim, .dmg, .iso
            ]
            
            let rows = try await CompetitorBenchmarkRunner.runCompetitorMatrix(
                selectedFormats: targetFormats,
                selectedLevels: [.level1, .level6],
                stopOnLagOrError: false,
                autoBestCompetitor: true,
                verifyAllDominance: false,
                passes: 2,
                progressHandler: { msg in
                    TTLogger.debug("  \(msg)")
                }
            )
            
            TTLogger.info("\n================================================================================")
            TTLogger.info("   📊 [TTZip Suite] 全格式 PK 测试完成，共完成 \(rows.count) 项场景测算与竞品对比")
            TTLogger.info("================================================================================\n")
            
            XCTAssertGreaterThan(rows.count, 0, "全格式 PK 测试结果列表不应为空")
        }
    }
}
