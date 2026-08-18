// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// Value type representing detected third-party archive applications and CLI tools.
public struct CompetitorTool: Identifiable, Sendable {
    public var id: String { toolId }
    public let toolId: String
    public let name: String
    public let bundleIdentifier: String?
    public let isInstalled: Bool
    public let appPath: String?
    public let cliExecutablePath: String?
    public let iconSystemName: String
    public let description: String
    
    public init(
        toolId: String,
        name: String,
        bundleIdentifier: String? = nil,
        isInstalled: Bool,
        appPath: String? = nil,
        cliExecutablePath: String? = nil,
        iconSystemName: String = "shippingbox.fill",
        description: String = ""
    ) {
        self.toolId = toolId
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.isInstalled = isInstalled
        self.appPath = appPath
        self.cliExecutablePath = cliExecutablePath
        self.iconSystemName = iconSystemName
        self.description = description
    }
}

/// Measured performance score against detected toolchains.
public struct CompetitorRealScore: Identifiable, Sendable {
    public var id: String { tool.id }
    public let tool: CompetitorTool
    public let measuredElapsedSeconds: Double
    public let measuredThroughputMBs: Double
    public let relativeSpeedupVsNative: Double
    
    public init(
        tool: CompetitorTool,
        measuredElapsedSeconds: Double,
        measuredThroughputMBs: Double,
        relativeSpeedupVsNative: Double
    ) {
        self.tool = tool
        self.measuredElapsedSeconds = measuredElapsedSeconds
        self.measuredThroughputMBs = measuredThroughputMBs
        self.relativeSpeedupVsNative = relativeSpeedupVsNative
    }
}

