import Foundation

/// 竞品测试对比报告生成与持久化导出组件
public enum CompetitorReportWriter {
    public static func saveCompetitorReport(rows: [CompetitorBenchmarkRow]) {
        let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let docsDir = currentDir.appendingPathComponent("docs")
        let archiveDir = docsDir.appendingPathComponent("benchmarks")
        try? FileManager.default.createDirectory(at: docsDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: archiveDir, withIntermediateDirectories: true)

        let formatter = DateFormatterCache.shared.formatter(for: "yyyy-MM-dd_HHmmss")
        let timestampStr = formatter.string(from: Date())

        let latestJsonURL = docsDir.appendingPathComponent("competitor_benchmark_report.json")
        let latestMdURL = docsDir.appendingPathComponent("competitor_benchmark_report.md")
        let archiveJsonURL = archiveDir.appendingPathComponent("benchmark_report_\(timestampStr).json")
        let archiveMdURL = archiveDir.appendingPathComponent("benchmark_report_\(timestampStr).md")
        let peakMatrixURL = archiveDir.appendingPathComponent("peak_performance_matrix.json")

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let json = try? encoder.encode(rows) {
            try? json.write(to: latestJsonURL)
            try? json.write(to: archiveJsonURL)
        }

        // 维护与更新物理最高纪录存储器 (Peak Performance Matrix)
        var peakDict: [String: PeakPerformanceRecord] = [:]
        if let existingData = try? Data(contentsOf: peakMatrixURL),
           let decoded = try? JSONDecoder().decode([String: PeakPerformanceRecord].self, from: existingData) {
            peakDict = decoded
        }
        for r in rows {
            let key = "\(r.format.rawValue)_\(r.level.rawValue)_\(r.isEncrypted)_\(r.dimensionName)"
            var currentRecord = peakDict[key] ?? PeakPerformanceRecord(
                formatRaw: r.format.rawValue,
                levelRaw: r.level.rawValue,
                isEncrypted: r.isEncrypted,
                dimensionName: r.dimensionName,
                peakCompressMBs: r.ttzipCompressMBs,
                peakExtractMBs: r.ttzipExtractMBs,
                lastUpdated: Date()
            )
            if r.ttzipCompressMBs > currentRecord.peakCompressMBs {
                currentRecord.peakCompressMBs = r.ttzipCompressMBs
                currentRecord.lastUpdated = Date()
            }
            if r.ttzipExtractMBs > currentRecord.peakExtractMBs {
                currentRecord.peakExtractMBs = r.ttzipExtractMBs
                currentRecord.lastUpdated = Date()
            }
            peakDict[key] = currentRecord
        }
        if let peakData = try? encoder.encode(peakDict) {
            try? peakData.write(to: peakMatrixURL)
        }

        let topo = AppleSiliconTuner.shared.topology
        var md = "# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)\n\n"
        md += "> **测试时间**: \(Date())\n"
        md += "> **测试环境**: Apple Silicon (\(topo.totalCores) 核 [P:\(topo.performanceCores) / E:\(topo.efficiencyCores)]) | macOS \(ProcessInfo.processInfo.operatingSystemVersionString)\n"
        md += "> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil\n"
        md += "> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构\n\n"
        md += "| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |\n"
        md += "| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |\n"

        for r in rows {
            let encStr = r.isEncrypted ? "AES-256" : "无"
            let compSizeStr = String(format: "%.2f MB (%.1f%%)", Double(r.archiveSizeBytes) / (1024.0 * 1024.0), r.compressionRatioPercent)
            let ttSizeStr = String(format: "%.2f MB (%.1f%%)", Double(r.ttzipArchiveSizeBytes) / (1024.0 * 1024.0), r.ttzipCompressionRatioPercent)
            let cComp = String(format: "%.1f MB/s", r.compressThroughputMBs)
            let cTT = String(format: "%.1f MB/s", r.ttzipCompressMBs)
            let cMult = String(format: "%.1fx", r.compressSpeedupVsCompetitor)
            let eComp = String(format: "%.1f MB/s", r.extractThroughputMBs)
            let eTT = String(format: "%.1f MB/s", r.ttzipExtractMBs)
            let eMult = String(format: "%.1fx", r.extractSpeedupVsCompetitor)
            let aopStr = r.topAopStage.isEmpty ? "-" : r.topAopStage

            md += "| \(r.dimensionName) | \(r.format.rawValue.uppercased()) | \(r.level.rawValue) | \(encStr) | \(r.toolName) | \(compSizeStr) | \(ttSizeStr) | \(cComp) | \(cTT) | **\(cMult)** | \(eComp) | \(eTT) | **\(eMult)** | \(aopStr) |\n"
        }

        try? md.write(to: latestMdURL, atomically: true, encoding: .utf8)
        try? md.write(to: archiveMdURL, atomically: true, encoding: .utf8)
    }

