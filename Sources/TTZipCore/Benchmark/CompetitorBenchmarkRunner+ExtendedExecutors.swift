import Foundation
import QuartzCore

extension CompetitorBenchmarkRunner {
    internal static func runExtendedCompetitorTools(
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
        let cores = AppleSiliconTuner.shared.topology.totalCores

        // 7. BZIP2 (pbzip2 / bzip2)
        if (fmt == .bz2 || fmt == .tarBz2), isToolSelected("pbzip2") || isToolSelected("bzip2") || isToolSelected("pbz2") {
            let pbzip2 = CompetitorDetector.findExecutable(names: ["pbzip2"])
            let bzip2 = CompetitorDetector.findExecutable(names: ["bzip2"])
            if let bin = pbzip2 ?? bzip2 {
                let label = pbzip2 != nil ? "pbzip2 (All Cores)" : "bzip2 (System)"
                let compArc = cacheDir.appendingPathComponent("bz2_\(UUID().uuidString).tar.bz2")
                let compExtract = cacheDir.appendingPathComponent("bz2_out_\(UUID().uuidString)")
                try? fm.createDirectory(at: compExtract, withIntermediateDirectories: true)
                let cLvl = max(1, min(9, lvl.rawValue))

                let t0 = CACurrentMediaTime()
                if pbzip2 != nil {
                    runCLI("/bin/sh", ["-c", "tar -cf - \"\(payload.path)\" | \(bin) -p\(cores) -m2000 -\(cLvl) > \"\(compArc.path)\""])
                } else {
                    runCLI("/bin/sh", ["-c", "tar -cf - \"\(payload.path)\" | \(bin) -\(cLvl) > \"\(compArc.path)\""])
                }
                let t1 = CACurrentMediaTime()

                let t2 = CACurrentMediaTime()
                if pbzip2 != nil {
                    runCLI("/bin/sh", ["-c", "\(bin) -d -p\(cores) -c \"\(compArc.path)\" | tar -xf - -C \"\(compExtract.path)\""])
                } else {
                    runCLI("/bin/sh", ["-c", "\(bin) -d -c \"\(compArc.path)\" | tar -xf - -C \"\(compExtract.path)\""])
                }
                let t3 = CACurrentMediaTime()

                runToolClosure(label, t1 - t0, t3 - t2, compArc.path, compExtract.path)
                try? fm.removeItem(at: compArc)
                try? fm.removeItem(at: compExtract)
            }
        }

        // 8. XZ (pixz / xz / 7zz)
        if (fmt == .xz || fmt == .tarXz), isToolSelected("pixz") || isToolSelected("xz") || isToolSelected("7zz") {
            let pixz = CompetitorDetector.findExecutable(names: ["pixz"])
            let xz = CompetitorDetector.findExecutable(names: ["xz"])
            let cLvl = max(1, min(9, lvl.rawValue))

            if let pixzBin = pixz {
                let compArc = cacheDir.appendingPathComponent("xz_\(UUID().uuidString).tar.xz")
                let compExtract = cacheDir.appendingPathComponent("xz_out_\(UUID().uuidString)")
                try? fm.createDirectory(at: compExtract, withIntermediateDirectories: true)

                let t0 = CACurrentMediaTime()
                runCLI("/bin/sh", ["-c", "tar -cf - \"\(payload.path)\" | \(pixzBin) -p \(cores) -\(cLvl) > \"\(compArc.path)\""])
                let t1 = CACurrentMediaTime()

                let t2 = CACurrentMediaTime()
                runCLI("/bin/sh", ["-c", "\(pixzBin) -d -p \(cores) -i \"\(compArc.path)\" | tar -xf - -C \"\(compExtract.path)\""])
                let t3 = CACurrentMediaTime()

                runToolClosure("pixz (Parallel XZ)", t1 - t0, t3 - t2, compArc.path, compExtract.path)
                try? fm.removeItem(at: compArc)
                try? fm.removeItem(at: compExtract)
            } else if let xzBin = xz {
                let compArc = cacheDir.appendingPathComponent("xz_\(UUID().uuidString).tar.xz")
                let compExtract = cacheDir.appendingPathComponent("xz_out_\(UUID().uuidString)")
                try? fm.createDirectory(at: compExtract, withIntermediateDirectories: true)

                let t0 = CACurrentMediaTime()
                runCLI("/bin/sh", ["-c", "tar -cf - \"\(payload.path)\" | \(xzBin) -T0 -\(cLvl) --memlimit=4096MB > \"\(compArc.path)\""])
                let t1 = CACurrentMediaTime()

                let t2 = CACurrentMediaTime()
                runCLI("/bin/sh", ["-c", "\(xzBin) -d -T0 -c \"\(compArc.path)\" | tar -xf - -C \"\(compExtract.path)\""])
                let t3 = CACurrentMediaTime()

                runToolClosure("xz (Thread=0)", t1 - t0, t3 - t2, compArc.path, compExtract.path)
                try? fm.removeItem(at: compArc)
                try? fm.removeItem(at: compExtract)
            }
        }

        // 9. LZIP (plzip / lzip)
        if fmt == .lzip, isToolSelected("plzip") || isToolSelected("lzip") {
            let plzip = CompetitorDetector.findExecutable(names: ["plzip"])
            let lzip = CompetitorDetector.findExecutable(names: ["lzip"])
            if let bin = plzip ?? lzip {
                let label = plzip != nil ? "plzip (Multi-thread Lzip)" : "lzip (Standard)"
                let compArc = cacheDir.appendingPathComponent("lz_\(UUID().uuidString).tar.lz")
                let compExtract = cacheDir.appendingPathComponent("lz_out_\(UUID().uuidString)")
                try? fm.createDirectory(at: compExtract, withIntermediateDirectories: true)
                let cLvl = max(1, min(9, lvl.rawValue))

                let t0 = CACurrentMediaTime()
                if plzip != nil {
                    runCLI("/bin/sh", ["-c", "tar -cf - \"\(payload.path)\" | \(bin) -n \(cores) -m 256 -\(cLvl) > \"\(compArc.path)\""])
                } else {
                    runCLI("/bin/sh", ["-c", "tar -cf - \"\(payload.path)\" | \(bin) -\(cLvl) > \"\(compArc.path)\""])
                }
                let t1 = CACurrentMediaTime()

                let t2 = CACurrentMediaTime()
                if plzip != nil {
                    runCLI("/bin/sh", ["-c", "\(bin) -d -n \(cores) -c \"\(compArc.path)\" | tar -xf - -C \"\(compExtract.path)\""])
                } else {
                    runCLI("/bin/sh", ["-c", "\(bin) -d -c \"\(compArc.path)\" | tar -xf - -C \"\(compExtract.path)\""])
                }
                let t3 = CACurrentMediaTime()

                runToolClosure(label, t1 - t0, t3 - t2, compArc.path, compExtract.path)
                try? fm.removeItem(at: compArc)
                try? fm.removeItem(at: compExtract)
            }
        }

        // 10. LZ4 (official lz4)
        if fmt == .lz4, isToolSelected("lz4") {
            if let lz4 = CompetitorDetector.findExecutable(names: ["lz4"]) {
                let compArc = cacheDir.appendingPathComponent("lz4_\(UUID().uuidString).tar.lz4")
                let compExtract = cacheDir.appendingPathComponent("lz4_out_\(UUID().uuidString)")
                try? fm.createDirectory(at: compExtract, withIntermediateDirectories: true)
                let cLvl = max(1, min(12, lvl.rawValue))

                let t0 = CACurrentMediaTime()
                runCLI("/bin/sh", ["-c", "tar -cf - \"\(payload.path)\" | \(lz4) -\(cLvl) -B6 -l > \"\(compArc.path)\""])
                let t1 = CACurrentMediaTime()

                let t2 = CACurrentMediaTime()
                runCLI("/bin/sh", ["-c", "\(lz4) -d -c \"\(compArc.path)\" | tar -xf - -C \"\(compExtract.path)\""])
                let t3 = CACurrentMediaTime()

                runToolClosure("official lz4 CLI", t1 - t0, t3 - t2, compArc.path, compExtract.path)
                try? fm.removeItem(at: compArc)
                try? fm.removeItem(at: compExtract)
            }
        }

        // 11. BROTLI (brotli)
        if fmt == .brotli, isToolSelected("brotli") {
            if let brotli = CompetitorDetector.findExecutable(names: ["brotli"]) {
                let compArc = cacheDir.appendingPathComponent("br_\(UUID().uuidString).tar.br")
                let compExtract = cacheDir.appendingPathComponent("br_out_\(UUID().uuidString)")
                try? fm.createDirectory(at: compExtract, withIntermediateDirectories: true)
                let cLvl = max(0, min(11, lvl.rawValue))

                let t0 = CACurrentMediaTime()
                runCLI("/bin/sh", ["-c", "tar -cf - \"\(payload.path)\" | \(brotli) -q \(cLvl) -f -o \"\(compArc.path)\""])
                let t1 = CACurrentMediaTime()

                let t2 = CACurrentMediaTime()
                runCLI("/bin/sh", ["-c", "\(brotli) -d -f -c \"\(compArc.path)\" | tar -xf - -C \"\(compExtract.path)\""])
                let t3 = CACurrentMediaTime()

                runToolClosure("brotli CLI", t1 - t0, t3 - t2, compArc.path, compExtract.path)
                try? fm.removeItem(at: compArc)
                try? fm.removeItem(at: compExtract)
            }
        }

        // 12. LRZIP (lrzip)
        if fmt == .lrzip, isToolSelected("lrzip") {
            if let lrzip = CompetitorDetector.findExecutable(names: ["lrzip"]) {
                let compArc = cacheDir.appendingPathComponent("lrz_\(UUID().uuidString).tar.lrz")
                let compExtract = cacheDir.appendingPathComponent("lrz_out_\(UUID().uuidString)")
                try? fm.createDirectory(at: compExtract, withIntermediateDirectories: true)
                let cLvl = max(1, min(9, lvl.rawValue))

                let t0 = CACurrentMediaTime()
                runCLI("/bin/sh", ["-c", "tar -cf - \"\(payload.path)\" | \(lrzip) -p \(cores) -m 2000 -L \(cLvl) -o \"\(compArc.path)\""])
                let t1 = CACurrentMediaTime()

                let t2 = CACurrentMediaTime()
                runCLI("/bin/sh", ["-c", "\(lrzip) -d -p \(cores) -o - \"\(compArc.path)\" | tar -xf - -C \"\(compExtract.path)\""])
                let t3 = CACurrentMediaTime()

                runToolClosure("lrzip (Multi-core)", t1 - t0, t3 - t2, compArc.path, compExtract.path)
                try? fm.removeItem(at: compArc)
                try? fm.removeItem(at: compExtract)
            }
        }

        // 13. AAR (Apple aa)
        if fmt == .aar, isToolSelected("aa") || isToolSelected("apple") {
            if let aa = CompetitorDetector.findExecutable(names: ["aa"], extraPaths: ["/usr/bin/aa"]) {
                let compArc = cacheDir.appendingPathComponent("aar_\(UUID().uuidString).aar")
                let compExtract = cacheDir.appendingPathComponent("aar_out_\(UUID().uuidString)")
                try? fm.createDirectory(at: compExtract, withIntermediateDirectories: true)

                let t0 = CACurrentMediaTime()
                runCLI(aa, ["archive", "-d", payload.path, "-o", compArc.path, "-a", "lzfse"])
                let t1 = CACurrentMediaTime()

                let t2 = CACurrentMediaTime()
                runCLI(aa, ["extract", "-d", compExtract.path, "-i", compArc.path])
                let t3 = CACurrentMediaTime()

                runToolClosure("Apple aa (AppleArchive LZFSE)", t1 - t0, t3 - t2, compArc.path, compExtract.path)
                try? fm.removeItem(at: compArc)
                try? fm.removeItem(at: compExtract)
            }
        }

        // 14. SNAPPY (snappy)
        if fmt == .snappy, isToolSelected("snappy") {
            if let snappy = CompetitorDetector.findExecutable(names: ["snappy", "szip"]) {
                let compArc = cacheDir.appendingPathComponent("sz_\(UUID().uuidString).sz")
                let compExtract = cacheDir.appendingPathComponent("sz_out_\(UUID().uuidString)")
                try? fm.createDirectory(at: compExtract, withIntermediateDirectories: true)

                let t0 = CACurrentMediaTime()
                runCLI(snappy, ["-c", payload.path, compArc.path])
                let t1 = CACurrentMediaTime()

                let t2 = CACurrentMediaTime()
                runCLI(snappy, ["-d", compArc.path, compExtract.appendingPathComponent("decompressed_out").path])
                let t3 = CACurrentMediaTime()

                runToolClosure("Snappy CLI", t1 - t0, t3 - t2, compArc.path, compExtract.path)
                try? fm.removeItem(at: compArc)
                try? fm.removeItem(at: compExtract)
            }
        }

        // 15. WIM (wimlib-imagex / 7zz)
        if fmt == .wim, isToolSelected("wimlib") || isToolSelected("7zz") || isToolSelected("7z") {
            let wimlib = CompetitorDetector.findExecutable(names: ["wimlib-imagex"])
            let sz = CompetitorDetector.findExecutable(names: ["7zz", "7z"])
            if let wimlibBin = wimlib {
                let compArc = cacheDir.appendingPathComponent("wim_\(UUID().uuidString).wim")
                let compExtract = cacheDir.appendingPathComponent("wim_out_\(UUID().uuidString)")
                try? fm.createDirectory(at: compExtract, withIntermediateDirectories: true)

                let t0 = CACurrentMediaTime()
                runCLI(wimlibBin, ["capture", payload.path, compArc.path, "--compress=LZX"])
                let t1 = CACurrentMediaTime()

                let t2 = CACurrentMediaTime()
                runCLI(wimlibBin, ["apply", compArc.path, "1", compExtract.path])
                let t3 = CACurrentMediaTime()

                runToolClosure("wimlib-imagex", t1 - t0, t3 - t2, compArc.path, compExtract.path)
                try? fm.removeItem(at: compArc)
                try? fm.removeItem(at: compExtract)
            } else if let szBin = sz {
                let compArc = cacheDir.appendingPathComponent("wim_\(UUID().uuidString).wim")
                let compExtract = cacheDir.appendingPathComponent("wim_out_\(UUID().uuidString)")
                try? fm.createDirectory(at: compExtract, withIntermediateDirectories: true)

                let t0 = CACurrentMediaTime()
                runCLI(szBin, ["a", "-twim", compArc.path, payload.path])
                let t1 = CACurrentMediaTime()

                let t2 = CACurrentMediaTime()
                runCLI(szBin, ["x", "-y", "-mmt=on", compArc.path, "-o" + compExtract.path + "/"])
                let t3 = CACurrentMediaTime()

                runToolClosure("7-Zip 7zz (WIM)", t1 - t0, t3 - t2, compArc.path, compExtract.path)
                try? fm.removeItem(at: compArc)
                try? fm.removeItem(at: compExtract)
            }
        }

        // 16. DMG / ISO (hdiutil / 7zz)
        if (fmt == .dmg || fmt == .iso), isToolSelected("hdiutil") || isToolSelected("7zz") {
            if let hdiutil = CompetitorDetector.findExecutable(names: ["hdiutil"], extraPaths: ["/usr/bin/hdiutil"]) {
                let extStr = fmt == .dmg ? "dmg" : "iso"
                let compArc = cacheDir.appendingPathComponent("disc_\(UUID().uuidString).\(extStr)")
                let compExtract = cacheDir.appendingPathComponent("disc_out_\(UUID().uuidString)")
                try? fm.createDirectory(at: compExtract, withIntermediateDirectories: true)
                let sz = CompetitorDetector.findExecutable(names: ["7zz", "7z"])

                let t0 = CACurrentMediaTime()
                if fmt == .dmg {
                    runCLI(hdiutil, ["create", "-srcfolder", payload.path, "-format", "UDZO", "-ov", compArc.path])
                } else {
                    runCLI(hdiutil, ["makehybrid", "-iso", "-joliet", "-o", compArc.path, payload.path])
                }
                let t1 = CACurrentMediaTime()

                let t2 = CACurrentMediaTime()
                if let szBin = sz {
                    runCLI(szBin, ["x", "-y", "-mmt=on", compArc.path, "-o" + compExtract.path + "/"])
                } else {
                    let mountPoint = cacheDir.appendingPathComponent("mnt_\(UUID().uuidString)").path
                    runCLI(hdiutil, ["attach", compArc.path, "-mountpoint", mountPoint])
                    runCLI("/bin/cp", ["-R", mountPoint + "/", compExtract.path + "/"])
                    runCLI(hdiutil, ["detach", mountPoint])
                }
                let t3 = CACurrentMediaTime()

                runToolClosure("macOS hdiutil (\(fmt.rawValue.uppercased()))", t1 - t0, t3 - t2, compArc.path, compExtract.path)
                try? fm.removeItem(at: compArc)
                try? fm.removeItem(at: compExtract)
            }
        }
    }
}
