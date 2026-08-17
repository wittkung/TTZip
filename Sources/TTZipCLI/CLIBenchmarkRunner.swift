import Foundation
import QuartzCore
import TTZipCore

public enum CLIBenchmarkRunner {
    public static func runExhaustiveBenchmark(formatFilter: String? = nil, levelFilter: String? = nil) async {
        print("🔥 启动全维度全组合矩阵物理压测引擎 (Format x Level x Encryption x Payload)...")
        
        var selectedFormats: [ArchiveCompressionFormat]? = nil
        if let fmtRaw = formatFilter, !fmtRaw.isEmpty {
            let splitFmts = fmtRaw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            let parsed = splitFmts.compactMap { (fmtStr: String) -> ArchiveCompressionFormat? in
                let mappedStr = (fmtStr == "gz") ? "tar.gz" : fmtStr
                return ArchiveCompressionFormat(rawValue: mappedStr)
            }
            if !parsed.isEmpty {
                selectedFormats = parsed
            }
        }
        
        var selectedLevels: [ArchiveCompressionLevel]? = nil
        if let lvlRaw = levelFilter, !lvlRaw.isEmpty {
            let splitLvls = lvlRaw.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            let parsed = splitLvls.compactMap { ArchiveCompressionLevel(levelInt: $0) }
            if !parsed.isEmpty {
                selectedLevels = parsed
            }
        }
        
        do {
            print("\n========================================================================================================================")
            print("📊 7Z / ZIP / TAR.GZ / TAR.ZST / ZST 全维度全组合极客极限性能测试汇总表 (Apple Silicon M-Series Native)")
            print("========================================================================================================================")
            let hDim = "场景维度"
            let hFmt = "格式"
            let hLvl = "压缩级别"
            let hEnc = "加密"
            let hComp = "打包/压缩吞吐"
            let hDecomp = "解压/释放吞吐"
            let hTime = "耗时(打包/解压)"
            let hRatio = "压缩体积比"
            let hSha = "完整性校验"
            
            print("\(hDim.padding(toLength: 26, withPad: " ", startingAt: 0)) | \(hFmt.padding(toLength: 6, withPad: " ", startingAt: 0)) | \(hLvl.padding(toLength: 10, withPad: " ", startingAt: 0)) | \(hEnc.padding(toLength: 6, withPad: " ", startingAt: 0)) | \(hComp.padding(toLength: 14, withPad: " ", startingAt: 0)) | \(hDecomp.padding(toLength: 14, withPad: " ", startingAt: 0)) | \(hTime.padding(toLength: 18, withPad: " ", startingAt: 0)) | \(hRatio.padding(toLength: 10, withPad: " ", startingAt: 0)) | \(hSha)")
            print("------------------------------------------------------------------------------------------------------------------------")
            fflush(stdout)

            let _ = try await ExhaustiveBenchmarkRunner.runExhaustiveMatrix(
                selectedFormats: selectedFormats,
                selectedLevels: selectedLevels
            ) { msg in
                if msg.hasPrefix("ROW:") {
                    let rowStr = String(msg.dropFirst(4))
                    print(rowStr)
                    fflush(stdout)
                } else {
                    print(msg)
                    fflush(stdout)
                }
            }
            print("========================================================================================================================\n")
        } catch {
            print("❌ 全维度矩阵测试失败: \(error.localizedDescription)")
        }
    }
    