    public static func loadPeakMatrix() -> [String: PeakPerformanceRecord] {
        let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let archiveDir = currentDir.appendingPathComponent("docs/benchmarks")
        let peakMatrixURL = archiveDir.appendingPathComponent("peak_performance_matrix.json")
        if let existingData = try? Data(contentsOf: peakMatrixURL),
           let decoded = try? JSONDecoder().decode([String: PeakPerformanceRecord].self, from: existingData) {
            return decoded
        }
        return [:]
    }

    public static func formatPKTable(
        stepCount: Int,
        totalItems: Int,
        payloadName: String,
        format: ArchiveCompressionFormat,
        level: ArchiveCompressionLevel,
        isEncrypted: Bool,
        ttNameStr: String,
        ttCompSpeed: String,
        ttExtractSpeed: String,
        ttSizeStr: String,
        ttTimeStr: String,
        ttMultStr: String,
        itemCompetitorResults: [(name: String, compDur: Double, compMBs: Double, extractDur: Double, extractMBs: Double, row: CompetitorBenchmarkRow)],
        ttCompMBs: Double
    ) -> String {
        func pad(_ s: String, _ len: Int) -> String {
            if s.count >= len { return s }
            return s + String(repeating: " ", count: len - s.count)
        }

        let key = "\(format.rawValue)_\(level.rawValue)_\(isEncrypted)_\(payloadName)"
        let peakDict = loadPeakMatrix()
        let peakRecord = peakDict[key]

        var peakHeaderExtra = ""
        if let rec = peakRecord {
            peakHeaderExtra = " | 🏛️ 历史最高纪录: 打包 \(String(format: "%.1f MB/s", rec.peakCompressMBs)) / 解压 \(String(format: "%.1f MB/s", rec.peakExtractMBs))"
        }

        let tableHeader = """

        ========================================================================================================================
        ⚔️ [单项全竞品 PK \(stepCount)/\(totalItems)] \(payloadName) | 格式: \(format.rawValue.uppercased()) | 级别: \(level.rawValue) | 加密: \(isEncrypted ? "AES-256" : "无")\(peakHeaderExtra)
        ========================================================================================================================
        │ 引擎 / 软件名称          │ 打包/压缩速率   │ 解压/释放速率   │ 压缩包体积 (压缩率)   │ 实测耗时 (打包/解压)│ TTZip 超越倍数         │
        ------------------------------------------------------------------------------------------------------------------------

        """
        var tableBody = "│ \(ttNameStr) │ \(ttCompSpeed) │ \(ttExtractSpeed) │ \(ttSizeStr) │ \(ttTimeStr) │ \(ttMultStr) │\n"

        if let rec = peakRecord {
            let pNameStr    = pad("🏛️ TTZip (历史最高纪录)", 26)
            let pCompSpeed  = pad(String(format: "%8.1f MB/s", rec.peakCompressMBs), 17)
            let pExtSpeed   = pad(String(format: "%8.1f MB/s", rec.peakExtractMBs), 17)
            let pSizeStr    = pad("---", 22)
            let pTimeStr    = pad("历史峰值数据", 19)
            let pMultStr    = pad("🏆 历史最快基准", 22)
            tableBody += "│ \(pNameStr) │ \(pCompSpeed) │ \(pExtSpeed) │ \(pSizeStr) │ \(pTimeStr) │ \(pMultStr) │\n"
        }

        for res in itemCompetitorResults {
            let compNameStr    = pad("⚡ \(res.name)", 26)
            let compCompSpeed  = pad(res.compDur > 0 ? String(format: "%8.1f MB/s", res.compMBs) : "  直通(只测解压)", 17)
            let compExtSpeed   = pad(String(format: "%8.1f MB/s", res.extractMBs), 17)
            let compSizeMb     = Double(res.row.archiveSizeBytes) / (1024.0 * 1024.0)
            let compRatio      = res.row.compressionRatioPercent
            let compSizeStr    = pad(String(format: "%.2f MB (%.1f%%)", compSizeMb, compRatio), 22)
            let compTimeStr    = pad(res.compDur > 0 ? String(format: "%.3fs / %.3fs", res.compDur, res.extractDur) : String(format: "  跳过 / %.3fs", res.extractDur), 19)
            
            let cMult          = (res.compDur > 0 && res.compMBs > 0) ? (ttCompMBs / res.compMBs) : 1.0
            let compMultStr    = pad(res.compDur == 0 ? "⚡ 直通(专向解压)" : (cMult >= 1.0 ? "🚀 TTZip 打包领先 \(String(format: "%.1f", cMult))x" : "⚡ 竞品打包领先 \(String(format: "%.1f", 1.0 / cMult))x"), 22)

            tableBody += "│ \(compNameStr) │ \(compCompSpeed) │ \(compExtSpeed) │ \(compSizeStr) │ \(compTimeStr) │ \(compMultStr) │\n"
        }

        let tableFooter = "========================================================================================================================"
        return tableHeader + tableBody + tableFooter
    }
}
