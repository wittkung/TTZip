// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import QuartzCore

extension CompetitorBenchmarkRunner {
    internal static func runGzZstdCompetitorTools(
        payload: (name: String, path: String, bytes: Int64),
        fmt: ArchiveCompressionFormat,
        lvl: ArchiveCompressionLevel,
        isEnc: Bool,
        stepCount: Int,
        ttArc: URL,
        ttArcSize: Int64,
        ttCompMBs: Double,
        ttExtractMBs: Double,
        stopOnLagOrError: Bool,
        selectedTools: [String]?,
        loadedFilter: TargetedBenchmarkFilter?,
        cacheDir: URL,
        compDictPath: String?,
        progressHandler: (@Sendable (String) -> Void)?,
        isToolSelected: (String) -> Bool,
        runToolClosure: (String, Double, Double, String, String) -> Void
    ) {
        let fm = FileManager.default
        let pigzBin = CompetitorDetector.findExecutable(names: ["pigz"])
        let libdeflateBin = CompetitorDetector.findExecutable(names: ["libdeflate-gzip"])
        let zstdBin = CompetitorDetector.findExecutable(names: ["zstd"])
        let payloadName = (payload.path as NSString).lastPathComponent
        let fmtStr = fmt.rawValue.uppercased()
        let encStr = isEnc ? "AES-256" : "None"
        let skipCompetitorCompress = (loadedFilter?.shouldSkipCompress(pkIdx: stepCount, payload: payload.name, format: fmtStr, level: lvl.rawValue, encryption: encStr) ?? false) && !isEnc

        // 4. Parallel pigz
        if (fmt == .tarGz || fmt == .gz), let pigz = pigzBin, isToolSelected("pigz") {
            let compArcPath = skipCompetitorCompress ? ttArc.path : cacheDir.appendingPathComponent("pigz_\(UUID().uuidString).\(fmtStr)").path
            let compExtract = cacheDir.appendingPathComponent("pigz_out_\(UUID().uuidString)")
            try? fm.createDirectory(at: compExtract, withIntermediateDirectories: true)

            var isDirObj: ObjCBool = false
            FileManager.default.fileExists(atPath: payload.path, isDirectory: &isDirObj)
            let needsTar = isDirObj.boolValue || fmt == .tarGz

            let cores = AppleSiliconTuner.shared.topology.totalCores
            let t0 = CACurrentMediaTime()
            if !skipCompetitorCompress {
                let clampedLevel = max(1, min(9, lvl.rawValue))
                let gzLevel = "-\(clampedLevel)"
                if needsTar {
                    let pDir = URL(fileURLWithPath: payload.path).deletingLastPathComponent().path
                    let pName = URL(fileURLWithPath: payload.path).lastPathComponent
                    runCLI("/bin/sh", ["-c", "cd \"\(pDir)\" && tar -cf - \"\(pName)\" | \(pigz) \(gzLevel) -p \(cores) > \"\(compArcPath)\""])
                } else {
                    runCLI("/bin/sh", ["-c", "\(pigz) \(gzLevel) -p \(cores) -c \"\(payload.path)\" > \"\(compArcPath)\""])
                }
            }
            let t1 = CACurrentMediaTime()

            let t2 = CACurrentMediaTime()
            if needsTar {
                runCLI("/bin/sh", ["-c", "\(pigz) -d -c \"\(compArcPath)\" | tar -xf - -C \"\(compExtract.path)\""])
            } else {
                runCLI("/bin/sh", ["-c", "\(pigz) -d -c \"\(compArcPath)\" > \"\(compExtract.path)/\(payloadName)\""])
            }
            let t3 = CACurrentMediaTime()

            runToolClosure("Parallel pigz (Multi-threaded GZIP)", skipCompetitorCompress ? 0 : t1 - t0, t3 - t2, compArcPath, compExtract.path)
            if !skipCompetitorCompress { try? fm.removeItem(atPath: compArcPath) }
            try? fm.removeItem(at: compExtract)
        }

        // 5. libdeflate-gzip CLI
        if (fmt == .tarGz || fmt == .gz), let ldef = libdeflateBin, isToolSelected("libdeflate") || isToolSelected("libdeflate-gzip") {
            let compArcPath = skipCompetitorCompress ? ttArc.path : cacheDir.appendingPathComponent("libdeflate_\(UUID().uuidString).\(fmtStr)").path
            let compExtract = cacheDir.appendingPathComponent("libdeflate_out_\(UUID().uuidString)")
            try? fm.createDirectory(at: compExtract, withIntermediateDirectories: true)

            var isDirObj: ObjCBool = false
            FileManager.default.fileExists(atPath: payload.path, isDirectory: &isDirObj)
            let needsTar = isDirObj.boolValue || fmt == .tarGz

            let t0 = CACurrentMediaTime()
            if !skipCompetitorCompress {
                let clampedLevel = max(1, min(12, lvl.rawValue))
                if needsTar {
                    let pDir = URL(fileURLWithPath: payload.path).deletingLastPathComponent().path
                    let pName = URL(fileURLWithPath: payload.path).lastPathComponent
                    runCLI("/bin/sh", ["-c", "cd \"\(pDir)\" && tar -cf - \"\(pName)\" | \(ldef) -\(clampedLevel) > \"\(compArcPath)\""])
                } else {
                    runCLI("/bin/sh", ["-c", "\(ldef) -\(clampedLevel) -c \"\(payload.path)\" > \"\(compArcPath)\""])
                }
            }
            let t1 = CACurrentMediaTime()

            let t2 = CACurrentMediaTime()
            if needsTar {
                runCLI("/bin/sh", ["-c", "\(ldef) -d -c \"\(compArcPath)\" | tar -xf - -C \"\(compExtract.path)\""])
            } else {
                runCLI("/bin/sh", ["-c", "\(ldef) -d -c \"\(compArcPath)\" > \"\(compExtract.path)/\(payloadName)\""])
            }
            let t3 = CACurrentMediaTime()

            runToolClosure("libdeflate-gzip (C Fast Path)", skipCompetitorCompress ? 0 : t1 - t0, t3 - t2, compArcPath, compExtract.path)
            if !skipCompetitorCompress { try? fm.removeItem(atPath: compArcPath) }
            try? fm.removeItem(at: compExtract)
        }

        // 6. Zstandard zstd CLI
        if (fmt == .tarZst || fmt == .zst), let zstd = zstdBin, isToolSelected("zstd") {
            let compArcPath = skipCompetitorCompress ? ttArc.path : cacheDir.appendingPathComponent("zstd_\(UUID().uuidString).\(fmtStr)").path
            let compExtract = cacheDir.appendingPathComponent("zstd_out_\(UUID().uuidString)")
            try? fm.createDirectory(at: compExtract, withIntermediateDirectories: true)

            var isDirObj: ObjCBool = false
            FileManager.default.fileExists(atPath: payload.path, isDirectory: &isDirObj)
            let needsTar = isDirObj.boolValue || fmt == .tarZst

            let cores = AppleSiliconTuner.shared.topology.totalCores
            let t0 = CACurrentMediaTime()
            if !skipCompetitorCompress {
                let clampedLevel = max(1, min(19, lvl.rawValue))
                if needsTar {
                    let pDir = URL(fileURLWithPath: payload.path).deletingLastPathComponent().path
                    let pName = URL(fileURLWithPath: payload.path).lastPathComponent
                    runCLI("/bin/sh", ["-c", "cd \"\(pDir)\" && tar -cf - \"\(pName)\" | \(zstd) -\(clampedLevel) -T\(cores) -q -o \"\(compArcPath)\""])
                } else {
                    runCLI("/bin/sh", ["-c", "\(zstd) -\(clampedLevel) -T\(cores) -q -c \"\(payload.path)\" -o \"\(compArcPath)\""])
                }
            }
            let t1 = CACurrentMediaTime()

            let t2 = CACurrentMediaTime()
            if needsTar {
                runCLI("/bin/sh", ["-c", "\(zstd) -d -T\(cores) -q -c \"\(compArcPath)\" | tar -xf - -C \"\(compExtract.path)\""])
            } else {
                runCLI("/bin/sh", ["-c", "\(zstd) -d -T\(cores) -q -c \"\(compArcPath)\" > \"\(compExtract.path)/\(payloadName)\""])
            }
            let t3 = CACurrentMediaTime()

            runToolClosure("Zstandard zstd CLI (-T0 All Cores)", skipCompetitorCompress ? 0 : t1 - t0, t3 - t2, compArcPath, compExtract.path)
            if !skipCompetitorCompress { try? fm.removeItem(atPath: compArcPath) }
            try? fm.removeItem(at: compExtract)
        }
    }
}