    public static func runCompetitorBenchmark(config: BenchmarkRunConfig) async {
        let fmtStr = config.selectedFormats?.map { $0.rawValue }.joined(separator: ",") ?? "全量 16 种格式 (7Z,ZIP,TAR,ZSTD...)"
        print("⚔️ 启动竞品性能 PK 对比引擎 [目标软件: \(config.selectedTools?.joined(separator: ",") ?? "全量已安装竞品")] [格式: \(fmtStr)]...")
        if let fc = config.filterConfigPath {
            print("🎯 [针对性测试配置生效]: \(fc)")
        }
        if config.stopOnLagOrError {
            print("🚨 [严格中断模式已激活]: 任何单项场景若被竞品超越或解压核验未通过，将立即强行中断测试退出！")
        }
        if config.verifyAllDominance {
            print("🏆 [全量霸榜大考模式已激活]: 统一测试 16 种格式全量对标，必须 100% 全胜！")
        }
        
        let hugeBytes = parseSizeBytes(config.hugeSizeFilter)
        
        do {
            let rows = try await CompetitorBenchmarkRunner.runCompetitorMatrix(
                selectedFormats: config.selectedFormats,
                selectedLevels: config.selectedLevels,
                selectedTools: config.selectedTools,
                hugeSizeBytes: hugeBytes,
                customFilePaths: config.customFilePaths,
                filterConfigPath: config.filterConfigPath,
                stopOnLagOrError: config.stopOnLagOrError || config.verifyAllDominance,
                autoBestCompetitor: config.autoBestCompetitor,
                hugeOnly: config.hugeOnly,
                verifyAllDominance: config.verifyAllDominance
            ) { msg in
                if msg.hasPrefix("ROW_PK:\n") {
                    print(String(msg.dropFirst(7)))
                    fflush(stdout)
                } else if !msg.hasPrefix("ROW:") {
                    print(msg)
                    fflush(stdout)
                }
            }
            print("\n================================================================================================ Protocol Output")
            print("🏁 竞品 1v1 对抗测试全面完成！")
            CompetitorReportWriter.saveCompetitorReport(rows: rows)
            print("========================================================================================================================\n")
        } catch {
            print("❌ 竞品 1v1 对抗测试强行中止/中断: \(error.localizedDescription)")
        }
    }

    public static func runCompetitorBenchmark(
        formatFilter: String? = nil,
        levelFilter: String? = nil,
        toolFilter: String? = nil,
        hugeSizeFilter: String? = nil,
        customFilePaths: [String]? = nil,
        filterConfigPath: String? = nil,
        stopOnLagOrError: Bool = false,
        autoBestCompetitor: Bool = false,
        verifyAllDominance: Bool = false
    ) async {
        let config = BenchmarkRunConfig(
            selectedFormats: CLIArgumentParser.parseFormats(formatFilter),
            selectedLevels: CLIArgumentParser.parseLevels(levelFilter),
            selectedTools: toolFilter?.split(separator: ",").map { String($0) },
            hugeSizeFilter: hugeSizeFilter,
            customFilePaths: customFilePaths,
            stopOnLagOrError: stopOnLagOrError,
            autoBestCompetitor: autoBestCompetitor,
            verifyAllDominance: verifyAllDominance,
            filterConfigPath: filterConfigPath
        )
        await runCompetitorBenchmark(config: config)
    }
    
    public static func runBenchmark(sizeRaw: String) async {
        let size: BenchmarkDataSize
        switch sizeRaw.lowercased() {
        case "50m", "50mb": size = .tiny
        case "500m", "500mb": size = .medium
        case "1g", "1gb": size = .large
        case "2g", "2gb": size = .stress
        default: size = .small
        }
        
        print("🚀 正在初始化全核硬件基准压测 Payload (目标模组: \(size.rawValue))...")
        do {
            let results = try await ArchiveBenchmarkFacade.shared.runAllPresetsSuite(size: size)
            
            print("\n=========================================================================================")
            print("📊 TTZip 原生极限性能基准测试结果 (Apple Silicon M-Series Unified Memory)")
            print("=========================================================================================")
            print(String(format: "%-15s | %-12s | %-12s | %-10s | %-10s", "格式算法", "压缩速率", "实测解压", "体积压缩比", "加速倍数"))
            print("=========================================================================================")
            for res in results {
                print(String(format: "%-15s | %-10.1f MB/s | %-10.1f MB/s | %-9.1f %% | %-8.1f x",
                             res.formatName,
                             res.throughputMBs,
                             res.decompressionThroughputMBs,
                             res.compressionRatioPercent,
                             res.speedupMultiplier))
            }
            print("=========================================================================================")
            print("✅ 硬件压测矩阵计算完成！")
            fflush(stdout)
        } catch {
            print("❌ 压测失败: \(error.localizedDescription)")
            fflush(stdout)
        }
    }
    