/// Detection service identifying installed archiving applications and CLI binaries across macOS.
public enum CompetitorDetector {
    /// Detects all supported third-party archiving tools and CLI engines installed on host system.
    public static func detectAllCompetitors() -> [CompetitorTool] {
        var tools: [CompetitorTool] = []
        
        // 1. macOS System Native (ditto)
        let dittoPath = findExecutable(names: ["ditto"], extraPaths: ["/usr/bin/ditto"])
        tools.append(CompetitorTool(
            toolId: "native_ditto",
            name: "macOS Native (ditto)",
            bundleIdentifier: "com.apple.archiveutility",
            isInstalled: dittoPath != nil,
            appPath: checkAppInstalled(bundleId: "com.apple.archiveutility", defaultPath: "/System/Library/CoreServices/Applications/Archive Utility.app").path,
            cliExecutablePath: dittoPath,
            iconSystemName: "applelogo",
            description: "macOS default Archive Utility and ditto compression tool"
        ))
        
        // 2. 7-Zip CLI toolchain
        let sevenZipCli = findExecutable(names: ["7zz", "7z"])
        tools.append(CompetitorTool(
            toolId: "7zip_cli",
            name: "7-Zip (7zz CLI)",
            bundleIdentifier: nil,
            isInstalled: sevenZipCli != nil,
            appPath: nil,
            cliExecutablePath: sevenZipCli,
            iconSystemName: "terminal.fill",
            description: "Official 7-Zip ARM64 multi-threaded CLI engine"
        ))

        // 3. Keka
        let kekaInstalled = checkAppInstalled(bundleId: "com.aone.keka", defaultPath: "/Applications/Keka.app")
        let kekaCli = findExecutable(
            names: ["keka7zz", "keka7z", "kekaexec"],
            extraPaths: [
                (kekaInstalled.path ?? "/Applications/Keka.app") + "/Contents/MacOS/keka7zz",
                (kekaInstalled.path ?? "/Applications/Keka.app") + "/Contents/MacOS/keka7z",
                (kekaInstalled.path ?? "/Applications/Keka.app") + "/Contents/Resources/kekaexec"
            ]
        ) ?? sevenZipCli
        tools.append(CompetitorTool(
            toolId: "keka",
            name: "Keka",
            bundleIdentifier: "com.aone.keka",
            isInstalled: kekaInstalled.installed || kekaCli != nil,
            appPath: kekaInstalled.path,
            cliExecutablePath: kekaCli,
            iconSystemName: "archivebox.circle.fill",
            description: "macOS open-source archiver powered by p7zip"
        ))

        // 4. BetterZip
        let bzInstalled = checkAppInstalled(bundleId: "com.macitbetter.betterzip", defaultPath: "/Applications/BetterZip.app")
        let bzCli = findExecutable(
            names: ["betterzip", "7za"],
            extraPaths: [
                (bzInstalled.path ?? "/Applications/BetterZip.app") + "/Contents/Helpers/7za",
                (bzInstalled.path ?? "/Applications/BetterZip.app") + "/Contents/Resources/betterzip"
            ]
        )
        tools.append(CompetitorTool(
            toolId: "betterzip",
            name: "BetterZip",
            bundleIdentifier: "com.macitbetter.betterzip",
            isInstalled: bzInstalled.installed || bzCli != nil,
            appPath: bzInstalled.path,
            cliExecutablePath: bzCli ?? sevenZipCli,
            iconSystemName: "slider.horizontal.3",
            description: "macOS archive manager"
        ))

        // 5. MacZip (eZip)
        let mzInstalled = checkAppInstalled(bundleId: "com.awehunt.maczip", defaultPath: "/Applications/MacZip.app")
        tools.append(CompetitorTool(
            toolId: "maczip",
            name: "MacZip (eZip)",
            bundleIdentifier: "com.awehunt.maczip",
            isInstalled: mzInstalled.installed,
            appPath: mzInstalled.path,
            cliExecutablePath: findExecutable(names: ["MacZip"], extraPaths: [(mzInstalled.path ?? "/Applications/MacZip.app") + "/Contents/MacOS/MacZip"]),
            iconSystemName: "folder.badge.gearshape",
            description: "macOS archiver utility"
        ))

        // 6. Parallel pigz
        let pigzCli = findExecutable(names: ["pigz"])
        tools.append(CompetitorTool(
            toolId: "pigz_cli",
            name: "Parallel pigz",
            bundleIdentifier: nil,
            isInstalled: pigzCli != nil,
            appPath: nil,
            cliExecutablePath: pigzCli,
            iconSystemName: "cpu.fill",
            description: "Parallel multi-threaded GZIP implementation"
        ))

        // 7. Zstandard zstd
        let zstdCli = findExecutable(names: ["zstd"])
        tools.append(CompetitorTool(
            toolId: "zstd_cli",
            name: "Zstandard zstd",
            bundleIdentifier: nil,
            isInstalled: zstdCli != nil,
            appPath: nil,
            cliExecutablePath: zstdCli,
            iconSystemName: "bolt.fill",
            description: "Meta Zstandard real-time compression algorithm CLI"
        ))
        
        // 8. libdeflate-gzip
        let libdeflateCli = findExecutable(names: ["libdeflate-gzip"])
        tools.append(CompetitorTool(
            toolId: "libdeflate_gzip",
            name: "libdeflate-gzip",
            bundleIdentifier: nil,
            isInstalled: libdeflateCli != nil,
            appPath: nil,
            cliExecutablePath: libdeflateCli,
            iconSystemName: "flame.fill",
            description: "High-throughput libdeflate GZIP implementation"
        ))

        // 9. ZPAQ Franz
        let zpaqfranzCli = findExecutable(names: ["zpaqfranz", "zpaq"])
        tools.append(CompetitorTool(
            toolId: "zpaq_franz",
            name: "ZPAQ Franz",
            bundleIdentifier: nil,
            isInstalled: zpaqfranzCli != nil,
            appPath: nil,
            cliExecutablePath: zpaqfranzCli,
            iconSystemName: "diamond.fill",
            description: "Context-mixing archiving and backup engine"
        ))

        // 10. Apple LZFSE CLI
        let lzfseCli = findExecutable(names: ["lzfse"])
        tools.append(CompetitorTool(
            toolId: "lzfse_cli",
            name: "Apple LZFSE CLI",
            bundleIdentifier: nil,
            isInstalled: lzfseCli != nil,
            appPath: nil,
            cliExecutablePath: lzfseCli,
            iconSystemName: "applelogo",
            description: "Apple LZFSE compression reference CLI"
        ))

        // 11. The Unarchiver CLI (unar)
        let unarCli = findExecutable(names: ["unar"])
        tools.append(CompetitorTool(
            toolId: "unar_cli",
            name: "The Unarchiver (unar)",
            bundleIdentifier: "com.macpaw.site.theunarchiver",
            isInstalled: unarCli != nil,
            appPath: checkAppInstalled(bundleId: "com.macpaw.site.theunarchiver", defaultPath: "/Applications/The Unarchiver.app").path,
            cliExecutablePath: unarCli,
            iconSystemName: "doc.zipper",
            description: "Universal archive extraction CLI"
        ))

        // 12. Long Range ZIP (lrzip)
        let lrzipCli = findExecutable(names: ["lrzip"])
        tools.append(CompetitorTool(
            toolId: "lrzip_cli",
            name: "Long Range ZIP (lrzip)",
            bundleIdentifier: nil,
            isInstalled: lrzipCli != nil,
            appPath: nil,
            cliExecutablePath: lrzipCli,
            iconSystemName: "square.stack.3d.down.right.fill",
            description: "Extended long-distance matching compression tool"
        ))

        // 13. powturbo TurboBench
        let turboBenchCli = findExecutable(names: ["turbobench", "TurboBench"])
        tools.append(CompetitorTool(
            toolId: "turbobench_cli",
            name: "TurboBench (powturbo)",
            bundleIdentifier: nil,
            isInstalled: turboBenchCli != nil,
            appPath: nil,
            cliExecutablePath: turboBenchCli,
            iconSystemName: "gauge.with.needle.fill",
            description: "In-memory compression benchmark suite"
        ))

        // 14. inikep lzbench
        let lzbenchCli = findExecutable(names: ["lzbench"])
        tools.append(CompetitorTool(
            toolId: "lzbench_cli",
            name: "lzbench (inikep)",
            bundleIdentifier: nil,
            isInstalled: lzbenchCli != nil,
            appPath: nil,
            cliExecutablePath: lzbenchCli,
            iconSystemName: "speedometer",
            description: "In-memory real-time data compression benchmark tool"
        ))
        
        return tools
    }
    
