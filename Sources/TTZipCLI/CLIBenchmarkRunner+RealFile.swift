import Foundation
import QuartzCore
import TTZipCore

extension CLIBenchmarkRunner {
    public static func runRealFileBenchmark(
        inputPath: String,
        formatFilter: String? = nil,
        levelFilter: String? = nil,
        toolFilter: String? = nil,
        password: String? = nil,
        enableZeroCopy: Bool = false
    ) async {
        let fm = FileManager.default
        let expandedPath = NSString(string: inputPath).expandingTildeInPath
        guard fm.fileExists(atPath: expandedPath) else {
            print("❌ 错误: 传入的文件或目录路径不存在: \(inputPath)")
            return
        }

        let isDirectory: Bool
        var isDirBool: ObjCBool = false
        fm.fileExists(atPath: expandedPath, isDirectory: &isDirBool)
        isDirectory = isDirBool.boolValue
        
        let totalOriginalBytes: Int64
        if isDirectory {
            totalOriginalBytes = (try? CompetitorBenchmarkRunner.folderSize(expandedPath)) ?? 0
        } else {
            let attrs = try? fm.attributesOfItem(atPath: expandedPath)
            totalOriginalBytes = (attrs?[.size] as? Int64) ?? 0
        }

        let sizeMB = Double(totalOriginalBytes) / (1024 * 1024)
        print("\n========================================================================================================================")
        print("⚔️ 真实实操全场景压测 [目标: \(expandedPath)] [总体积: \(String(format: "%.2f MB", sizeMB))] [密码: \(password != nil ? "已指定" : "无")]")
        print("========================================================================================================================")

        let allFormats: [ArchiveCompressionFormat] = [
            .sevenZip, .zip, .tar, .zst, .gz, .bz2, .xz, .lzip,
            .lz4, .brotli, .lrzip, .aar, .snappy, .wim, .dmg, .iso
        ]
        let allLevels: [ArchiveCompressionLevel] = [.fastest, .normal, .maximum, .ultra]

        var selectedFormats = allFormats
        if let fRaw = formatFilter, !fRaw.isEmpty {
            let parts = fRaw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            selectedFormats = allFormats.filter { f in
                parts.contains(f.rawValue.lowercased()) ||
                (f == .zip && parts.contains("zip")) ||
                (f == .sevenZip && (parts.contains("7z") || parts.contains("7zip"))) ||
                (f == .zst && (parts.contains("zst") || parts.contains("zstd"))) ||
                (f == .tarGz && (parts.contains("tar.gz") || parts.contains("tgz"))) ||
                (f == .tarZst && (parts.contains("tar.zst") || parts.contains("tzst")))
            }
        }

        var selectedLevels = allLevels
        if let lRaw = levelFilter, !lRaw.isEmpty {
            let parts = lRaw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            selectedLevels = allLevels.filter { l in
                parts.contains(String(l.rawValue))
            }
        }

        for fmt in selectedFormats {
            for lvl in selectedLevels {
                if (fmt == .zst || fmt == .tarGz || fmt == .tarZst) && password != nil {
                    continue
                }
                
                print("\n------------------------------------------------------------------------------------------------------------------------")
                print("🎯 [测试场景] 格式: \(fmt.rawValue.uppercased()) | 级别: L\(lvl.rawValue)")
                print("------------------------------------------------------------------------------------------------------------------------")

                let hc1 = padColumn("软件 / 算法", 24)
                let hc2 = padColumn("打包速率 (MB/s)", 16)
                let hc3 = padColumn("解压速率 (MB/s)", 16)
                let hc4 = padColumn("耗时 (打包/解压)", 18)
                let hc5 = padColumn("产物体积", 12)
                let hc6 = padColumn("哈希与完整性", 12)
                let hc7 = padColumn("性能定位", 22)
                print("\(hc1) | \(hc2) | \(hc3) | \(hc4) | \(hc5) | \(hc6) | \(hc7)")
                print("------------------------------------------------------------------------------------------------------------------------")

                let workDir = fm.temporaryDirectory.appendingPathComponent("RealBench_\(UUID().uuidString)")
                try? fm.createDirectory(at: workDir, withIntermediateDirectories: true)
                defer { try? fm.removeItem(at: workDir) }

                let ttArc = workDir.appendingPathComponent("tt_out.\(fmt.rawValue)").path
                let ttOut = workDir.appendingPathComponent("tt_extracted").path

                var ttCompTime: Double = 0
                var ttExtTime: Double = 0
                var ttValid = false
                var ttCrcStr = "N/A"
                var ttStatusName = "👑 TTZip (SIMD Accel)"

                let checker = ArchiveEngineFactory.makeIntegrityChecker()

                let compStart = PlatformMonotonicTimer.nowSeconds()
                do {
                    let advOpts = ArchiveAdvancedOptions.builder()
                        .withEnableZeroCopy(enableZeroCopy)
                        .build()
                    _ = try await TTZipEngineFacade.shared.quickCompress(
                        inputs: [expandedPath],
                        outputPath: ttArc,
                        format: fmt,
                        level: lvl,
                        password: password,
                        advancedOptions: advOpts
                    )
                    ttCompTime = max(0.001, PlatformMonotonicTimer.nowSeconds() - compStart)
                } catch {
                    ttStatusName = "❌ TTZip 打包失败"
                }

                do {
                    try? fm.createDirectory(atPath: ttOut, withIntermediateDirectories: true)
                    let extRes = try await TTZipEngineFacade.shared.quickExtract(
                        archivePath: ttArc,
                        destinationDir: ttOut,
                        password: password
                    )
                    ttExtTime = max(0.001, extRes.durationSeconds)
                    let res = checker.verifyExtractedDirectory(
                        directoryPath: ttOut,
                        expectedOriginalBytes: totalOriginalBytes,
                        sourceFilePath: isDirectory ? nil : expandedPath,
                        sourceCRC32: nil,
                        label: "TTZip RealBench Verification"
                    )
                    ttValid = res.isValid
                    ttCrcStr = res.crc32 ?? "OK"
                } catch {
                    ttStatusName = "❌ TTZip 解压失败"
                }

                let ttCompMBs = sizeMB / ttCompTime
                let ttExtMBs = sizeMB / ttExtTime

                var competitorRows: [(name: String, compMBs: Double, extMBs: Double, compTime: Double, extTime: Double, sizeMB: Double, crc: String, valid: Bool, label: String)] = []

                let need7z = toolFilter == nil || toolFilter!.contains("7z") || toolFilter!.contains("7zz")
                if need7z, let p7z = SevenZipBinaryResolver.resolveBinaryPath() {
                    let arc7z = workDir.appendingPathComponent("comp_7z.\(fmt.rawValue)").path
                    let out7z = workDir.appendingPathComponent("comp_7z_extracted").path

                    var cTime: Double = 0
                    var eTime: Double = 0
                    var aSize: Int64 = 0
                    var valid = false
                    var crcStr = "N/A"

                    var compArgs: [String] = ["a"]
                    if fmt == .zip { compArgs.append("-tzip") }
                    else if fmt == .sevenZip { compArgs.append("-t7z") }
                    
                    if lvl == .fastest { compArgs.append("-mx=1") }
                    else if lvl == .normal { compArgs.append("-mx=5") }
                    else if lvl == .maximum { compArgs.append("-mx=7") }
                    else if lvl == .ultra { compArgs.append("-mx=9") }
                    
                    if let pwd = password, !pwd.isEmpty {
                        compArgs.append("-p\(pwd)")
                    }
                    compArgs.append(arc7z)
                    compArgs.append(expandedPath)

                    let cs = PlatformMonotonicTimer.nowSeconds()
                    _ = CompetitorBenchmarkRunner.runCLI(p7z, compArgs)
                    cTime = max(0.001, PlatformMonotonicTimer.nowSeconds() - cs)
                    aSize = (try? fm.attributesOfItem(atPath: arc7z)[.size] as? Int64) ?? 0

                    try? fm.createDirectory(atPath: out7z, withIntermediateDirectories: true)
                    var extArgs = ["x", arc7z, "-o\(out7z)", "-y"]
                    if let pwd = password, !pwd.isEmpty {
                        extArgs.append("-p\(pwd)")
                    }
                    let es = PlatformMonotonicTimer.nowSeconds()
                    _ = CompetitorBenchmarkRunner.runCLI(p7z, extArgs)
                    eTime = max(0.001, PlatformMonotonicTimer.nowSeconds() - es)

                    let vRes = checker.verifyExtractedDirectory(
                        directoryPath: out7z,
                        expectedOriginalBytes: totalOriginalBytes,
                        sourceFilePath: isDirectory ? nil : expandedPath,
                        sourceCRC32: nil,
                        label: "7-Zip RealBench Verification"
                    )
                    valid = vRes.isValid
                    crcStr = vRes.crc32 ?? "OK"

                    let cMBs = sizeMB / cTime
                    let eMBs = sizeMB / eTime
                    let compRatio = ttCompMBs / max(0.1, cMBs)
                    let extRatio = ttExtMBs / max(0.1, eMBs)
                    let labelStr = String(format: "TTZip 领先 %.1fx / %.1fx", compRatio, extRatio)

                    competitorRows.append(("⚡ 7-Zip 7zz CLI", cMBs, eMBs, cTime, eTime, Double(aSize)/(1024*1024), crcStr, valid, labelStr))
                }

                let rc1 = padColumn(ttStatusName, 24)
                let rc2 = padColumn(String(format: "%.1f MB/s", ttCompMBs), 16)
                let rc3 = padColumn(String(format: "%.1f MB/s", ttExtMBs), 16)
                let rc4 = padColumn(String(format: "%.3fs / %.3fs", ttCompTime, ttExtTime), 18)
                let rc5 = padColumn(ttCrcStr, 12)
                let rc6 = padColumn(ttValid ? "✅ 100% 匹配" : "❌ 不匹配", 12)
                let rc7 = padColumn("基准 (1.0x / 1.0x)", 22)
                print("\(rc1) | \(rc2) | \(rc3) | \(rc4) | \(rc5) | \(rc6) | \(rc7)")

                for comp in competitorRows {
                    let kc1 = padColumn(comp.name, 24)
                    let kc2 = padColumn(String(format: "%.1f MB/s", comp.compMBs), 16)
                    let kc3 = padColumn(String(format: "%.1f MB/s", comp.extMBs), 16)
                    let kc4 = padColumn(String(format: "%.3fs / %.3fs", comp.compTime, comp.extTime), 18)
                    let kc5 = padColumn(comp.crc, 12)
                    let kc6 = padColumn(comp.valid ? "✅ 100% 匹配" : "❌ 不匹配", 12)
                    let kc7 = padColumn(comp.label, 22)
                    print("\(kc1) | \(kc2) | \(kc3) | \(kc4) | \(kc5) | \(kc6) | \(kc7)")
                }

                try? fm.removeItem(atPath: ttArc)
                try? fm.removeItem(atPath: ttOut)
            }
        }
        print("========================================================================================================================\n")
    }
}
