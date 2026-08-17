import Foundation
import QuartzCore

extension CompetitorBenchmarkRunner {
    @discardableResult
    public static func runCLI(_ executable: String, _ arguments: [String], currentDirectory: String? = nil) -> Bool {
        return TTZipProcessExecutor.runCLI(executable, arguments, currentDirectory: currentDirectory)
    }

    public static func folderSize(_ path: String) throws -> Int64 {
        let component = ArchiveComponentTreeBuilder.buildTree(fromDiskPath: path)
        return component.sizeBytes
    }

    internal struct ExecutedToolResult: Sendable {
        let name: String
        let compDur: Double
        let compMBs: Double
        let extractDur: Double
        let extractMBs: Double
        let row: CompetitorBenchmarkRow
    }

    internal static func runCompetitorTools(
        payload: (name: String, path: String, bytes: Int64),
        fmt: ArchiveCompressionFormat,
        lvl: ArchiveCompressionLevel,
        isEnc: Bool,
        stepCount: Int,
        ttArc: URL,
        ttArcSize: Int64,
        ttCompMBs: Double,
        ttExtractMBs: Double,
        ttCompressAopStage: String = "-",
        stopOnLagOrError: Bool,
        selectedTools: [String]?,
        autoBestCompetitor: Bool = false,
        loadedFilter: TargetedBenchmarkFilter?,
        cacheDir: URL,
        compDictPath: String?,
        progressHandler: (@Sendable (String) -> Void)?
    ) -> [ExecutedToolResult] {
        var itemCompetitorResults: [ExecutedToolResult] = []
        let fm = FileManager.default

        let isToolSelected: (String) -> Bool = { tKey in
            if let selected = selectedTools, !selected.isEmpty {
                let normSelected = selected.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
                let normKey = tKey.lowercased()
                return normSelected.contains { k in
                    if k == normKey { return true }
                    if k == "7z" || k == "7zz" || k == "7zip" {
                        return normKey.contains("7z") || normKey.contains("7zz")
                    }
                    if k == "apple" || k == "native" || k == "ditto" {
                        return normKey.contains("ditto") || normKey.contains("apple")
                    }
                    return normKey == k
                }
            }
            if autoBestCompetitor {
                let k = tKey.lowercased()
                if fmt == .zip {
                    // 仅保留最强单项竞品: 7-Zip (7zz 多线程极速标杆)
                    return k == "7z" || k == "7zz" || k == "7zip"
                } else if fmt == .sevenZip {
                    return k == "7z" || k == "7zz" || k == "7zip"
                } else if fmt == .gz || fmt == .tarGz {
                    return k == "pigz" || k == "gz" || k == "7z" || k == "7zz"
                } else if fmt == .zst || fmt == .tarZst {
                    return k == "zstd" || k == "zst"
                }
            }
            return true
        }

        let dittoBin = CompetitorDetector.findExecutable(names: ["ditto"])
        let sevenZipBin = CompetitorDetector.findExecutable(names: ["7zz", "7z"])
        _ = CompetitorDetector.findExecutable(names: ["keka7zz", "keka7z", "kekaexec", "keka"])
        _ = CompetitorDetector.findExecutable(names: ["7za", "betterzip"])
        let zipBin = CompetitorDetector.findExecutable(names: ["zip"])
        let unzipBin = CompetitorDetector.findExecutable(names: ["unzip"])

        let runToolClosure = { (tName: String, cDur: Double, eDur: Double, arcPath: String, extractPath: String) in
            let arcSize = (try? fm.attributesOfItem(atPath: arcPath)[.size] as? Int64) ?? 0
            guard arcSize > 0 else {
                if stopOnLagOrError {
                    TTLogger.error("\n❌ [单项对比中断 / 归档不可用] 竞品 \(tName) 在场景 [\(payload.name) | 级别: L\(lvl.rawValue)] 中生成归档失败！按协议立即强行中止压测！\n")
                    exit(1)
                }
                return
            }
            let checker = ArchiveEngineFactory.makeIntegrityChecker()
            let checkResult = checker.verifyExtractedDirectory(
                directoryPath: extractPath,
                expectedOriginalBytes: payload.bytes,
                sourceFilePath: payload.path,
                label: tName
            )
            guard checkResult.isValid else {
                if stopOnLagOrError {
                    TTLogger.error("\n❌ [单项对比中断 / 哈希校验未通过] 竞品 \(tName) 在场景 [\(payload.name) | 级别: L\(lvl.rawValue)] 下解压产物与源文件 CRC32 不符！按协议立即强行中止压测！\n")
                    exit(1)
                }
                return
            }
            let cMBs = cDur > 0 ? ((Double(payload.bytes) / (1024.0 * 1024.0)) / max(0.001, cDur)) : 0.0
            let eMBs = (Double(payload.bytes) / (1024.0 * 1024.0)) / max(0.001, eDur)

            if stopOnLagOrError {
                let margin = 1.05
                if cDur > 0 && cMBs > (ttCompMBs * margin) {
                    TTLogger.error("\n❌ [未实现全量霸榜 / 打包被竞品超越] 竞品 \(tName) 在场景 [\(payload.name) | 级别: L\(lvl.rawValue) | 加密: \(isEnc ? "AES-256" : "无")] 下打包速度超越 TTZip！\n    ├─ 竞品 \(tName) 打包速率: \(String(format: "%.1f MB/s", cMBs))\n    └─ TTZip 打包速率: \(String(format: "%.1f MB/s", ttCompMBs))\n按协议立即强行中止压测！\n")
                    exit(1)
                }
                if eMBs > (ttExtractMBs * margin) {
                    TTLogger.error("\n❌ [未实现全量霸榜 / 解压被竞品超越] 竞品 \(tName) 在场景 [\(payload.name) | 级别: L\(lvl.rawValue) | 加密: \(isEnc ? "AES-256" : "无")] 下解压速度超越 TTZip！\n    ├─ 竞品 \(tName) 解压速率: \(String(format: "%.1f MB/s", eMBs))\n    └─ TTZip 解压速率: \(String(format: "%.1f MB/s", ttExtractMBs))\n按协议立即强行中止压测！\n")
                    exit(1)
                }
            }

            let ratioPct = payload.bytes > 0 ? (Double(arcSize) / Double(payload.bytes)) * 100.0 : 100.0
            let ttRatioPct = payload.bytes > 0 ? (Double(ttArcSize) / Double(payload.bytes)) * 100.0 : 100.0
            let cMult = cMBs > 0 ? (ttCompMBs / cMBs) : 1.0
            let eMult = eMBs > 0 ? (ttExtractMBs / eMBs) : 1.0

            progressHandler?("⚡ [\(tName)] 对比测试完成 | 打包速率: \(cDur > 0 ? String(format: "%.1f MB/s", cMBs) : "直通(只测解压)") (\(String(format: "%.3fs", cDur))) | 解压速率: \(String(format: "%.1f MB/s", eMBs)) (\(String(format: "%.3fs", eDur))) | 产物体积: \(String(format: "%.2f MB", Double(arcSize) / (1024.0 * 1024.0))) (\(String(format: "%.1f%%", ratioPct)))")

            let cRow = CompetitorBenchmarkRow(
                toolName: tName,
                dimensionName: payload.name,
                format: fmt,
                level: lvl,
                isEncrypted: isEnc,
                datasetSizeBytes: payload.bytes,
                archiveSizeBytes: arcSize,
                compressDurationSeconds: cDur,
                compressThroughputMBs: cMBs,
                extractDurationSeconds: eDur,
                extractThroughputMBs: eMBs,
                compressionRatioPercent: ratioPct,
                ttzipArchiveSizeBytes: ttArcSize,
                ttzipCompressionRatioPercent: ttRatioPct,
                ttzipCompressMBs: ttCompMBs,
                ttzipExtractMBs: ttExtractMBs,
                compressSpeedupVsCompetitor: cMult,
                extractSpeedupVsCompetitor: eMult,
                topAopStage: ttCompressAopStage
            )
            itemCompetitorResults.append(ExecutedToolResult(
                name: tName,
                compDur: cDur,
                compMBs: cMBs,
                extractDur: eDur,
                extractMBs: eMBs,
                row: cRow
            ))
        }

        let payloadDir = (payload.path as NSString).deletingLastPathComponent
        let payloadName = (payload.path as NSString).lastPathComponent

        let encStr = isEnc ? "AES-256" : "无"
        let fmtStr = fmt.rawValue.uppercased()
        let skipCompetitorCompress = (loadedFilter?.shouldSkipCompress(pkIdx: stepCount, payload: payload.name, format: fmtStr, level: lvl.rawValue, encryption: encStr) ?? false) && !isEnc

        // 1. ditto
        if fmt == .zip, let ditto = dittoBin, !isEnc, (isToolSelected("ditto") || isToolSelected("apple") || isToolSelected("native")) {
            let compArcPath = skipCompetitorCompress ? ttArc.path : cacheDir.appendingPathComponent("ditto_\(UUID().uuidString).zip").path
            let compExtract = cacheDir.appendingPathComponent("ditto_out_\(UUID().uuidString)")
            try? fm.createDirectory(at: compExtract, withIntermediateDirectories: true)

            progressHandler?("⚡ [Apple ditto (Native)] 对比测试启动中...")

            let t0 = PlatformMonotonicTimer.nowSeconds()
            if !skipCompetitorCompress { runCLI(ditto, ["-c", "-k", "--keepParent", payloadName, compArcPath], currentDirectory: payloadDir) }
            let t1 = PlatformMonotonicTimer.nowSeconds()
            let t2 = PlatformMonotonicTimer.nowSeconds()
            runCLI(ditto, ["-x", "-k", compArcPath, compExtract.path])
            let t3 = PlatformMonotonicTimer.nowSeconds()

            runToolClosure("Apple ditto (Native)", skipCompetitorCompress ? 0.0 : (t1 - t0), t3 - t2, compArcPath, compExtract.path)
            if !skipCompetitorCompress { try? fm.removeItem(atPath: compArcPath) }
            try? fm.removeItem(at: compExtract)
        }

        // 2. 7-Zip (7zz)
        if (fmt == .zip || fmt == .sevenZip || fmt == .wim || fmt == .tar), let sz = sevenZipBin, (isToolSelected("7z") || isToolSelected("7zz") || isToolSelected("7zip")) {
            let fmtStr = fmt == .zip ? "zip" : (fmt == .tar ? "tar" : "7z")
            let compArcPath = skipCompetitorCompress ? ttArc.path : cacheDir.appendingPathComponent("7zz_\(UUID().uuidString).\(fmtStr)").path
            let compExtract = cacheDir.appendingPathComponent("7zz_out_\(UUID().uuidString)")
            try? fm.createDirectory(at: compExtract, withIntermediateDirectories: true)

            progressHandler?("⚡ [7-Zip 7zz CLI] 对比测试启动中...")

            let compPasses = 1
            var bestCompDur = Double.infinity
            var bestExtractDur = Double.infinity
            var okComp = true
            var okExt = true
            var validExtDir = compExtract.path + "_out"

            let mxLevel = "\(lvl.rawValue)"
            var args = ["a", "-t\(fmtStr)", "-mx=\(mxLevel)", "-mmt=on", "-bsp0"]
            if fmt == .sevenZip && lvl.rawValue >= 8 { args.append("-md=64m"); args.append("-ms=on"); args.append("-myx=9") }
            if fmt == .zip && lvl.rawValue >= 8 { args.append("-myx=9") }
            if isEnc {
                if fmt == .sevenZip { args.append("-mhe=on") } else { args.append("-mem=AES256") }
                args.append("-pP@ssw0rd2026!")
            }
            args.append(compArcPath)
            args.append(payloadName)

            for _ in 0..<compPasses {
                if !skipCompetitorCompress { try? fm.removeItem(atPath: compArcPath) }
                let t0 = PlatformMonotonicTimer.nowSeconds()
                if !skipCompetitorCompress {
                    okComp = runCLI(sz, args, currentDirectory: payloadDir)
                }
                let t1 = PlatformMonotonicTimer.nowSeconds()
                if okComp {
                    bestCompDur = min(bestCompDur, max(0.001, t1 - t0))
                }

                validExtDir = compExtract.path + "_out"
                try? fm.removeItem(atPath: validExtDir)
                try? fm.createDirectory(atPath: validExtDir, withIntermediateDirectories: true)
                var passExArgs = ["x", "-mmt=on", "-bsp0", compArcPath, "-o" + validExtDir + "/", "-y"]
                if isEnc { passExArgs.append("-pP@ssw0rd2026!") }

                let t2 = PlatformMonotonicTimer.nowSeconds()
                okExt = runCLI(sz, passExArgs)
                let t3 = PlatformMonotonicTimer.nowSeconds()
                if okExt {
                    bestExtractDur = min(bestExtractDur, max(0.001, t3 - t2))
                }
            }

            if okComp && okExt && bestExtractDur < Double.infinity {
                let label = fmt == .zip ? "7-Zip 7zz (Max Multithread)" : "7-Zip 7zz CLI"
                runToolClosure(label, skipCompetitorCompress ? 0.0 : bestCompDur, bestExtractDur, compArcPath, validExtDir)
            }
            if !skipCompetitorCompress { try? fm.removeItem(atPath: compArcPath) }
            try? fm.removeItem(at: compExtract)
        }

        // 3. Info-ZIP
        if fmt == .zip, let zipPath = zipBin, let unzipPath = unzipBin, !isEnc, (isToolSelected("infozip") || isToolSelected("info-zip")) {
            let compArcPath = skipCompetitorCompress ? ttArc.path : cacheDir.appendingPathComponent("infozip_\(UUID().uuidString).zip").path
            let compExtract = cacheDir.appendingPathComponent("infozip_out_\(UUID().uuidString)")
            try? fm.createDirectory(at: compExtract, withIntermediateDirectories: true)

            let t0 = PlatformMonotonicTimer.nowSeconds()
            if !skipCompetitorCompress {
                let zipLvl = "-\(lvl.rawValue)"
                runCLI(zipPath, ["-r", "-q", zipLvl, compArcPath, payload.path])
            }
            let t1 = PlatformMonotonicTimer.nowSeconds()

            let t2 = PlatformMonotonicTimer.nowSeconds()
            runCLI(unzipPath, ["-q", compArcPath, "-d", compExtract.path])
            let t3 = PlatformMonotonicTimer.nowSeconds()

            runToolClosure("Info-ZIP (System)", skipCompetitorCompress ? 0.0 : (t1 - t0), t3 - t2, compArcPath, compExtract.path)
            if !skipCompetitorCompress { try? fm.removeItem(atPath: compArcPath) }
            try? fm.removeItem(at: compExtract)
        }

        // 4. BSD tar
        if fmt == .tar, !isEnc, (isToolSelected("tar") || isToolSelected("bsdtar") || isToolSelected("apple")) {
            let compArcPath = skipCompetitorCompress ? ttArc.path : cacheDir.appendingPathComponent("tar_\(UUID().uuidString).tar").path
            let compExtract = cacheDir.appendingPathComponent("tar_out_\(UUID().uuidString)")
            try? fm.createDirectory(at: compExtract, withIntermediateDirectories: true)

            progressHandler?("⚡ [BSD tar (Native)] 对比测试启动中...")

            let t0 = PlatformMonotonicTimer.nowSeconds()
            if !skipCompetitorCompress { runCLI("/usr/bin/tar", ["-cf", compArcPath, "-C", payloadDir, payloadName]) }
            let t1 = PlatformMonotonicTimer.nowSeconds()
            let t2 = PlatformMonotonicTimer.nowSeconds()
            runCLI("/usr/bin/tar", ["-xf", compArcPath, "-C", compExtract.path])
            let t3 = PlatformMonotonicTimer.nowSeconds()

            runToolClosure("BSD tar (Native)", skipCompetitorCompress ? 0.0 : (t1 - t0), t3 - t2, compArcPath, compExtract.path)
            if !skipCompetitorCompress { try? fm.removeItem(atPath: compArcPath) }
            try? fm.removeItem(at: compExtract)
        }

        runGzZstdCompetitorTools(
            payload: payload,
            fmt: fmt,
            lvl: lvl,
            isEnc: isEnc,
            stepCount: stepCount,
            ttArc: ttArc,
            ttArcSize: ttArcSize,
            ttCompMBs: ttCompMBs,
            ttExtractMBs: ttExtractMBs,
            stopOnLagOrError: stopOnLagOrError,
            selectedTools: selectedTools,
            loadedFilter: loadedFilter,
            cacheDir: cacheDir,
            compDictPath: compDictPath,
            progressHandler: progressHandler,
            isToolSelected: isToolSelected,
            runToolClosure: runToolClosure
        )

        runExtendedCompetitorTools(
            payload: payload,
            fmt: fmt,
            lvl: lvl,
            isEnc: isEnc,
            stepCount: stepCount,
            ttArc: ttArc,
            ttArcSize: ttArcSize,
            ttCompMBs: ttCompMBs,
            ttExtractMBs: ttExtractMBs,
            stopOnLagOrError: stopOnLagOrError,
            selectedTools: selectedTools,
            loadedFilter: loadedFilter,
            cacheDir: cacheDir,
            compDictPath: compDictPath,
            progressHandler: progressHandler,
            isToolSelected: isToolSelected,
            runToolClosure: runToolClosure
        )

        return itemCompetitorResults
    }
}
