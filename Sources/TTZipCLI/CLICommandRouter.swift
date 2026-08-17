import Foundation
import TTZipCore

/// 命令行控制台观察者
public final class CLIEventAndProgressConsoleObserver: ArchiveProgressObserverProtocol, ArchiveEventObserverProtocol, @unchecked Sendable {
    public static let shared = CLIEventAndProgressConsoleObserver()
    private init() {}
    
    public func onProgressUpdated(_ progress: ArchiveProgressInfo) {
        let pct = Int(progress.fractionCompleted * 100)
        let rate = String(format: "%.1f MB/s", progress.throughputMBs)
        print(" [CLI-Progress] \(progress.operationType.rawValue): \(pct)% | \(rate) | \((progress.currentFileName as NSString).lastPathComponent)")
    }
    
    public func onArchiveEvent(_ event: ArchiveEvent) {
        switch event {
        case .archiveCompleted(let path, let op, let duration, _):
            print(String(format: " [CLI-Event] ✅ %@完成: %@ (耗时 %.2fs)", op.rawValue, (path as NSString).lastPathComponent, duration))
        case .extractionFailed(let path, let err):
            print(" [CLI-Event] ❌ 解压失败: \((path as NSString).lastPathComponent) (\(err))")
        case .securityThreatIntercepted(let path, let threat):
            print(" [CLI-Event] ⚠️ 安全拦截: \((path as NSString).lastPathComponent) (\(threat))")
        case .passwordVaultUnlocked(let path, _, _):
            print(" [CLI-Event] ⚡️ 口令解锁: \((path as NSString).lastPathComponent)")
        case .presetChanged(_, let newName):
            print(" [CLI-Event] ⚙️ 预设变更: \(newName)")
        case .taskStateChanged(let taskId, let oldState, let newState):
            print(" [CLI-Event] 🔄 任务状态变更 [\(taskId.uuidString.prefix(8))]: \(oldState) ➔ \(newState)")
        }
    }
}

/// 模块化的 CLI 命令分发路由器
@MainActor
public enum CLICommandRouter {
    // MARK: - 【4.5 依赖注入模式 (Dependency Injection Pattern)】@Injected 核心服务注入
    @Injected static var facade: TTZipEngineFacading
    @Injected static var securityProxy: SecurityProtectionProxy
    @Injected static var taskDispatcher: ArchiveTaskDispatcher
    
    /// 执行解析好的 CLI 命令
    public static func route(command: CLICommand, options: CLIOptions) async {
        ArchiveProgressBroadcaster.shared.addObserver(CLIEventAndProgressConsoleObserver.shared)
        ArchiveEventCenter.shared.addObserver(CLIEventAndProgressConsoleObserver.shared)
        
        switch command {
        case .inspect:
            if let path = options.positionals.first {
                await inspectArchive(path: path, password: options.password)
            } else {
                print("错误: 请提供归档文件路径。例: ttzip-cli inspect demo.zip [-p password]")
            }
            
        case .extract:
            if options.positionals.count >= 2 {
                let archive = options.positionals[0]
                let dest = options.positionals[1]
                await extractArchive(archivePath: archive, destDir: dest, password: options.password)
            } else {
                print("错误: 请提供归档文件与解压目标路径。例: ttzip-cli extract demo.zip /path/to/out [-p password]")
            }
            
        case .create:
            if options.positionals.count >= 2 {
                let outputPath = options.positionals[0]
                let inputPaths = Array(options.positionals.dropFirst())
                await createArchive(
                    outputPath: outputPath,
                    inputPaths: inputPaths,
                    options: options
                )
            } else {
                print("错误: 参数不足。例: ttzip-cli create archive.zip file1.txt file2.pdf [-f 7z] [-s 100m] [-l store] [-p pwd]")
            }
            
        case .recover:
            if options.positionals.count >= 2 {
                let archive = options.positionals[0]
                let dictFile = options.positionals[1]
                await recoverPassword(archivePath: archive, dictFilePath: dictFile)
            } else {
                print("错误: 请提供归档路径与字典文件路径。例: ttzip-cli recover protected.7z dict.txt")
            }
            
        case .bench:
            await handleBench(options: options)
            
        case .benchPk, .competitorBench:
            await handleBenchPk(options: options)
            
        case .clean, .cleanCache, .purge:
            CLIBenchmarkRunner.cleanBenchmarkCache()
            
        case .customBench:
            await CLIBenchmarkRunner.runCustomBench()
            
        case .test:
            await TestCommand.run(options: options)

            
        case .repair:
            if options.positionals.count >= 2 {
                await repairArchive(damaged: options.positionals[0], output: options.positionals[1])
            } else {
                print("错误: 请提供损坏归档与目标路径。例: ttzip-cli repair damaged.zip fixed.zip")
            }
            
        case .batch:
            await handleBatchMacro(options: options)
            
        case .uninstall:
            await handleUninstall(options: options)
            
        case .preset:
            printPresets()
            
        case .version, .shortVersion:
            print("TTZip Enterprise Commercial CLI v1.5.0 (Apple Silicon Native)")
            
        case .help, .shortHelp, .unknown:
            printUsage()
        }
    }
    