    /// Filters detected tools returning only those present on host system.
    public static func detectOnlyInstalledCompetitors() -> [CompetitorTool] {
        return detectAllCompetitors().filter { $0.isInstalled }
    }
    
    // MARK: - Private Dynamic Probing Helpers
    
    public static func checkAppInstalled(bundleId: String, defaultPath: String) -> (installed: Bool, path: String?) {
        let fm = FileManager.default
        if fm.fileExists(atPath: defaultPath) {
            return (true, defaultPath)
        }
        
        #if canImport(AppKit)
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return (true, url.path)
        }
        #endif
        
        return (false, nil)
    }
    
    public static func findExecutable(names: [String], extraPaths: [String] = []) -> String? {
        let fm = FileManager.default

        for p in extraPaths {
            if fm.isExecutableFile(atPath: p) { return p }
        }

        #if MAS_BUILD
        let searchDirs = ["/usr/bin", "/bin"]
        #else
        let pathEnv = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin"
        var searchDirs: [String] = []
        for dir in pathEnv.split(separator: ":").map({ String($0) }) + ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"] {
            if !searchDirs.contains(dir) {
                searchDirs.append(dir)
            }
        }
        #endif

        for name in names {
            for dir in searchDirs {
                let fullPath = (dir as NSString).appendingPathComponent(name)
                if fm.isExecutableFile(atPath: fullPath) {
                    return fullPath
                }
            }
        }

        return nil
    }
}
