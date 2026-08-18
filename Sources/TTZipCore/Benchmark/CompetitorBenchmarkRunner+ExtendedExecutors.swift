// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

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
            let sz = CompetitorDetector.findExecutable(names: ["7zz", "7z"])
            if let bin = pixz ?? xz ?? sz {
                let label = pixz != nil ? "pixz (All Cores)" : (xz != nil ? "xz (System)" : "7-Zip 7zz CLI (ARM64)")
                let compArc = cacheDir.appendingPathComponent("xz_\(UUID().uuidString).tar.xz")
                let compExtract = cacheDir.appendingPathComponent("xz_out_\(UUID().uuidString)")
                try? fm.createDirectory(at: compExtract, withIntermediateDirectories: true)
                let cLvl = max(1, min(9, lvl.rawValue))

                let t0 = CACurrentMediaTime()
                if pixz != nil {
                    runCLI("/bin/sh", ["-c", "tar -cf - \"\(payload.path)\" | \(bin) -p \(cores) -\(cLvl) > \"\(compArc.path)\""])
                } else if xz != nil {
                    runCLI("/bin/sh", ["-c", "tar -cf - \"\(payload.path)\" | \(bin) -T\(cores) -\(cLvl) > \"\(compArc.path)\""])
                } else {
                    runCLI(bin, ["a", "-txz", "-mmt=on", "-mx=\(cLvl)", compArc.path, payload.path])
                }
                let t1 = CACurrentMediaTime()

                let t2 = CACurrentMediaTime()
                if pixz != nil {
                    runCLI("/bin/sh", ["-c", "\(bin) -d -p \(cores) -i \"\(compArc.path)\" | tar -xf - -C \"\(compExtract.path)\""])
                } else if xz != nil {
                    runCLI("/bin/sh", ["-c", "\(bin) -d -T\(cores) -c \"\(compArc.path)\" | tar -xf - -C \"\(compExtract.path)\""])
                } else {
                    runCLI(bin, ["x", compArc.path, "-o\(compExtract.path)", "-y"])
                }
                let t3 = CACurrentMediaTime()

                runToolClosure(label, t1 - t0, t3 - t2, compArc.path, compExtract.path)
                try? fm.removeItem(at: compArc)
                try? fm.removeItem(at: compExtract)
            }
        }

        // 9. LZIP (plzip / lzip)
        if fmt == .lzip, isToolSelected("plzip") || isToolSelected("lzip") {
            let plzip = CompetitorDetector.findExecutable(names: ["plzip"])
            let lzip = CompetitorDetector.findExecutable(names: ["lzip"])
            if let bin = plzip ?? lzip {
                let label = plzip != nil ? "plzip (Parallel Lzip)" : "lzip (Official)"
                let compArc = cacheDir.appendingPathComponent("lz_\(UUID().uuidString).tar.lz")
                let compExtract = cacheDir.appendingPathComponent("lz_out_\(UUID().uuidString)")
                try? fm.createDirectory(at: compExtract, withIntermediateDirectories: true)
                let cLvl = max(1, min(9, lvl.rawValue))

                let t0 = CACurrentMediaTime()
                if plzip != nil {
                    runCLI("/bin/sh", ["-c", "tar -cf - \"\(payload.path)\" | \(bin) -n \(cores) -\(cLvl) > \"\(compArc.path)\""])
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

        // 10. LZ4 (lz4)
        if fmt == .lz4, isToolSelected("lz4") {
            if let bin = CompetitorDetector.findExecutable(names: ["lz4"]) {
                let compArc = cacheDir.appendingPathComponent("lz4_\(UUID().uuidString).tar.lz4")
                let compExtract = cacheDir.appendingPathComponent("lz4_out_\(UUID().uuidString)")
                try? fm.createDirectory(at: compExtract, withIntermediateDirectories: true)
                let cLvl = max(1, min(9, lvl.rawValue))

                let t0 = CACurrentMediaTime()
                runCLI("/bin/sh", ["-c", "tar -cf - \"\(payload.path)\" | \(bin) -\(cLvl) -B7 > \"\(compArc.path)\""])
                let t1 = CACurrentMediaTime()

                let t2 = CACurrentMediaTime()
                runCLI("/bin/sh", ["-c", "\(bin) -d -c \"\(compArc.path)\" | tar -xf - -C \"\(compExtract.path)\""])
                let t3 = CACurrentMediaTime()

                runToolClosure("lz4 CLI (C11 Native)", t1 - t0, t3 - t2, compArc.path, compExtract.path)
                try? fm.removeItem(at: compArc)
                try? fm.removeItem(at: compExtract)
            }
        }

        // 11. Brotli (brotli)
        if fmt == .brotli, isToolSelected("brotli") {
            if let bin = CompetitorDetector.findExecutable(names: ["brotli"]) {
                let compArc = cacheDir.appendingPathComponent("br_\(UUID().uuidString).tar.br")
                let compExtract = cacheDir.appendingPathComponent("br_out_\(UUID().uuidString)")
                try? fm.createDirectory(at: compExtract, withIntermediateDirectories: true)
                let cLvl = max(1, min(9, lvl.rawValue))

                let t0 = CACurrentMediaTime()
                runCLI("/bin/sh", ["-c", "tar -cf - \"\(payload.path)\" | \(bin) -q \(cLvl) -c > \"\(compArc.path)\""])
                let t1 = CACurrentMediaTime()

                let t2 = CACurrentMediaTime()
                runCLI("/bin/sh", ["-c", "\(bin) -d -c \"\(compArc.path)\" | tar -xf - -C \"\(compExtract.path)\""])
                let t3 = CACurrentMediaTime()

                runToolClosure("Google Brotli CLI", t1 - t0, t3 - t2, compArc.path, compExtract.path)
                try? fm.removeItem(at: compArc)
                try? fm.removeItem(at: compExtract)
            }
        }

        // 12. LRZIP (lrzip)
        if fmt == .lrzip, isToolSelected("lrzip") {
            if let bin = CompetitorDetector.findExecutable(names: ["lrzip"]) {
                let compArc = cacheDir.appendingPathComponent("lrz_\(UUID().uuidString).tar.lrz")
                let compExtract = cacheDir.appendingPathComponent("lrz_out_\(UUID().uuidString)")
                try? fm.createDirectory(at: compExtract, withIntermediateDirectories: true)
                let cLvl = max(1, min(9, lvl.rawValue))

                let t0 = CACurrentMediaTime()
                runCLI("/bin/sh", ["-c", "tar -cf - \"\(payload.path)\" | \(bin) -l -L \(cLvl) -p \(cores) -o \"\(compArc.path)\""])
                let t1 = CACurrentMediaTime()

                let t2 = CACurrentMediaTime()
                runCLI("/bin/sh", ["-c", "\(bin) -d -p \(cores) -o - \"\(compArc.path)\" | tar -xf - -C \"\(compExtract.path)\""])
                let t3 = CACurrentMediaTime()

                runToolClosure("lrzip (Long Range ZIP)", t1 - t0, t3 - t2, compArc.path, compExtract.path)
                try? fm.removeItem(at: compArc)
                try? fm.removeItem(at: compExtract)
            }
        }

        // 13. Apple Archive (aa)
        if fmt == .aar, isToolSelected("aa") || isToolSelected("applearchive") {
            if let bin = CompetitorDetector.findExecutable(names: ["aa"]) {
                let compArc = cacheDir.appendingPathComponent("aa_\(UUID().uuidString).aar")
                let compExtract = cacheDir.appendingPathComponent("aa_out_\(UUID().uuidString)")
                try? fm.createDirectory(at: compExtract, withIntermediateDirectories: true)

                let t0 = CACurrentMediaTime()
                runCLI(bin, ["archive", "-d", payload.path, "-o", compArc.path, "-t", "\(cores)"])
                let t1 = CACurrentMediaTime()

                let t2 = CACurrentMediaTime()
                runCLI(bin, ["extract", "-i", compArc.path, "-d", compExtract.path, "-t", "\(cores)"])
                let t3 = CACurrentMediaTime()

                runToolClosure("Apple aa (Apple Archive CLI)", t1 - t0, t3 - t2, compArc.path, compExtract.path)
                try? fm.removeItem(at: compArc)
                try? fm.removeItem(at: compExtract)
            }
        }

        // 14. Snappy (snzip)
        if fmt == .snappy, isToolSelected("snappy") || isToolSelected("snzip") {
            if let bin = CompetitorDetector.findExecutable(names: ["snzip"]) {
                let compArc = cacheDir.appendingPathComponent("snappy_\(UUID().uuidString).tar.sz")
                let compExtract = cacheDir.appendingPathComponent("snappy_out_\(UUID().uuidString)")
                try? fm.createDirectory(at: compExtract, withIntermediateDirectories: true)

                let t0 = CACurrentMediaTime()
                runCLI("/bin/sh", ["-c", "tar -cf - \"\(payload.path)\" | \(bin) -c > \"\(compArc.path)\""])
                let t1 = CACurrentMediaTime()

                let t2 = CACurrentMediaTime()
                runCLI("/bin/sh", ["-c", "\(bin) -d -c \"\(compArc.path)\" | tar -xf - -C \"\(compExtract.path)\""])
                let t3 = CACurrentMediaTime()

                runToolClosure("Google Snappy (snzip CLI)", t1 - t0, t3 - t2, compArc.path, compExtract.path)
                try? fm.removeItem(at: compArc)
                try? fm.removeItem(at: compExtract)
            }
        }

        // 15. WIM (wimlib-imagex)
        if fmt == .wim, isToolSelected("wimlib") || isToolSelected("wimlib-imagex") {
            if let bin = CompetitorDetector.findExecutable(names: ["wimlib-imagex"]) {
                let compArc = cacheDir.appendingPathComponent("wim_\(UUID().uuidString).wim")
                let compExtract = cacheDir.appendingPathComponent("wim_out_\(UUID().uuidString)")
                try? fm.createDirectory(at: compExtract, withIntermediateDirectories: true)

                let t0 = CACurrentMediaTime()
                runCLI(bin, ["capture", payload.path, compArc.path, "--threads=\(cores)"])
                let t1 = CACurrentMediaTime()

                let t2 = CACurrentMediaTime()
                runCLI(bin, ["apply", compArc.path, "1", compExtract.path, "--threads=\(cores)"])
                let t3 = CACurrentMediaTime()

                runToolClosure("wimlib-imagex CLI", t1 - t0, t3 - t2, compArc.path, compExtract.path)
                try? fm.removeItem(at: compArc)
                try? fm.removeItem(at: compExtract)
            }
        }

        // 16. DMG (hdiutil)
        if fmt == .dmg, isToolSelected("hdiutil") || isToolSelected("dmg") {
            let compArc = cacheDir.appendingPathComponent("dmg_\(UUID().uuidString).dmg")
            let compMount = cacheDir.appendingPathComponent("dmg_mount_\(UUID().uuidString)")
            try? fm.createDirectory(at: compMount, withIntermediateDirectories: true)

            let t0 = CACurrentMediaTime()
            runCLI("/usr/bin/hdiutil", ["create", "-srcfolder", payload.path, "-format", "UDZO", compArc.path, "-quiet"])
            let t1 = CACurrentMediaTime()

            let t2 = CACurrentMediaTime()
            runCLI("/usr/bin/hdiutil", ["attach", compArc.path, "-mountpoint", compMount.path, "-nobrowse", "-quiet"])
            runCLI("/usr/bin/hdiutil", ["detach", compMount.path, "-quiet"])
            let t3 = CACurrentMediaTime()

            runToolClosure("Apple hdiutil (macOS Native)", t1 - t0, t3 - t2, compArc.path, compMount.path)
            try? fm.removeItem(at: compArc)
            try? fm.removeItem(at: compMount)
        }
    }
}