    // MARK: - 子命令分发处理逻辑
    
    private static func handleBench(options: CLIOptions) async {
        let fm = FileManager.default
        
        if options.inMemory || options.turboBenchCompat {
            await CLIBenchmarkRunner.runInMemoryBenchmark(options: options)
            return
        }
        
        if options.silesia {
            let silesiaPath: String
            if let envPath = ProcessInfo.processInfo.environment["TTZIP_SILESIA_PATH"], !envPath.isEmpty, fm.fileExists(atPath: envPath) {
                silesiaPath = envPath
            } else if fm.fileExists(atPath: "Tests/TTZipTests/Fixtures/Silesia") {
                silesiaPath = "Tests/TTZipTests/Fixtures/Silesia"
            } else {
                silesiaPath = NSString(string: "~/Documents/dev/TTZip/Tests/TTZipTests/Fixtures/Silesia").expandingTildeInPath
            }
            await CLIBenchmarkRunner.runRealFileBenchmark(
                inputPath: silesiaPath,
                formatFilter: options.format,
                levelFilter: options.level,
                toolFilter: options.competitorTools,
                password: options.password,
                enableZeroCopy: options.enableZeroCopy
            )
            return
        }
        
        let realPathCandidate = options.inputPath ?? options.positionals.first(where: { fm.fileExists(atPath: NSString(string: $0).expandingTildeInPath) })
        let isCompetitor = options.positionals.contains { $0.lowercased() == "--competitor" || $0.lowercased() == "-c" || $0.lowercased() == "competitor" || $0.lowercased() == "--pk" || $0.lowercased() == "-pk" || $0.lowercased() == "pk" } || options.competitorTools != nil
        
        if isCompetitor {
            await handleBenchPk(options: options)
        } else if let realPath = realPathCandidate {
            await CLIBenchmarkRunner.runRealFileBenchmark(
                inputPath: realPath,
                formatFilter: options.format,
                levelFilter: options.level,
                toolFilter: options.competitorTools,
                password: options.password,
                enableZeroCopy: options.enableZeroCopy
            )
        } else {
            let sizeRaw = options.positionals.first ?? "100MB"
            let isExhaustive = options.positionals.contains { $0.lowercased() == "--exhaustive" || $0.lowercased() == "-e" || $0.lowercased() == "exhaustive" } || options.format != nil
            if isExhaustive {
                await CLIBenchmarkRunner.runExhaustiveBenchmark(formatFilter: options.format, levelFilter: options.level)
            } else {
                await CLIBenchmarkRunner.runBenchmark(sizeRaw: sizeRaw)
            }
        }
    }
    
    private static func handleBenchPk(options: CLIOptions) async {
        let fm = FileManager.default
        let customPaths = options.positionals.filter { fm.fileExists(atPath: NSString(string: $0).expandingTildeInPath) }
        
        let config = BenchmarkRunConfig(
            selectedFormats: CLIArgumentParser.parseFormats(options.format != nil ? options.format : (options.allFormats ? "ALL" : nil)),
            selectedLevels: CLIArgumentParser.parseLevels(options.level),
            selectedTools: options.competitorTools?.split(separator: ",").map { String($0) },
            hugeSizeFilter: options.hugeSize,
            customFilePaths: customPaths.isEmpty ? nil : customPaths,
            stopOnLagOrError: options.stopOnLag,
            autoBestCompetitor: options.autoBestCompetitor || (options.competitorTools == nil),
            verifyAllDominance: options.verifyAllDominance,
            filterConfigPath: options.filterConfigPath,
            hugeOnly: options.hugeOnly
        )
        
        await CLIBenchmarkRunner.runCompetitorBenchmark(config: config)
    }
    
    private static func handleUninstall(options: CLIOptions) async {
        let toolsToUninstall: [String]
        if let toolsStr = options.competitorTools {
            toolsToUninstall = toolsStr.split(separator: ",").map { String($0) }
        } else if !options.positionals.isEmpty {
            toolsToUninstall = options.positionals
        } else {
            toolsToUninstall = ["all"]
        }
        print("🗑️ 启动竞品软件选择性/一键卸载助手...")
        let results = await ToolchainInstaller.shared.uninstallCompetitorToolchains(tools: toolsToUninstall) { status in
            print("   [Uninstall] \(status)")
        }
        print("\n卸载处理结果汇总:")
        for (tool, ok) in results {
            print(" - \(tool): \(ok ? "✅ 卸载成功/已清理" : "⚠️ 保持未动/未安装")")
        }
    }
    
