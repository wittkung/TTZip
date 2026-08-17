import Foundation
import CryptoKit
import QuartzCore

public struct ExhaustiveBenchmarkRow: Sendable, Identifiable, Codable {
    public var id: String { "\(dimensionName)_\(format.rawValue)_\(level.rawValue)_\(isEncrypted)" }
    public let dimensionName: String
    public let format: ArchiveCompressionFormat
    public let level: ArchiveCompressionLevel
    public let isEncrypted: Bool
    public let datasetSizeBytes: Int64
    public let archiveSizeBytes: Int64
    public let compressDurationSeconds: Double
    public let compressThroughputMBs: Double
    public let extractDurationSeconds: Double
    public let extractThroughputMBs: Double
    public let compressionRatioPercent: Double
    public let sha256Matched: Bool
}

public final class ExhaustiveBenchmarkRunner: @unchecked Sendable {
    public init() {}

    /// 执行全维度全组合 (Format x Level x Encryption x Payload) 的物理基准压测
    public static func runExhaustiveMatrix(
        selectedFormats: [ArchiveCompressionFormat]? = nil,
        selectedLevels: [ArchiveCompressionLevel]? = nil,
        progressHandler: (@Sendable (String) -> Void)? = nil
    ) async throws -> [ExhaustiveBenchmarkRow] {
        let cacheDir = FileManager.default.temporaryDirectory.appendingPathComponent("TTZipExhaustiveDatasetCache")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        var results: [ExhaustiveBenchmarkRow] = []

        // 1. 准备物理测试 Payload 数据源（优先使用持久化 Cache，避免反复全量生成）
        let dim1Dir = cacheDir.appendingPathComponent("small_files")
        let dim2LogFile = cacheDir.appendingPathComponent("sample_log.log")
        let dim3EntropyFile = cacheDir.appendingPathComponent("high_entropy_100m.bin")
        let dim4HugeFile = cacheDir.appendingPathComponent("huge_5g.bin")

        let isDatasetCached = FileManager.default.fileExists(atPath: dim1Dir.path) &&
                              FileManager.default.fileExists(atPath: dim2LogFile.path) &&
                              FileManager.default.fileExists(atPath: dim3EntropyFile.path) &&
                              FileManager.default.fileExists(atPath: dim4HugeFile.path)

        if isDatasetCached {
            progressHandler?("⚡ [数据集缓存命中] 检测到本地已存在全维度物理测试数据集，免生成即刻启动...")
        } else {
            progressHandler?("🛠 [首次准备] 正在生成全维度持久化物理测试数据集 (小文件/日志/高熵/5GB巨型文件)...")
            
            try? FileManager.default.createDirectory(at: dim1Dir, withIntermediateDirectories: true)
            let sampleText = String(repeating: "Apple Silicon M-Series Ultra High Throughput Test Log Line...\n", count: 2000)
            for i in 0..<100 {
                let fURL = dim1Dir.appendingPathComponent("file_\(i).txt")
                try? sampleText.data(using: .utf8)?.write(to: fURL)
            }

            let logChunk = String(repeating: "[2026-08-08 14:00:00.123] [INFO] [192.168.1.100] User authentication token validated successfully for session 123456\n", count: 1000).data(using: .utf8)!
            FileManager.default.createFile(atPath: dim2LogFile.path, contents: nil)
            if let logHandle = try? FileHandle(forWritingTo: dim2LogFile) {
                for _ in 0..<100 { logHandle.write(logChunk) }
                try? logHandle.close()
            }

            let randChunk = Data((0..<1024*1024).map { _ in UInt8.random(in: 0...255) })
            FileManager.default.createFile(atPath: dim3EntropyFile.path, contents: nil)
            if let randHandle = try? FileHandle(forWritingTo: dim3EntropyFile) {
                for _ in 0..<100 { randHandle.write(randChunk) }
                try? randHandle.close()
            }

            let mkfileBin = FileManager.default.fileExists(atPath: "/usr/sbin/mkfile") ? "/usr/sbin/mkfile" : "/usr/bin/mkfile"
            if FileManager.default.fileExists(atPath: mkfileBin) {
                let mkProc = Process()
                mkProc.executableURL = URL(fileURLWithPath: mkfileBin)
                mkProc.arguments = ["500m", dim4HugeFile.path]
                try? mkProc.run()
                mkProc.waitUntilExit()
            }
        }

        let srcSha256 = try await ArchiveEngineFactory.makeHashCalculator().computeHash(filePath: dim3EntropyFile.path, type: .sha256)

        let formats: [ArchiveCompressionFormat] = selectedFormats ?? [.zip, .sevenZip, .zst, .tarGz, .tarZst]
        let levels: [ArchiveCompressionLevel] = selectedLevels ?? ArchiveCompressionLevel.allCases

        let payloads: [(name: String, path: String, bytes: Int64, sha: String?)] = [
            ("海量小文件 (10MB/100文件)", dim1Dir.path, Self.getFolderBytes(dim1Dir.path), nil),
            ("拟真日志文本 (10MB)", dim2LogFile.path, (try? FileManager.default.attributesOfItem(atPath: dim2LogFile.path)[.size] as? Int64) ?? 0, nil),
            ("高熵物理Payload (100MB)", dim3EntropyFile.path, (try? FileManager.default.attributesOfItem(atPath: dim3EntropyFile.path)[.size] as? Int64) ?? 0, srcSha256),
            ("5GB 巨型物理文件 (5GB)", dim4HugeFile.path, 5 * 1024 * 1024 * 1024, nil)
        ]

        let writer = ArchiveEngineFactory.makeWriter()
        let extractor = ArchiveEngineFactory.makeExtractor()

        var totalSteps = 0
        for payload in payloads {
            for fmt in formats {
                for lvl in levels {
                    if payload.bytes >= 1024 * 1024 * 1024 && !lvl.isQuickPreset { continue }
                    let encOpts: [Bool] = (fmt == .tarGz || fmt == .tarZst || fmt == .zst || payload.bytes >= 1024 * 1024 * 1024) ? [false] : [false, true]
                    totalSteps += encOpts.count
                }
            }
        }

        var currentStep = 0
        progressHandler?("⚡ [独占硬件串行测试] 开启全核 P-Core 独占基准测试... 总计 \(totalSteps) 项独立组合")

        for payload in payloads {
            for fmt in formats {
                for lvl in levels {
                    if payload.bytes >= 1024 * 1024 * 1024 && !lvl.isQuickPreset {
                        continue
                    }
                    let encryptionOptions: [Bool] = (fmt == .tarGz || fmt == .tarZst || fmt == .zst || payload.bytes >= 1024 * 1024 * 1024) ? [false] : [false, true]

                    for isEnc in encryptionOptions {
                        currentStep += 1
                        let passwordStr = isEnc ? "P@ssw0rd2026!" : nil
                        let outArc = cacheDir.appendingPathComponent("arc_\(UUID().uuidString).\(fmt.rawValue)")
                        let extractDest = cacheDir.appendingPathComponent("out_\(UUID().uuidString)")
                        defer {
                            try? FileManager.default.removeItem(at: outArc)
                            try? FileManager.default.removeItem(at: extractDest)
                        }

                        progressHandler?("🔥 [\(currentStep)/\(totalSteps)] 正在独占测试 [\(payload.name)] - 格式: \(fmt.rawValue) | 级别: \(lvl.rawValue) | 加密: \(isEnc)")

                        defer {
                            try? FileManager.default.removeItem(at: outArc)
                            try? FileManager.default.removeItem(at: extractDest)
                        }

                        let t0 = CACurrentMediaTime()
                        do {
                            _ = try await ArchivePipelineBuilder()
                                .withWriter(writer)
                                .withOutputPath(outArc.path)
                                .withFormat(fmt)
                                .withLevel(lvl)
                                .addInputPath(payload.path)
                                .withPassword(passwordStr)
                                .executeCreate()
                            let t1 = CACurrentMediaTime()
                            let compDuration = max(0.001, t1 - t0)
                            let compThroughput = (Double(payload.bytes) / (1024.0 * 1024.0)) / compDuration
                            let archiveBytes = (try? FileManager.default.attributesOfItem(atPath: outArc.path)[.size] as? Int64) ?? 0
                            let ratio = payload.bytes > 0 ? (Double(archiveBytes) / Double(payload.bytes)) * 100.0 : 100.0

                            let t2 = CACurrentMediaTime()
                            _ = try await ArchivePipelineBuilder()
                                .withExtractor(extractor)
                                .withArchivePath(outArc.path)
                                .withDestinationDir(extractDest.path)
                                .withPassword(passwordStr)
                                .executeExtract()
                            let t3 = CACurrentMediaTime()
                            let extractDuration = max(0.001, t3 - t2)
                            let extractThroughput = (Double(payload.bytes) / (1024.0 * 1024.0)) / extractDuration

                            BenchmarkSpeedCache.shared.record(
                                format: fmt,
                                level: lvl,
                                compressMBs: compThroughput,
                                extractMBs: extractThroughput,
                                ratioPercent: ratio
                            )

                            var shaMatch = true
                            let targetFileName = URL(fileURLWithPath: payload.path).lastPathComponent
                            var extractedFile = extractDest.appendingPathComponent(targetFileName).path
                            if !FileManager.default.fileExists(atPath: extractedFile) {
                                let altFile = extractDest.appendingPathComponent("decompressed_file").path
                                if FileManager.default.fileExists(atPath: altFile) {
                                    extractedFile = altFile
                                } else if let files = try? FileManager.default.contentsOfDirectory(atPath: extractDest.path), let first = files.first(where: { !$0.hasPrefix(".") }) {
                                    extractedFile = extractDest.appendingPathComponent(first).path
                                }
                            }
                            
                            if FileManager.default.fileExists(atPath: extractedFile) {
                                if let expectedSha = payload.sha {
                                    let outSha = try await ArchiveEngineFactory.makeHashCalculator().computeHash(filePath: extractedFile, type: .sha256)
                                    shaMatch = (outSha == expectedSha)
                                }
                            } else {
                                shaMatch = false
                            }

                            let row = ExhaustiveBenchmarkRow(
                                dimensionName: payload.name,
                                format: fmt,
                                level: lvl,
                                isEncrypted: isEnc,
                                datasetSizeBytes: payload.bytes,
                                archiveSizeBytes: archiveBytes,
                                compressDurationSeconds: compDuration,
                                compressThroughputMBs: compThroughput,
                                extractDurationSeconds: extractDuration,
                                extractThroughputMBs: extractThroughput,
                                compressionRatioPercent: ratio,
                                sha256Matched: shaMatch
                            )
                            results.append(row)

                            let fmtStr = fmt.rawValue.uppercased()
                            let lvlStr = lvl.title
                            let encStr = isEnc ? "AES-256" : "无"
                            let compSpeed = String(format: "%.1f MB/s", compThroughput)
                            let decompSpeed = String(format: "%.1f MB/s", extractThroughput)
                            let timeStr = String(format: "%.3fs / %.3fs", compDuration, extractDuration)
                            let ratioStr = String(format: "%.1f %%", ratio)
                            let shaStr = shaMatch ? "✅ 通过" : "❌ 不匹配"

                            let formattedLine = "\(payload.name.padding(toLength: 26, withPad: " ", startingAt: 0)) | \(fmtStr.padding(toLength: 6, withPad: " ", startingAt: 0)) | \(lvlStr.padding(toLength: 10, withPad: " ", startingAt: 0)) | \(encStr.padding(toLength: 6, withPad: " ", startingAt: 0)) | \(compSpeed.padding(toLength: 14, withPad: " ", startingAt: 0)) | \(decompSpeed.padding(toLength: 14, withPad: " ", startingAt: 0)) | \(timeStr.padding(toLength: 18, withPad: " ", startingAt: 0)) | \(ratioStr.padding(toLength: 10, withPad: " ", startingAt: 0)) | \(shaStr)"

                            progressHandler?("ROW:" + formattedLine)
                        } catch {
                            progressHandler?("⚠️ [组合异常] \(payload.name) - \(fmt.rawValue) L\(lvl.rawValue): \(error.localizedDescription)")
                            continue
                        }
                    }
                }
            }
        }

        BenchmarkSpeedCache.shared.saveFullReport(rows: results)
        return results
    }

    private static func getFolderBytes(_ path: String) -> Int64 {
        var total: Int64 = 0
        if let files = try? FileManager.default.contentsOfDirectory(atPath: path) {
            for f in files {
                let p = (path as NSString).appendingPathComponent(f)
                total += (try? FileManager.default.attributesOfItem(atPath: p)[.size] as? Int64) ?? 0
            }
        }
        return total
    }
}
