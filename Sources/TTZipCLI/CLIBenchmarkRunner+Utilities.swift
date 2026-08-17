// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Weitao Kung (Witt Kung) <kevintungs@163.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import TTZipCore

extension CLIBenchmarkRunner {
    public static func parseSizeBytes(_ raw: String?) -> Int64 {
        guard let r = raw?.lowercased().trimmingCharacters(in: .whitespaces), !r.isEmpty else {
            return 500 * 1024 * 1024
        }
        if r.hasSuffix("g") || r.hasSuffix("gb") {
            let numStr = r.replacingOccurrences(of: "gb", with: "").replacingOccurrences(of: "g", with: "")
            let val = Double(numStr) ?? 1.0
            return Int64(val * 1024 * 1024 * 1024)
        } else if r.hasSuffix("m") || r.hasSuffix("mb") {
            let numStr = r.replacingOccurrences(of: "mb", with: "").replacingOccurrences(of: "m", with: "")
            let val = Double(numStr) ?? 500.0
            return Int64(val * 1024 * 1024)
        } else if let bytes = Int64(r) {
            return bytes
        }
        return 500 * 1024 * 1024
    }

    /// Purge all benchmark datasets, test residues, and temporary caches to reclaim disk space
    public static func cleanBenchmarkCache() {
        ArchiveBenchmarkFacade.shared.cleanCache()
        let fm = FileManager.default
        let docsUrl = fm.urls(for: .documentDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let docsCacheDir = docsUrl.appendingPathComponent("TTZipExhaustiveDatasetCache")
        let tmpCacheDir = fm.temporaryDirectory.appendingPathComponent("TTZipExhaustiveDatasetCache")

        var freedBytes: Int64 = 0

        func calculateAndRemove(dir: URL) {
            guard fm.fileExists(atPath: dir.path) else { return }
            if let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey]) {
                while let fURL = enumerator.nextObject() as? URL {
                    if let r = try? fURL.resourceValues(forKeys: [.fileSizeKey]) {
                        freedBytes += Int64(r.fileSize ?? 0)
                    }
                }
            }
            try? fm.removeItem(at: dir)
        }

        calculateAndRemove(dir: docsCacheDir)
        calculateAndRemove(dir: tmpCacheDir)

        let homeUrl = fm.homeDirectoryForCurrentUser
        let dotCacheDir = homeUrl.appendingPathComponent(".cache/ttzip_benchmark")
        calculateAndRemove(dir: dotCacheDir)

        let tmpUrl = fm.temporaryDirectory
        if let tmpItems = try? fm.contentsOfDirectory(at: tmpUrl, includingPropertiesForKeys: [.fileSizeKey]) {
            for item in tmpItems {
                let name = item.lastPathComponent
                if name.hasPrefix("tt_") || name.hasPrefix("lz_") || name.hasPrefix("lrz_") || name.hasPrefix("CustomBench_") || name.hasPrefix("TTZipExhaustive") {
                    calculateAndRemove(dir: item)
                }
            }
        }

        let freedMB = Double(freedBytes) / (1024.0 * 1024.0)
        print("🧹 [Benchmark Cache Purged] Successfully cleared test datasets and caches (Reclaimed ~\(String(format: "%.1f", freedMB)) MB / \(String(format: "%.2f", freedMB / 1024.0)) GB disk space).")
        fflush(stdout)
    }

    internal static func runPurgeCache() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/purge")
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        try? p.run()
        p.waitUntilExit()
    }
}