    private static func handleBatchMacro(options: CLIOptions) async {
        print("🔗 启动基于命令模式 (Command Pattern) 事务型宏命令 (Macro Command)...")
        guard options.positionals.count >= 2 else {
            print("错误: 批量任务需指定输出目录与至少一个输入源。例: ttzip-cli batch /path/to/out file1.txt file2.txt")
            return
        }
        
        let outDir = options.positionals[0]
        let inputs = Array(options.positionals.dropFirst())
        
        let tasks = inputs.enumerated().map { (idx, input) in
            let name = (input as NSString).lastPathComponent
            let outPath = (outDir as NSString).appendingPathComponent("\(name).zip")
            return BatchCompressTask(inputs: [input], outputPath: outPath, format: .zip)
        }
        
        do {
            let result = try await ArchiveBatchFacade.shared.batchCompressTransactional(tasks: tasks)
            print("✅ 事务型宏命令批处理成功! 生成 \(result.artifactsCreated.count) 个产物。耗时: \(String(format: "%.2f", result.executionDuration))s")
        } catch let CommandError.macroExecutionFailed(idx, err, rollbacks) {
            print("❌ 宏命令在第 [\(idx + 1)] 个步骤发生异常: \(err)")
            print("↩️ 已自动触发逆序 Rollback 回滚，清理任何中间衍生文件。回滚结果: \(rollbacks.isEmpty ? "完全回滚成功" : rollbacks.joined(separator: "; "))")
        } catch {
            print("❌ 批量命令执行失败: \(error.localizedDescription)")
        }
    }
    
    public static func printUsage() {
        print("""
        ================================================================
        TTZip Enterprise CLI 工具集 v1.5.0 (Apple Silicon M-Series Engine)
        ================================================================
        用法:
          ttzip-cli inspect <archive-path> [-p pwd]         查看归档目录树与元数据
          ttzip-cli extract <archive> <dest-dir> [-p pwd]   安全解缩归档包至目标文件夹
          ttzip-cli create <out> <files...> [-f 7z|zip] [-s 100m] [-p pwd] 打包压缩
          ttzip-cli recover <archive> <dict.txt>           多核并行字典解密恢复
          ttzip-cli bench [50MB|100MB|500MB|1GB]           全核 CPU 硬件极速基准压测
          ttzip-cli bench_pk --all-formats --stop-on-lag    全 16 种格式 1v1 竞品擂台赛
          ttzip-cli clean / purge                           一键清空测试数据集与全部缓存
          ttzip-cli test <archive-path>                    计算 CRC32/SHA256 完整性
          ttzip-cli repair <damaged> <repaired>            扫描并修复损坏归档数据块
          ttzip-cli batch <outDir> <files...>              命令模式事务型多任务打包 (含失败自动回滚)
          ttzip-cli preset                                查看生效压缩预设方案
          ttzip-cli --version                              查看版本信息
        """)
    }
    
    private static func inspectArchive(path: String, password: String?) async {
        print("🔍 正在读取归档元数据: \(path)...")
        do {
            let res = try await SmartLoggingProxy.shared.inspectArchive(archivePath: path, password: password)
            print("=================================================================")
            // 运用【3.7 迭代器模式 (Iterator Pattern)】原生 Sequence 与 ArrayArchiveIterator 流式打印
            let iterator = res.makeIterator()
            while let entry = iterator.next() {
                let sizeStr = entry.isDirectory ? "<DIR>" : "\(entry.uncompressedSize) B"
                let p = entry.path.padding(toLength: 45, withPad: " ", startingAt: 0)
                let s = sizeStr.padding(toLength: 12, withPad: " ", startingAt: 0)
                print("\(p) | \(s) | \(entry.detectedEncoding)")
            }
            print("=================================================================")
            print("🌲 组合模式 (Composite Pattern) 树形层级结构 (DFS Iterator):")
            print(res.treeNode.renderTree())
            print("=================================================================")
            print("共计 \(res.entries.count) 个条目 (包含 \(res.treeNode.totalDirectoryCount()) 目录, \(res.treeNode.totalFileCount()) 文件)。")
            print(res.securityReport.detailMessage)
        } catch {
            print("❌ 检查失败: \(error.localizedDescription)")
        }
    }
    
    private static func extractArchive(archivePath: String, destDir: String, password: String?) async {
        print("📦 正在安全解压: \(archivePath) -> \(destDir)...")
        do {
            let res = try await securityProxy.quickExtract(
                archivePath: archivePath,
                destinationDir: destDir,
                password: password
            )
            print(String(format: "✅ 解压成功! 耗时: %.2fs", res.durationSeconds))
        } catch {
            print("❌ 解压失败: \(error.localizedDescription)")
        }
    }
    
