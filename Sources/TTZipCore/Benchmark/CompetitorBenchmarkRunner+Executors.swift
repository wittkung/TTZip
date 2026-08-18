// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

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
            return true
        }

        let runToolClosure: (String, Double, Double, String, String) -> Void = { label, cDur, eDur, compArcPath, compExtractPath in
            let cDurSafe = max(1e-6, cDur)
            let eDurSafe = max(1e-6, eDur)
            let cMBs = (Double(payload.bytes) / (1024.0 * 1024.0)) / cDurSafe
            let eMBs = (Double(payload.bytes) / (1024.0 * 1024.0)) / eDurSafe
            let sz = (try? fm.attributesOfItem(atPath: compArcPath)[.size] as? Int64) ?? ttArcSize
            let ratio = payload.bytes > 0 ? (Double(sz) / Double(payload.bytes)) * 100.0 : 100.0
            let ttRatio = payload.bytes > 0 ? (Double(ttArcSize) / Double(payload.bytes)) * 100.0 : 100.0

            let compSpeedup = cMBs > 0 ? (ttCompMBs / cMBs) : 1.0
            let extractSpeedup = eMBs > 0 ? (ttExtractMBs / eMBs) : 1.0

            let row = CompetitorBenchmarkRow(
                toolName: label,
                dimensionName: payload.name,
                format: fmt,
                level: lvl,
                isEncrypted: isEnc,
                datasetSizeBytes: payload.bytes,
                archiveSizeBytes: sz,
                compressDurationSeconds: cDurSafe,
                compressThroughputMBs: cMBs,
                extractDurationSeconds: eDurSafe,
                extractThroughputMBs: eMBs,
                compressionRatioPercent: ratio,
                ttzipArchiveSizeBytes: ttArcSize,
                ttzipCompressionRatioPercent: ttRatio,
                ttzipCompressMBs: ttCompMBs,
                ttzipExtractMBs: ttExtractMBs,
                compressSpeedupVsCompetitor: compSpeedup,
                extractSpeedupVsCompetitor: extractSpeedup,
                topAopStage: ttCompressAopStage
            )
            itemCompetitorResults.append(ExecutedToolResult(
                name: label,
                compDur: cDur,
                compMBs: cMBs,
                extractDur: eDur,
                extractMBs: eMBs,
                row: row
            ))
        }

        let sevenZipBin = CompetitorDetector.findExecutable(names: ["7zz", "7z"])
        let fmtStr = fmt.rawValue.uppercased()
        let encStr = isEnc ? "AES-256" : "None"
        let skipCompetitorCompress = (loadedFilter?.shouldSkipCompress(pkIdx: stepCount, payload: payload.name, format: fmtStr, level: lvl.rawValue, encryption: encStr) ?? false) && !isEnc

        // 1. 7-Zip CLI (7zz)
        if (fmt == .sevenZip || fmt == .zip || fmt == .tar), let szBin = sevenZipBin, isToolSelected("7zz") || isToolSelected("7z") {
            let compArcPath = skipCompetitorCompress ? ttArc.path : cacheDir.appendingPathComponent("7zz_\(UUID().uuidString).\(fmt.rawValue)").path
            let compExtract = cacheDir.appendingPathComponent("7zz_out_\(UUID().uuidString)")
            try? fm.createDirectory(at: compExtract, withIntermediateDirectories: true)

            var compDur = 1e-6
            var extractDur = 1e-6
            let passCount = (payload.bytes <= 15 * 1024 * 1024) ? 3 : 1
            var bestComp = Double.infinity
            var bestExt = Double.infinity

            for _ in 0..<passCount {
                if !skipCompetitorCompress {
                    var compArgs = ["a", compArcPath, payload.path, "-mx=\(lvl.rawValue)", "-mmt=on", "-y"]
                    if isEnc {
                        compArgs.append("-pP@ssw0rd2026!")
                        if fmt == .sevenZip { compArgs.append("-mhe=on") }
                    }
                    let t0 = CACurrentMediaTime()
                    _ = runCLI(szBin, compArgs)
                    let t1 = CACurrentMediaTime()
                    bestComp = min(bestComp, max(1e-6, t1 - t0))
                }

                var extArgs = ["x", compArcPath, "-o\(compExtract.path)", "-y"]
                if isEnc { extArgs.append("-pP@ssw0rd2026!") }
                let t2 = CACurrentMediaTime()
                _ = runCLI(szBin, extArgs)
                let t3 = CACurrentMediaTime()
                bestExt = min(bestExt, max(1e-6, t3 - t2))
            }

            compDur = skipCompetitorCompress ? 0 : bestComp
            extractDur = bestExt
            runToolClosure("7-Zip 7zz CLI (ARM64)", compDur, extractDur, compArcPath, compExtract.path)

            if !skipCompetitorCompress { try? fm.removeItem(atPath: compArcPath) }
            try? fm.removeItem(at: compExtract)
        }

        // 2. Apple Native ditto
        if fmt == .zip && !isEnc, isToolSelected("ditto") || isToolSelected("apple") {
            let compArcPath = cacheDir.appendingPathComponent("ditto_\(UUID().uuidString).zip").path
            let compExtract = cacheDir.appendingPathComponent("ditto_out_\(UUID().uuidString)")
            try? fm.createDirectory(at: compExtract, withIntermediateDirectories: true)

            let t0 = CACurrentMediaTime()
            _ = runCLI("/usr/bin/ditto", ["-c", "-k", "--keepParent", payload.path, compArcPath])
            let t1 = CACurrentMediaTime()

            let t2 = CACurrentMediaTime()
            _ = runCLI("/usr/bin/ditto", ["-x", "-k", compArcPath, compExtract.path])
            let t3 = CACurrentMediaTime()

            runToolClosure("Apple ditto (Native macOS)", t1 - t0, t3 - t2, compArcPath, compExtract.path)
            try? fm.removeItem(atPath: compArcPath)
            try? fm.removeItem(at: compExtract)
        }

        // 3. System tar
        if fmt == .tar && !isEnc, isToolSelected("tar") || isToolSelected("system tar") {
            let compArcPath = cacheDir.appendingPathComponent("tar_\(UUID().uuidString).tar").path
            let compExtract = cacheDir.appendingPathComponent("tar_out_\(UUID().uuidString)")
            try? fm.createDirectory(at: compExtract, withIntermediateDirectories: true)

            let pDir = URL(fileURLWithPath: payload.path).deletingLastPathComponent().path
            let pName = URL(fileURLWithPath: payload.path).lastPathComponent

            let t0 = CACurrentMediaTime()
            _ = runCLI("/usr/bin/tar", ["-cf", compArcPath, "-C", pDir, pName])
            let t1 = CACurrentMediaTime()

            let t2 = CACurrentMediaTime()
            _ = runCLI("/usr/bin/tar", ["-xf", compArcPath, "-C", compExtract.path])
            let t3 = CACurrentMediaTime()

            runToolClosure("System tar (Native BSD)", t1 - t0, t3 - t2, compArcPath, compExtract.path)
            try? fm.removeItem(atPath: compArcPath)
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

        if autoBestCompetitor && itemCompetitorResults.count > 1 {
            if let bestComp = itemCompetitorResults.max(by: { $0.compMBs < $1.compMBs }) {
                return [bestComp]
            }
        }

        return itemCompetitorResults
    }
}