    public static func runCustomBench() async {
        print("🚀 [Independent Real-World Performance Benchmark]")
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("CustomBench_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        func measure(_ name: String, _ block: () async throws -> Void) async {
            let start = PlatformMonotonicTimer.nowSeconds()
            do {
                try await block()
                let elapsed = PlatformMonotonicTimer.nowSeconds() - start
                print("   ✅ [\(name)] 完成，耗时: \(String(format: "%.3f", elapsed)) 秒")
            } catch {
                print("   ❌ [\(name)] 失败: \(error)")
            }
        }
        
        do {
            print("--- Scenario 1: Tiny Files (1000 files, ~10KB each) ---")
            let tinyDir = tempDir.appendingPathComponent("tiny_in")
            try FileManager.default.createDirectory(at: tinyDir, withIntermediateDirectories: true)
            for i in 0..<1000 {
                let fileURL = tinyDir.appendingPathComponent("tiny_\(i).txt")
                let content = String(repeating: "TTZip Fast I/O Test \(i)\n", count: 10240 / 25)
                try content.write(to: fileURL, atomically: true, encoding: .utf8)
            }
            
            await measure("ZIP Tiny Files") {
                _ = try await SecurityProtectionProxy.shared.quickCompress(
                    inputs: [tinyDir.path],
                    outputPath: tempDir.appendingPathComponent("tiny.zip").path,
                    format: .zip,
                    level: .normal
                )
            }
            if SevenZipBinaryResolver.resolveBinaryPath() != nil {
                await measure("7Z Tiny Files") {
                    _ = try await SecurityProtectionProxy.shared.quickCompress(
                        inputs: [tinyDir.path],
                        outputPath: tempDir.appendingPathComponent("tiny.7z").path,
                        format: .sevenZip,
                        level: .normal
                    )
                }
            }
        } catch {
            print("Setup failed: \(error)")
        }
    }

    public static func padColumn(_ string: String, _ width: Int) -> String {
        var displayWidth = 0
        for char in string {
            if char.isASCII {
                displayWidth += 1
            } else {
                displayWidth += 2
            }
        }
        if displayWidth >= width { return string }
        return string + String(repeating: " ", count: width - displayWidth)
    }

    // MARK: - 纯内存与 TurboBench / lzbench 对齐基准测试 (Feature 052)

    public static func runInMemoryBenchmark(options: CLIOptions) async {
        print("⚡ 启动纯内存基准测试引擎 (TurboBench / lzbench 工业级时钟校准)...")

        let formats: [String]
        if let fmtRaw = options.format, !fmtRaw.isEmpty {
            if fmtRaw.uppercased() == "ALL" {
                formats = ["zip", "7z", "zstd", "lz4"]
            } else {
                formats = fmtRaw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            }
        } else {
            formats = ["zip", "7z", "zstd", "lz4"]
        }

        let levels: [Int]
        if let lvlRaw = options.level, !lvlRaw.isEmpty {
            levels = lvlRaw.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        } else {
            levels = [1, 6]
        }

        let bufSize = parseSizeBytes(options.hugeSize ?? "10MB")
        let config = InMemoryBenchmarkConfig(
            selectedFormats: formats,
            selectedLevels: levels.isEmpty ? [1, 6] : levels,
            bufferSizeBytes: bufSize,
            warmupPasses: options.warmupPasses,
            minDurationMs: options.minDurationMs,
            useBinaryUnits: options.binaryUnits,
            turboBenchOutput: options.turboBenchCompat,
            customInputPath: options.inputPath
        )

        do {
            let engine = InMemoryBenchmarkEngine.shared
            let report = try await engine.runInMemoryBenchmark(config: config) { msg in
                if msg.hasPrefix("ROW:") {
                    print(String(msg.dropFirst(4)))
                    fflush(stdout)
                } else {
                    print(msg)
                    fflush(stdout)
                }
            }

            print("\n" + engine.generateTurboBenchTable(report: report))

            if let jsonPath = options.jsonReportPath {
                try engine.exportJSONReport(report: report, to: jsonPath)
                print("📄 JSON 基准测试报告已导出: \(jsonPath)")
            }
        } catch {
            print("❌ 纯内存基准测试失败: \(error.localizedDescription)")
        }
    }
}
