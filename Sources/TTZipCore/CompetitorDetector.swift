import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// 竞品软件与工具链基本信息
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

/// 真实检测测算数据模型
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

/// 真实已安装压缩软件与工具链感知服务
public enum CompetitorDetector {
    /// 探测当前 macOS 系统中所有真实安装的压缩软件与 CLI 工具链 (全动态环境推断，无硬编码路径依赖)
    public static func detectAllCompetitors() -> [CompetitorTool] {
        var tools: [CompetitorTool] = []
        
        // 1. macOS 系统原生 (ditto)
        let dittoPath = findExecutable(names: ["ditto"], extraPaths: ["/usr/bin/ditto"])
        tools.append(CompetitorTool(
            toolId: "native_ditto",
            name: "macOS 系统原生 (ditto)",
            bundleIdentifier: "com.apple.archiveutility",
            isInstalled: dittoPath != nil,
            appPath: checkAppInstalled(bundleId: "com.apple.archiveutility", defaultPath: "/System/Library/CoreServices/Applications/Archive Utility.app").path,
            cliExecutablePath: dittoPath,
            iconSystemName: "applelogo",
            description: "macOS 默认 Finder 右键压缩引擎"
        ))
        
        // 2. 7-Zip CLI 工具链
        let sevenZipCli = findExecutable(names: ["7zz", "7z"])
        tools.append(CompetitorTool(
            toolId: "7zip_cli",
            name: "7-Zip (7zz CLI)",
            bundleIdentifier: nil,
            isInstalled: sevenZipCli != nil,
            appPath: nil,
            cliExecutablePath: sevenZipCli,
            iconSystemName: "terminal.fill",
            description: "官方 7-Zip ARM64 高性能多线程 CLI 引擎"
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
            description: "macOS 开源知名归档工具 (基于 p7zip 多核内核)"
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
            description: "macOS 经典归档管理软件"
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
            description: "macOS 简洁压缩解压工具"
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
            description: "全核多线程并行 GZIP 引擎"
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
            description: "Meta 多线程 Zstd 高速压缩解压引擎"
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
            description: "极致吞吐率 Deflate / Gzip 编解码引擎"
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
            description: "极限上下文预测 (Context Mixing) 极致备份归档引擎"
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
            description: "Apple 底层 LZFSE 硬件优化编解码引擎"
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
            description: "macOS 知名全格式解压引擎"
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
            description: "超大文件极长距离匹配归档引擎"
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
            description: "工业级纯内存多算法极限基准测试引擎"
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
            description: "开源实时数据压缩纯内存基准测试工具"
        ))
        
        return tools
    }
    
    /// 过滤出已被真实安装的第三方与系统工具
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
