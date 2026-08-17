import Foundation
import QuartzCore
import CTTZipBridge

/// 竞品基准压测对比引擎 (复用物理测试矩阵，全开竞品性能参数进行横向 PK)
public final class CompetitorBenchmarkRunner: @unchecked Sendable {
    public init() {}

    /// 执行全矩阵竞品性能对比压测（针对每一项场景，跑分 TTZip 并并行拉出所有竞品进行全量横向 PK）
    public static func runCompetitorMatrix(
        selectedFormats: [ArchiveCompressionFormat]? = nil,
        selectedLevels: [ArchiveCompressionLevel]? = nil,
        selectedTools: [String]? = nil,
        hugeSizeBytes: Int64 = 500 * 1024 * 1024,
        customFilePaths: [String]? = nil,
        ttzipRows: [ExhaustiveBenchmarkRow]? = nil,
        filterConfigPath: String? = nil,
        stopOnLagOrError: Bool = false,
        autoBestCompetitor: Bool = false,
        hugeOnly: Bool = false,
        verifyAllDominance: Bool = false,
        passes: Int = 1,
        progressHandler: (@Sendable (String) -> Void)? = nil
    ) async throws -> [CompetitorBenchmarkRow] {
        let cacheDir = FileManager.default.temporaryDirectory.appendingPathComponent("TTZipExhaustiveDatasetCache")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        var (payloads, _) = try prepareDatasets(
            hugeSizeBytes: hugeSizeBytes,
            customFilePaths: customFilePaths,
            progressHandler: progressHandler
        )
        if hugeOnly {
            payloads = payloads.filter { $0.bytes >= 400 * 1024 * 1024 }
        }

        let all16: [ArchiveCompressionFormat] = [.sevenZip, .zip, .tar, .zst, .gz, .bz2, .xz, .lzip, .lz4, .brotli, .lrzip, .aar, .snappy, .wim, .dmg, .iso]
        let formats: [ArchiveCompressionFormat] = selectedFormats ?? all16
        let levels: [ArchiveCompressionLevel] = selectedLevels ?? [.level1, .ultra]

        let writer = ArchiveEngineFactory.makeWriter()
        let extractor = ArchiveEngineFactory.makeExtractor()

        let loadedFilter: TargetedBenchmarkFilter? = filterConfigPath != nil ? TargetedBenchmarkFilter.load(from: filterConfigPath!) : nil
        if loadedFilter != nil {
            progressHandler?("🎯 [已激活针对性测试筛选器] 已从配置文件过滤出特定追平/落后测试场景...")
        }

        var itemsToRun: [(payload: (name: String, path: String, bytes: Int64), fmt: ArchiveCompressionFormat, lvl: ArchiveCompressionLevel, isEnc: Bool)] = []
        var rawIdx = 0
        for payload in payloads {
            for fmt in formats {
                for lvl in levels {
                    if payload.bytes >= 1024 * 1024 * 1024 && !lvl.isQuickPreset { continue }
                    let supportsEncryption = fmt.supportsPasswordEncryption
                    let encOpts: [Bool] = (supportsEncryption && payload.bytes < 1024 * 1024 * 1024) ? [false, true] : [false]
                    for isEnc in encOpts {
                        rawIdx += 1
                        let encStr = isEnc ? "AES-256" : "无"
                        let fmtStr = fmt.rawValue.uppercased()
                        if let filter = loadedFilter {
                            if filter.matches(pkIdx: rawIdx, payload: payload.name, format: fmtStr, level: lvl.rawValue, encryption: encStr) {
                                itemsToRun.append((payload, fmt, lvl, isEnc))
                            }
                        } else {
                            itemsToRun.append((payload, fmt, lvl, isEnc))
                        }
                    }
                }
            }
        }

        let totalItems = itemsToRun.count
        progressHandler?("⚔️ [全竞品多核 PK 启动] 共计 \(totalItems) 项组合场景，针对每一项：跑出 TTZip 与所有已安装竞品软件速度，即刻打出对比表格...")

        var allReportRows: [CompetitorBenchmarkRow] = []
        var stepCount = 0

        for item in itemsToRun {
            stepCount += 1
            let payload = item.payload
            let fmt = item.fmt
            let lvl = item.lvl
            let isEnc = item.isEnc
            let passwordStr = isEnc ? "P@ssw0rd2026!" : nil

            let payloadMB = String(format: "%.0f", Double(payload.bytes) / (1024.0 * 1024.0))
            progressHandler?("📌 [场景 \(stepCount)/\(totalItems)] 开始: \(payload.name) | \(fmt.rawValue.uppercased()) | L\(lvl.rawValue) | 加密: \(isEnc ? "AES-256" : "无") | \(payloadMB) MB")

            let ttArcPath = cacheDir.appendingPathComponent("tt_archive_\(UUID().uuidString).\(fmt.rawValue)").path
            let ttExtractDestPath = cacheDir.appendingPathComponent("tt_out_\(UUID().uuidString)").path
            try? FileManager.default.createDirectory(atPath: ttExtractDestPath, withIntermediateDirectories: true)
            defer {
                try? FileManager.default.removeItem(atPath: ttArcPath)
                try? FileManager.default.removeItem(atPath: ttExtractDestPath)
            }

            var ttCompDur = 1e-6
            var ttExtractDur = 1e-6
            var ttCompMBs = 0.0
            var ttExtractMBs = 0.0
            var ttArcSize: Int64 = 0

            let isShortWorkload = payload.bytes <= 15 * 1024 * 1024
            let passCount = isShortWorkload ? max(passes, 5) : max(1, passes)
            var bestCompDur = Double.infinity
            var bestExtractDur = Double.infinity
            var validExtractDir = ttExtractDestPath
            let checker = ArchiveEngineFactory.makeIntegrityChecker()
            AppleSiliconTuner.shared.boostCurrentThreadPriority()

            _ = try? CompetitorBenchmarkRunner.folderSize(payload.path)

            var ttCompressAopStage = "-"
            for pass in 0..<passCount {
                let runArcPath = cacheDir.appendingPathComponent("tt_run_\(UUID().uuidString).\(fmt.rawValue)").path
                defer { try? FileManager.default.removeItem(atPath: runArcPath) }
                
                progressHandler?("   ⏳ TTZip 打包中 (Pass \(pass + 1)/\(passCount))...")
                AppleSiliconTuner.shared.boostCurrentThreadPriority()
                ttzip_slice_reset()
                let tt0 = CACurrentMediaTime()
                do {
                    var advanced = ArchiveAdvancedOptions.defaultOptions
                    if isEnc && fmt == .sevenZip {
                        advanced.encryptFileNames = true
                    }
                    try writer.createArchiveSync(
                        outputPath: runArcPath,
                        format: fmt,
                        level: lvl,
                        inputPaths: [payload.path],
                        password: passwordStr,
                        advancedOptions: advanced
                    )
                    let tt1 = CACurrentMediaTime()
                    let topName = String(cString: ttzip_slice_get_top_stage_name())
                    let topRatio = ttzip_slice_get_top_stage_ratio()
                    if topName != "N/A" && topRatio > 0.0 {
                        ttCompressAopStage = String(format: "%@ (%.1f%%)", topName, topRatio)
                    }
                    bestCompDur = min(bestCompDur, max(1e-6, tt1 - tt0))
                    let compMBs = (Double(payload.bytes) / (1024.0 * 1024.0)) / max(1e-6, tt1 - tt0)
                    progressHandler?("   ✅ TTZip 打包完成: \(String(format: "%.1f", compMBs)) MB/s (\(String(format: "%.3f", tt1 - tt0))s)")
                } catch {
                    TTLogger.error("\n❌ [TTZip 打包失败]: failed with error: \(error)")
                    if stopOnLagOrError { exit(1) }
                }

                let sz = (try? FileManager.default.attributesOfItem(atPath: runArcPath)[.size] as? Int64) ?? 0
                if sz > 0 {
                    ttArcSize = sz
                    let passExtractDir = (ttExtractDestPath as NSString).appendingPathComponent("pass_\(pass)")
                    try? FileManager.default.removeItem(atPath: passExtractDir)
                    try? FileManager.default.createDirectory(atPath: passExtractDir, withIntermediateDirectories: true)
                    progressHandler?("   ⏳ TTZip 解压中...")
                    AppleSiliconTuner.shared.boostCurrentThreadPriority()
                    let tt2 = CACurrentMediaTime()
                    do {
                        try extractor.extractSync(
                            archivePath: runArcPath,
                            destinationDir: passExtractDir,
                            password: passwordStr
                        )
                        let tt3 = CACurrentMediaTime()
                        let v = checker.verifyExtractedDirectory(
                            directoryPath: passExtractDir,
                            expectedOriginalBytes: payload.bytes,
                            sourceFilePath: payload.path,
                            label: "TTZip Pass \(pass)"
                        )
                        if v.isValid {
                            bestExtractDur = min(bestExtractDur, max(1e-6, tt3 - tt2))
                            validExtractDir = passExtractDir
                        }
                    } catch {
                        TTLogger.warning("⚠️ [CompetitorBenchmarkRunner extractSync Error]: \(error)")
                    }
                }
            }

            let result = checker.verifyExtractedDirectory(
                directoryPath: validExtractDir,
                expectedOriginalBytes: payload.bytes,
                sourceFilePath: payload.path,
                label: "TTZip"
            )
            if !result.isValid {
                let files = (try? FileManager.default.contentsOfDirectory(atPath: validExtractDir)) ?? []
                TTLogger.error("❌ [TTZip 解压失败]: dir \(validExtractDir) contains \(files). ARC PATH: \(ttArcPath)")
                if stopOnLagOrError {
                    TTLogger.error("\n❌ [单项对比中断 / TTZip 解压核验未通过] TTZip 在场景 [\(payload.name) | 级别: L\(lvl.rawValue)] 下解压产物核验失败！按协议立即强行中止压测！\n")
                    exit(1)
                }
            }

            if bestCompDur < Double.infinity {
                ttCompDur = max(1e-6, bestCompDur)
                ttCompMBs = (Double(payload.bytes) / (1024.0 * 1024.0)) / ttCompDur
            }
            if bestExtractDur < Double.infinity {
                ttExtractDur = max(1e-6, bestExtractDur)
                ttExtractMBs = (Double(payload.bytes) / (1024.0 * 1024.0)) / ttExtractDur
            }

            let itemCompetitorResults = runCompetitorTools(
                payload: payload,
                fmt: fmt,
                lvl: lvl,
                isEnc: isEnc,
                stepCount: stepCount,
                ttArc: URL(fileURLWithPath: ttArcPath),
                ttArcSize: ttArcSize,
                ttCompMBs: ttCompMBs,
                ttExtractMBs: ttExtractMBs,
                ttCompressAopStage: ttCompressAopStage,
                stopOnLagOrError: stopOnLagOrError,
                selectedTools: selectedTools,
                autoBestCompetitor: autoBestCompetitor,
                loadedFilter: loadedFilter,
                cacheDir: cacheDir,
                compDictPath: nil,
                progressHandler: progressHandler
            )

            for res in itemCompetitorResults {
                allReportRows.append(res.row)
            }

            let ttNameStr      = "👑 TTZip (Apple SIMD)".padding(toLength: 26, withPad: " ", startingAt: 0)
            let ttCompSpeed    = String(format: "%8.1f MB/s", ttCompMBs).padding(toLength: 17, withPad: " ", startingAt: 0)
            let ttExtractSpeed = String(format: "%8.1f MB/s", ttExtractMBs).padding(toLength: 17, withPad: " ", startingAt: 0)
            let ttSizeMb       = Double(ttArcSize) / (1024.0 * 1024.0)
            let ttRatio        = payload.bytes > 0 ? (Double(ttArcSize) / Double(payload.bytes)) * 100.0 : 100.0
            let ttSizeStr      = String(format: "%.2f MB (%.1f%%)", ttSizeMb, ttRatio).padding(toLength: 22, withPad: " ", startingAt: 0)
            let ttTimeStr      = String(format: "%.3fs / %.3fs", ttCompDur, ttExtractDur).padding(toLength: 19, withPad: " ", startingAt: 0)
            let ttMultStr      = "基准 (1.0x)".padding(toLength: 22, withPad: " ", startingAt: 0)

            let fullTable = CompetitorReportWriter.formatPKTable(
                stepCount: stepCount,
                totalItems: totalItems,
                payloadName: payload.name,
                format: fmt,
                level: lvl,
                isEncrypted: isEnc,
                ttNameStr: ttNameStr,
                ttCompSpeed: ttCompSpeed,
                ttExtractSpeed: ttExtractSpeed,
                ttSizeStr: ttSizeStr,
                ttTimeStr: ttTimeStr,
                ttMultStr: ttMultStr,
                itemCompetitorResults: itemCompetitorResults.map { ($0.name, $0.compDur, $0.compMBs, $0.extractDur, $0.extractMBs, $0.row) },
                ttCompMBs: ttCompMBs
            )

            progressHandler?("ROW_PK:\n" + fullTable)

            // 及时清理本项测试产生的中间包与解压临时目录，杜绝磁盘脏页堆积与 IO 节流
            for pass in 0..<passCount {
                let passExtractDir = (ttExtractDestPath as NSString).appendingPathComponent("pass_\(pass)")
                try? FileManager.default.removeItem(atPath: passExtractDir)
            }
            try? FileManager.default.removeItem(atPath: validExtractDir)
            try? FileManager.default.removeItem(atPath: ttArcPath)
            try? FileManager.default.removeItem(atPath: ttExtractDestPath)
        }

        CompetitorReportWriter.saveCompetitorReport(rows: allReportRows)
        return allReportRows
    }
}
