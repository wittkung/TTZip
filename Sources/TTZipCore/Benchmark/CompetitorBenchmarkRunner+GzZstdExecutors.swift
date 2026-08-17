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
        let tarBin = CompetitorDetector.findExecutable(names: ["tar", "bsdtar"])
        let zstdBin = CompetitorDetector.findExecutable(names: ["zstd"])
        let payloadName = (payload.path as NSString).lastPathComponent
        let fmtStr = fmt.rawValue.uppercased()
        let encStr = isEnc ? "AES-256" : "无"
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
                runCLI("/bin/sh", ["-c", "\(pigz) -d -p \(cores) -c \"\(compArcPath)\" | tar -xf - -C \"\(compExtract.path)\""])
            } else {
                runCLI("/bin/sh", ["-c", "\(pigz) -d -p \(cores) -c \"\(compArcPath)\" > \"\(compExtract.path)/\(payloadName)\""])
            }
            let t3 = CACurrentMediaTime()

            runToolClosure("Parallel pigz (All Cores)", skipCompetitorCompress ? 0.0 : (t1 - t0), t3 - t2, compArcPath, compExtract.path)
            if !skipCompetitorCompress { try? fm.removeItem(atPath: compArcPath) }
            try? fm.removeItem(at: compExtract)
        }

        // 4.1 libdeflate-gzip
        if (fmt == .sevenZip || fmt == .zip || fmt == .tarGz || fmt == .gz), let libdeflate = libdeflateBin, (isToolSelected("libdeflate") || isToolSelected("libdeflate-gzip") || isToolSelected("libdeflate_gzip")) {
            let compArcPath = skipCompetitorCompress ? ttArc.path : cacheDir.appendingPathComponent("libdeflate_\(UUID().uuidString).\(fmtStr)").path
            let compExtract = cacheDir.appendingPathComponent("libdeflate_out_\(UUID().uuidString)")
            try? fm.createDirectory(at: compExtract, withIntermediateDirectories: true)

            var isDirObj: ObjCBool = false
            FileManager.default.fileExists(atPath: payload.path, isDirectory: &isDirObj)
            let needsTar = isDirObj.boolValue || fmt == .tarGz || fmt == .zip || fmt == .sevenZip

            let clampedLevel = max(1, min(12, lvl.rawValue))
            let gzLevel = "-\(clampedLevel)"
            let t0 = CACurrentMediaTime()
            if !skipCompetitorCompress {
                if needsTar {
                    let pDir = URL(fileURLWithPath: payload.path).deletingLastPathComponent().path
                    let pName = URL(fileURLWithPath: payload.path).lastPathComponent
                    runCLI("/bin/sh", ["-c", "cd \"\(pDir)\" && tar -cf - \"\(pName)\" | \(libdeflate) \(gzLevel) > \"\(compArcPath)\""])
                } else {
                    runCLI("/bin/sh", ["-c", "\(libdeflate) \(gzLevel) -c \"\(payload.path)\" > \"\(compArcPath)\""])
                }
            }
            let t1 = CACurrentMediaTime()

            let t2 = CACurrentMediaTime()
            if needsTar {
                runCLI("/bin/sh", ["-c", "\(libdeflate) -d -c \"\(compArcPath)\" | tar -xf - -C \"\(compExtract.path)\""])
            } else {
                runCLI("/bin/sh", ["-c", "\(libdeflate) -d -c \"\(compArcPath)\" > \"\(compExtract.path)/\(payloadName)\""])
            }
            let t3 = CACurrentMediaTime()

            runToolClosure("libdeflate-gzip CLI", skipCompetitorCompress ? 0.0 : (t1 - t0), t3 - t2, compArcPath, compExtract.path)
            if !skipCompetitorCompress { try? fm.removeItem(atPath: compArcPath) }
            try? fm.removeItem(at: compExtract)
        }
        
        // 4.5. Standard gzip (Fallback if pigz is not available)
        if (fmt == .tarGz || fmt == .gz), pigzBin == nil, isToolSelected("gzip") {
            let gzip = "/usr/bin/gzip"
            let compArcPath = skipCompetitorCompress ? ttArc.path : cacheDir.appendingPathComponent("gzip_\(UUID().uuidString).\(fmtStr)").path
            let compExtract = cacheDir.appendingPathComponent("gzip_out_\(UUID().uuidString)")
            try? fm.createDirectory(at: compExtract, withIntermediateDirectories: true)

            var isDirObj: ObjCBool = false
            FileManager.default.fileExists(atPath: payload.path, isDirectory: &isDirObj)
            let needsTar = isDirObj.boolValue || fmt == .tarGz

            let t0 = CACurrentMediaTime()
            if !skipCompetitorCompress {
                let clampedLevel = max(1, min(9, lvl.rawValue))
                let gzLevel = "-\(clampedLevel)"
                if needsTar {
                    let pDir = URL(fileURLWithPath: payload.path).deletingLastPathComponent().path
                    let pName = URL(fileURLWithPath: payload.path).lastPathComponent
                    runCLI("/bin/sh", ["-c", "cd \"\(pDir)\" && tar -cf - \"\(pName)\" | \(gzip) \(gzLevel) > \"\(compArcPath)\""])
                } else {
                    runCLI("/bin/sh", ["-c", "\(gzip) \(gzLevel) -c \"\(payload.path)\" > \"\(compArcPath)\""])
                }
            }
            let t1 = CACurrentMediaTime()

            let t2 = CACurrentMediaTime()
            if needsTar {
                runCLI("/bin/sh", ["-c", "\(gzip) -d -c \"\(compArcPath)\" | tar -xf - -C \"\(compExtract.path)\""])
            } else {
                runCLI("/bin/sh", ["-c", "\(gzip) -d -c \"\(compArcPath)\" > \"\(compExtract.path)/\(payloadName)\""])
            }
            let t3 = CACurrentMediaTime()

            runToolClosure("gzip (System)", skipCompetitorCompress ? 0.0 : (t1 - t0), t3 - t2, compArcPath, compExtract.path)
            if !skipCompetitorCompress { try? fm.removeItem(atPath: compArcPath) }
            try? fm.removeItem(at: compExtract)
        }

        // 5. System tar
        if let tar = tarBin, (isToolSelected("tar") || isToolSelected("bsdtar")) {
            if fmt == .tarGz && pigzBin == nil {
                let compArcPath = skipCompetitorCompress ? ttArc.path : cacheDir.appendingPathComponent("tar_\(UUID().uuidString).tar.gz").path
                let compExtract = cacheDir.appendingPathComponent("tar_out_\(UUID().uuidString)")
                try? fm.createDirectory(at: compExtract, withIntermediateDirectories: true)

                let t0 = CACurrentMediaTime()
                if !skipCompetitorCompress { runCLI(tar, ["-czf", compArcPath, payload.path]) }
                let t1 = CACurrentMediaTime()

                let t2 = CACurrentMediaTime()
                runCLI(tar, ["-xzf", compArcPath, "-C", compExtract.path])
                let t3 = CACurrentMediaTime()

                runToolClosure("BSD tar (gzip)", skipCompetitorCompress ? 0.0 : (t1 - t0), t3 - t2, compArcPath, compExtract.path)
                if !skipCompetitorCompress { try? fm.removeItem(atPath: compArcPath) }
                try? fm.removeItem(at: compExtract)
            } else if fmt == .zip && !isEnc {
                let compArcPath = skipCompetitorCompress ? ttArc.path : cacheDir.appendingPathComponent("tar_\(UUID().uuidString).zip").path
                let compExtract = cacheDir.appendingPathComponent("tar_out_\(UUID().uuidString)")
                try? fm.createDirectory(at: compExtract, withIntermediateDirectories: true)

                let t0 = CACurrentMediaTime()
                if !skipCompetitorCompress { runCLI(tar, ["-a", "-cf", compArcPath, payload.path]) }
                let t1 = CACurrentMediaTime()

                let t2 = CACurrentMediaTime()
                runCLI(tar, ["-xf", compArcPath, "-C", compExtract.path])
                let t3 = CACurrentMediaTime()

                runToolClosure("BSD tar (zip)", skipCompetitorCompress ? 0.0 : (t1 - t0), t3 - t2, compArcPath, compExtract.path)
                if !skipCompetitorCompress { try? fm.removeItem(atPath: compArcPath) }
                try? fm.removeItem(at: compExtract)
            } else if (fmt == .zst || fmt == .tarZst) {
                let compArc = cacheDir.appendingPathComponent("tar_\(UUID().uuidString).tar.zst")
                let compExtract = cacheDir.appendingPathComponent("tar_out_\(UUID().uuidString)")
                try? fm.createDirectory(at: compExtract, withIntermediateDirectories: true)

                let zLevel = lvl.rawValue < 0 ? "--fast=\(-lvl.rawValue)" : "-\(lvl.rawValue)"
                var zI = "zstd \(zLevel) -T0"
                if lvl.rawValue >= 9 { zI += " --ultra" }
                if let dpath = compDictPath, !dpath.isEmpty {
                    zI += " -D \(dpath)"
                }
                
                let t0 = CACurrentMediaTime()
                runCLI("/bin/sh", ["-c", "tar -cf - \"\(payload.path)\" | \(zI) > \"\(compArc.path)\""])
                let t1 = CACurrentMediaTime()

                let t2 = CACurrentMediaTime()
                var zIDec = "zstd -d -T0"
                if let dpath = compDictPath, !dpath.isEmpty {
                    zIDec += " -D \(dpath)"
                }
                runCLI("/bin/sh", ["-c", "\(zIDec) -c \"\(compArc.path)\" | tar -xf - -C \"\(compExtract.path)\""])
                let t3 = CACurrentMediaTime()

                runToolClosure("BSD tar (zstd)", t1 - t0, t3 - t2, compArc.path, compExtract.path)
                try? fm.removeItem(at: compArc)
                try? fm.removeItem(at: compExtract)
            }
        }

        var isDir: ObjCBool = false
        let isPayloadDir = fm.fileExists(atPath: payload.path, isDirectory: &isDir) && isDir.boolValue
        
        // 6. Zstandard zstd
        if (fmt == .zst || fmt == .tarZst) && !isPayloadDir, let zstd = zstdBin, isToolSelected("zstd") {
            let compArc = cacheDir.appendingPathComponent("zstd_\(UUID().uuidString).zst")
            let compExtract = cacheDir.appendingPathComponent("zstd_out_\(UUID().uuidString)")
            try? fm.createDirectory(at: compExtract, withIntermediateDirectories: true)

            let zLevel = lvl.rawValue < 0 ? "--fast=\(-lvl.rawValue)" : "-\(lvl.rawValue)"
            var zArgs = ["-T0", zLevel, payload.path, "-o", compArc.path, "-f"]
            if lvl.rawValue >= 9 { zArgs.append("--ultra") }
            if let dpath = compDictPath, !dpath.isEmpty {
                zArgs.append(contentsOf: ["-D", dpath])
            }
            let t0 = CACurrentMediaTime()
            runCLI(zstd, zArgs)
            let t1 = CACurrentMediaTime()

            let t2 = CACurrentMediaTime()
            var decArgs = ["-d", "-T0", compArc.path, "-o", compExtract.appendingPathComponent("decompressed_out").path, "-f"]
            if let dpath = compDictPath, !dpath.isEmpty {
                decArgs.append(contentsOf: ["-D", dpath])
            }
            runCLI(zstd, decArgs)
            let t3 = CACurrentMediaTime()

            runToolClosure("Zstandard zstd (Thread=0)", t1 - t0, t3 - t2, compArc.path, compExtract.path)
            try? fm.removeItem(at: compArc)
            try? fm.removeItem(at: compExtract)
        }
    }
}
