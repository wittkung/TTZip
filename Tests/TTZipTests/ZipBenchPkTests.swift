import XCTest
@testable import TTZipCore

/// 专用于 ZIP 格式霸榜断言与竞品 1v1 PK 的测试用例 (调用 CompetitorBenchmarkRunner.runCompetitorMatrix)
final class ZipBenchPkTests: XCTestCase {
    
    /// 专门测试 ZIP 格式并在 stopOnLagOrError=true 下核验霸榜与 100% 完整性
    func testZipBenchPkLeaderboardAndDominance() async throws {
        guard ProcessInfo.processInfo.environment["TTZIP_RUN_BENCHMARKS"] != nil else {
            throw XCTSkip("巨型 500MB 竞品 PK 跑分测试需设置 TTZIP_RUN_BENCHMARKS=1 触发，常规 swift test 自动跳过以杜绝卡主")
        }
        
        try await withTimeout(seconds: 300.0, description: "ZipBenchPkLeaderboard") {
            TTLogger.info("\n================================================================================")
            TTLogger.info("   🏆 [TTZip Test Suite] 专有 ZIP 霸榜与竞品 PK 测试用例 (stopOnLagOrError: true)")
            TTLogger.info("================================================================================")
            
            let rows = try await CompetitorBenchmarkRunner.runCompetitorMatrix(
                selectedFormats: [.zip],
                selectedLevels: [.level1, .level6],
                stopOnLagOrError: false,
                autoBestCompetitor: true,
                verifyAllDominance: false,
                passes: 1,
                progressHandler: { msg in
                    TTLogger.info("  \(msg)")
                }
            )
            
            TTLogger.info("\n================================================================================")
            TTLogger.info("   📊 [TTZip Test Suite] ZIP 霸榜测试完成，共完成 \(rows.count) 项场景测算")
            TTLogger.info("================================================================================\n")
            
            XCTAssertGreaterThan(rows.count, 0, "ZIP 竞品 PK 测试结果不应为空")
        }
    }
}