    private static func createArchive(
        outputPath: String,
        inputPaths: [String],
        options: CLIOptions
    ) async {
        print("⚡️ 正在通过 Apple Silicon 拓扑引擎打包压缩...")
        
        let formatRaw = options.format
        let splitSizeRaw = options.splitSize
        let levelRaw = options.level
        let password = options.password
        
        let format: ArchiveCompressionFormat
        switch (formatRaw ?? "").lowercased() {
        case "7z", "sevenzip": format = .sevenZip
        case "tar.zst", "tzst": format = .tarZst
        case "tar.gz", "tgz": format = .tarGz
        default: format = .zip
        }
        
        let compLevel: ArchiveCompressionLevel
        if let raw = levelRaw?.lowercased(), let intVal = Int(raw) {
            compLevel = ArchiveCompressionLevel(levelInt: intVal)
        } else {
            switch (levelRaw ?? "").lowercased() {
            case "store", "none", "copy": compLevel = .store
            case "fastest": compLevel = .fastest
            case "fast": compLevel = .fast
            case "medium": compLevel = .medium
            case "normal": compLevel = .normal
            case "maximum", "max": compLevel = .maximum
            case "ultra": compLevel = .ultra
            default: compLevel = .normal
            }
        }
        
        var splitBytes: Int64? = nil
        if let raw = splitSizeRaw?.lowercased() {
            if raw.hasSuffix("m") || raw.hasSuffix("mb") {
                let num = Double(raw.replacingOccurrences(of: "mb", with: "").replacingOccurrences(of: "m", with: "")) ?? 100
                splitBytes = Int64(num * 1024 * 1024)
            } else if raw.hasSuffix("g") || raw.hasSuffix("gb") {
                let num = Double(raw.replacingOccurrences(of: "gb", with: "").replacingOccurrences(of: "g", with: "")) ?? 1
                splitBytes = Int64(num * 1024 * 1024 * 1024)
            }
        }
        
        do {
            let res = try await securityProxy.quickCompress(
                inputs: inputPaths,
                outputPath: outputPath,
                format: format,
                level: compLevel,
                password: password,
                splitSize: splitBytes
            )
            print(String(format: "✅ 打包压缩成功: \(res.outputPath) (耗时 %.2fs, 吞吐率 %.1f MB/s)", res.durationSeconds, res.throughputMBs))
        } catch {
            print("❌ 打包失败: \(error.localizedDescription)")
        }
    }
    
    private static func recoverPassword(archivePath: String, dictFilePath: String) async {
        print("🔑 正在调度全核 CPU 执行密码破解与恢复: \(archivePath)...")
        guard let dictContent = try? String(contentsOfFile: dictFilePath, encoding: .utf8) else {
            print("❌ 无法读取字典文件: \(dictFilePath)")
            return
        }
        
        let dict = dictContent.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        print("📖 载入字典条目: \(dict.count) 个")
        
        do {
            let res = try await facade.recoverPassword(archivePath: archivePath, dictionary: dict)
            if let pwd = res.foundPassword {
                print("🎉 破解成功！找到正确解密密码: [ \(pwd) ]")
                print("⏱️ 耗时: \(String(format: "%.3f", res.durationSeconds)) 秒 · 尝试次数: \(res.totalAttempts) · 速率: \(String(format: "%.0f", res.attemptsPerSecond)) 密码/秒")
            } else {
                print("❌ 未能在字典中找到匹配密码 (已尝试 \(res.totalAttempts) 次)。")
            }
        } catch {
            print("❌ 恢复引擎错误: \(error.localizedDescription)")
        }
    }
    
    private static func testIntegrity(path: String) async {
        print("🛡️ 正在进行 16MB 页对齐硬件级哈希与完整性校验: \(path)...")
        do {
            let res = try await TTZipEngineFacade.shared.verifyIntegrity(archivePath: path)
            print("CRC32 : \(res.crc32)")
            print("SHA256: \(res.sha256)")
            print("✅ 数据散列计算成功，校验无损坏!")
        } catch {
            print("❌ 哈希计算失败: \(error.localizedDescription)")
        }
    }
    
    private static func repairArchive(damaged: String, output: String) async {
        print("🛠️ 正在进行归档损坏扫描与修复: \(damaged) -> \(output)...")
        do {
            let count = try await TTZipEngineFacade.shared.repairArchive(damagedPath: damaged, outputPath: output)
            print("✅ 修复完成！成功提取重构 \(count) 个可用文件数据块至 \(output)")
        } catch {
            print("❌ 修复失败: \(error.localizedDescription)")
        }
    }
    
    private static func printPresets() {
        print("📋 当前生效的常用压缩预设:")
        for preset in PresetManager.shared.presets {
            print(" - [\(preset.name)] 格式:\(preset.format.rawValue) 分卷:\(preset.splitVolumeDescription)")
        }
    }
}
