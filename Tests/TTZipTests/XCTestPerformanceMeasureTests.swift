import XCTest
import CTTZipBridge
@testable import TTZipCore

/// 使用 AsyncBenchmarkRunner 与 IsolatedTempSandbox 规范评估 Clock / CPU / Memory 性能指标
final class XCTestPerformanceMeasureTests: XCTestCase {
    
    // MARK: - 1. ZIP Level 1 压缩性能硬门禁 (>= 1400 MB/s Debug / >= 1700 MB/s Release)
    
    func testZipCompression_Level1_ThroughputFloor() async throws {
        let metrics = try await AsyncBenchmarkRunner.measure(
            name: "ZIP Level 1 Compression",
            payloadBytes: 10 * 1024 * 1024, // 10MB
            iterations: 3,
            setUp: { sandbox in
                let logFileURL = sandbox.fileURL(named: "sample_log_l1.log")
                try TestFileGenerator.createRealisticLogFile(at: logFileURL, linesCount: 70362)
            },
            block: { sandbox in
                let logFileURL = sandbox.fileURL(named: "sample_log_l1.log")
                let outArchive = sandbox.fileURL(named: "measure_zip_l1.zip").path
                let writer = ArchiveWriter()
                try await writer.createArchive(
                    outputPath: outArchive,
                    format: .zip,
                    level: .fastest,
                    inputPaths: [logFileURL.path]
                )
                XCTAssertTrue(FileManager.default.fileExists(atPath: outArchive))
            }
        )
        #if DEBUG
        XCTAssertGreaterThan(metrics.throughputMBs, 1500.0, "ZIP Level 1 (10MB) 压缩吞吐速率必须高于 1500 MB/s (Debug 模式硬门禁)")
        #else
        XCTAssertGreaterThan(metrics.throughputMBs, 2000.0, "ZIP Level 1 (10MB) 压缩吞吐速率必须高于 2000 MB/s (Release 模式硬门禁)")
        #endif
    }

    // MARK: - 1.1 单体大文件 (50MB) ZIP Level 1 压缩性能硬门禁 (>= 1700 MB/s Debug / >= 2100 MB/s Release)
    
    func testZipCompression_SingleLargeFile_Level1_ThroughputFloor() async throws {
        let metrics = try await AsyncBenchmarkRunner.measure(
            name: "ZIP Single 50MB Level 1 Compression",
            payloadBytes: 50 * 1024 * 1024, // 50MB
            iterations: 2,
            setUp: { sandbox in
                let logFileURL = sandbox.fileURL(named: "sample_large_50m_l1.log")
                try TestFileGenerator.createRealisticLogFile(at: logFileURL, linesCount: 351812)
            },
            block: { sandbox in
                let logFileURL = sandbox.fileURL(named: "sample_large_50m_l1.log")
                let outArchive = sandbox.fileURL(named: "measure_large_50m_l1.zip").path
                let writer = ArchiveWriter()
                try await writer.createArchive(
                    outputPath: outArchive,
                    format: .zip,
                    level: .fastest,
                    inputPaths: [logFileURL.path]
                )
                XCTAssertTrue(FileManager.default.fileExists(atPath: outArchive))
            }
        )
        #if DEBUG
        XCTAssertGreaterThan(metrics.throughputMBs, 1700.0, "单体 50MB 大文件 ZIP Level 1 压缩吞吐必须高于 1700 MB/s (Debug 模式硬门禁)")
        #else
        XCTAssertGreaterThan(metrics.throughputMBs, 2100.0, "单体 50MB 大文件 ZIP Level 1 压缩吞吐必须高于 2100 MB/s (Release 模式硬门禁)")
        #endif
    }

    // MARK: - 2. ZIP Level 6 压缩性能硬门禁 (>= 1100 MB/s Debug / >= 1350 MB/s Release)
    
    func testZipCompression_Level6_ThroughputFloor() async throws {
        let metrics = try await AsyncBenchmarkRunner.measure(
            name: "ZIP Level 6 Compression",
            payloadBytes: 10 * 1024 * 1024, // 10MB
            iterations: 5,
            setUp: { sandbox in
                let logFileURL = sandbox.fileURL(named: "sample_log_l6.log")
                try TestFileGenerator.createRealisticLogFile(at: logFileURL, linesCount: 70362)
            },
            block: { sandbox in
                AppleSiliconTuner.shared.boostCurrentThreadPriority()
                let logFileURL = sandbox.fileURL(named: "sample_log_l6.log")
                let outArchive = sandbox.fileURL(named: "measure_zip_l6.zip").path
                let writer = ArchiveWriter()
                try await writer.createArchive(
                    outputPath: outArchive,
                    format: .zip,
                    level: .normal,
                    inputPaths: [logFileURL.path]
                )
                XCTAssertTrue(FileManager.default.fileExists(atPath: outArchive))
            }
        )
        #if DEBUG
        XCTAssertGreaterThan(metrics.throughputMBs, 1100.0, "ZIP Level 6 压缩吞吐速率必须高于 1100 MB/s (Debug 模式硬门禁)")
        #else
        XCTAssertGreaterThan(metrics.throughputMBs, 1350.0, "ZIP Level 6 压缩吞吐速率必须高于 1350 MB/s (Release 模式硬门禁)")
        #endif

    }
    
    // MARK: - 3. ZIP 极速解压性能硬门禁 (>= 7500 MB/s Debug / >= 10000 MB/s Release)
    
    func testZipDecompression_ThroughputFloor() async throws {
        let metrics = try await AsyncBenchmarkRunner.measure(
            name: "ZIP Decompression",
            payloadBytes: 10 * 1024 * 1024,
            iterations: 3,
            setUp: { sandbox in
                let logFileURL = sandbox.fileURL(named: "sample_log_decomp.log")
                try TestFileGenerator.createRealisticLogFile(at: logFileURL, linesCount: 50000)
                let outArchive = sandbox.fileURL(named: "measure_zip_decomp.zip").path
                let writer = ArchiveWriter()
                try await writer.createArchive(outputPath: outArchive, format: .zip, level: .normal, inputPaths: [logFileURL.path])
            },
            block: { sandbox in
                let outArchive = sandbox.fileURL(named: "measure_zip_decomp.zip").path
                let destDir = sandbox.fileURL(named: "dest_zip").path
                let extractor = ArchiveExtractor()
                try await extractor.extract(archivePath: outArchive, destinationDir: destDir)
                XCTAssertTrue(FileManager.default.fileExists(atPath: destDir))
            }
        )
        #if DEBUG
        XCTAssertGreaterThan(metrics.throughputMBs, 7500.0, "ZIP 解压吞吐速率必须高于 7500 MB/s (Debug 模式硬门禁)")
        #else
        XCTAssertGreaterThan(metrics.throughputMBs, 10000.0, "ZIP 解压吞吐速率必须高于 10000 MB/s (Release 模式硬门禁)")
        #endif
    }
    
    // MARK: - 4. 7Z Level 1 极速压缩门禁 (>= 3200 MB/s Debug / >= 3900 MB/s Release)

    func testSevenZipCompression_Level1_ThroughputFloor() async throws {
        let metrics = try await AsyncBenchmarkRunner.measure(
            name: "7Z Level 1 Compression",
            payloadBytes: 10 * 1024 * 1024,
            iterations: 3,
            setUp: { sandbox in
                let logFileURL = sandbox.fileURL(named: "sample_log_7z_l1.log")
                try TestFileGenerator.createRealisticLogFile(at: logFileURL, linesCount: 50000)
            },
            block: { sandbox in
                let logFileURL = sandbox.fileURL(named: "sample_log_7z_l1.log")
                let outArchive = sandbox.fileURL(named: "measure_7z_l1.7z").path
                let writer = ArchiveWriter()
                try await writer.createArchive(
                    outputPath: outArchive,
                    format: .sevenZip,
                    level: .fastest,
                    inputPaths: [logFileURL.path]
                )
                XCTAssertTrue(FileManager.default.fileExists(atPath: outArchive))
            }
        )
        #if DEBUG
        XCTAssertGreaterThan(metrics.throughputMBs, 3200.0, "7Z Level 1 压缩吞吐必须高于 3200 MB/s (Debug 模式硬门禁)")
        #else
        XCTAssertGreaterThan(metrics.throughputMBs, 3900.0, "7Z Level 1 压缩吞吐必须高于 3900 MB/s (Release 模式硬门禁)")
        #endif
    }

    // MARK: - 4.1 7Z 极速解压性能硬门禁 (>= 6600 MB/s Debug / >= 7200 MB/s Release)

    func testSevenZipDecompression_ThroughputFloor() async throws {
        let metrics = try await AsyncBenchmarkRunner.measure(
            name: "7Z Decompression",
            payloadBytes: 10 * 1024 * 1024,
            iterations: 3,
            setUp: { sandbox in
                let logFileURL = sandbox.fileURL(named: "sample_log_7z_decomp.log")
                try TestFileGenerator.createRealisticLogFile(at: logFileURL, linesCount: 50000)
                let outArchive = sandbox.fileURL(named: "measure_7z_decomp.7z").path
                let writer = ArchiveWriter()
                try await writer.createArchive(outputPath: outArchive, format: .sevenZip, level: .fastest, inputPaths: [logFileURL.path])
            },
            block: { sandbox in
                AppleSiliconTuner.shared.boostCurrentThreadPriority()
                let outArchive = sandbox.fileURL(named: "measure_7z_decomp.7z").path
                let destDir = sandbox.fileURL(named: "dest_7z").path
                let extractor = ArchiveExtractor()
                try await extractor.extract(archivePath: outArchive, destinationDir: destDir)
                XCTAssertTrue(FileManager.default.fileExists(atPath: destDir))
            }
        )
        #if DEBUG
        XCTAssertGreaterThan(metrics.throughputMBs, 6600.0, "7Z 解压吞吐速率必须高于 6600 MB/s (Debug 模式硬门禁)")
        #else
        XCTAssertGreaterThan(metrics.throughputMBs, 7200.0, "7Z 解压吞吐速率必须高于 7200 MB/s (Release 模式硬门禁)")
        #endif
    }

    // MARK: - 4.2 7Z 多固实块 (LZMA2 Level 5) 性能度量 (>= 480 MB/s Debug / >= 620 MB/s Release)
    
    func testSevenZipCompression_XCTestMeasureMetrics() async throws {
        guard SevenZipBinaryResolver.resolveBinaryPath() != nil else {
            throw XCTSkip("7z 二进制未就绪，跳过 7z 性能度量测试")
        }
        
        let metrics = try await AsyncBenchmarkRunner.measure(
            name: "7Z Compression",
            payloadBytes: 10 * 1024 * 1024,
            iterations: 3,
            setUp: { sandbox in
                let logFileURL = sandbox.fileURL(named: "sample_log_7z.log")
                try TestFileGenerator.createRealisticLogFile(at: logFileURL, linesCount: 50000)
            },
            block: { sandbox in
                let logFileURL = sandbox.fileURL(named: "sample_log_7z.log")
                let outArchive = sandbox.fileURL(named: "measure_7z.7z").path
                let writer = ArchiveWriter()
                try await writer.createArchive(
                    outputPath: outArchive,
                    format: .sevenZip,
                    level: .normal,
                    inputPaths: [logFileURL.path]
                )
                XCTAssertTrue(FileManager.default.fileExists(atPath: outArchive))
            }
        )
        #if DEBUG
        XCTAssertGreaterThan(metrics.throughputMBs, 480.0, "7Z 压缩吞吐速率必须高于 480 MB/s (Debug 模式硬门禁)")
        #else
        XCTAssertGreaterThan(metrics.throughputMBs, 620.0, "7Z 压缩吞吐速率必须高于 620 MB/s (Release 模式硬门禁)")
        #endif
    }
    
    // MARK: - 5. 巨型文件 Store 模式 Direct I/O 度量 (>= 6000 MB/s Debug / >= 7500 MB/s Release)
    
    func testZipStore_HugeFile_XCTestMeasureMetrics() async throws {
        let metrics = try await AsyncBenchmarkRunner.measure(
            name: "ZIP Store Direct I/O",
            payloadBytes: 50 * 1024 * 1024, // 50MB
            iterations: 4,
            warmupIterations: 2,
            setUp: { sandbox in
                let hugeFileURL = sandbox.fileURL(named: "huge_50m.bin")
                try TestFileGenerator.createHugeFile(at: hugeFileURL, sizeInMB: 50)
            },
            block: { sandbox in
                AppleSiliconTuner.shared.boostCurrentThreadPriority()
                let hugeFilePath = sandbox.fileURL(named: "huge_50m.bin").path
                let outArchive = sandbox.fileURL(named: "measure_store.zip").path
                let writer = ArchiveWriter()
                try await writer.createArchive(
                    outputPath: outArchive,
                    format: .zip,
                    level: .store,
                    inputPaths: [hugeFilePath]
                )
                XCTAssertTrue(FileManager.default.fileExists(atPath: outArchive))
            }
        )
        #if DEBUG
        XCTAssertGreaterThan(metrics.throughputMBs, 6000.0, "ZIP Store 吞吐速率必须高于 6000 MB/s (Debug 模式硬门禁)")
        #else
        XCTAssertGreaterThan(metrics.throughputMBs, 7500.0, "ZIP Store 吞吐速率必须高于 7500 MB/s (Release 模式硬门禁)")
        #endif
    }
    
    // MARK: - 6. 批量小文件零分配流式扫描与打包硬门禁 (>= 50 MB/s Debug / >= 70 MB/s Release)
    
    func testZipBatchSmallFiles_XCTestMeasureMetrics() async throws {
        let metrics = try await AsyncBenchmarkRunner.measure(
            name: "ZIP Batch Small Files",
            payloadBytes: 2048000,
            iterations: 2,
            setUp: { sandbox in
                let batchDir = sandbox.fileURL(named: "batch_small_files")
                try TestFileGenerator.createBatchSmallFiles(in: batchDir, count: 500, sizePerFileInKB: 4)
            },

            block: { sandbox in
                let batchDir = sandbox.fileURL(named: "batch_small_files")
                let outArchive = sandbox.fileURL(named: "measure_batch.zip").path
                let writer = ArchiveWriter()
                try await writer.createArchive(
                    outputPath: outArchive,
                    format: .zip,
                    level: .normal,
                    inputPaths: [batchDir.path]
                )
                XCTAssertTrue(FileManager.default.fileExists(atPath: outArchive))
            }
        )
        #if DEBUG
        XCTAssertGreaterThan(metrics.throughputMBs, 50.0, "批量小文件压缩吞吐必须高于 50 MB/s (Debug 模式硬门禁)")
        #else
        XCTAssertGreaterThan(metrics.throughputMBs, 70.0, "批量小文件压缩吞吐必须高于 70 MB/s (Release 模式硬门禁)")
        #endif
    }

    // MARK: - 7. TAR.ZST Direct In-Process 流式打包硬门禁 (>= 15000 MB/s Debug / >= 22000 MB/s Release)

    func testTarZstdDirect_50MB_ThroughputFloor() async throws {
        let metrics = try await AsyncBenchmarkRunner.measure(
            name: "TAR.ZST Direct 50MB",
            payloadBytes: 50 * 1024 * 1024,
            iterations: 2,
            setUp: { sandbox in
                let logFileURL = sandbox.fileURL(named: "sample_tar_zst_50m.log")
                try TestFileGenerator.createRealisticLogFile(at: logFileURL, linesCount: 250000)
            },
            block: { sandbox in
                let logFileURL = sandbox.fileURL(named: "sample_tar_zst_50m.log")
                let outArchive = sandbox.fileURL(named: "measure_tar_zst.tar.zst").path
                let writer = ArchiveWriter()
                try await writer.createArchive(
                    outputPath: outArchive,
                    format: .tarZst,
                    level: .level1,
                    inputPaths: [logFileURL.path]
                )
                XCTAssertTrue(FileManager.default.fileExists(atPath: outArchive))
            }
        )
        #if DEBUG
        XCTAssertGreaterThan(metrics.throughputMBs, 15000.0, "TAR.ZST Direct 打包吞吐必须高于 15000 MB/s (Debug 门禁底线)")
        #else
        XCTAssertGreaterThan(metrics.throughputMBs, 22000.0, "TAR.ZST Direct 打包吞吐必须高于 22000 MB/s (Release 门禁底线)")
        #endif
    }

    // MARK: - 8. 7Z AES-256 KDF ARMv8 硬件派生耗时硬门禁 (<= 17 ms Debug / <= 15 ms Release)

    func testSevenZipKdf_HardwareAcceleration_DurationFloor() throws {
        var key = [UInt8](repeating: 0, count: 32)
        let pass = "TTZipSecurityVaultBenchmark2026!"
        let salt: [UInt8] = [0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88]

        let t0 = CACurrentMediaTime()
        let res = ttzip_7z_kdf_sha256_armv8(pass, salt, salt.count, 19, &key)
        let elapsedMs = (CACurrentMediaTime() - t0) * 1000.0

        XCTAssertEqual(res, 0, "7z KDF 必须执行成功")
        #if DEBUG
        XCTAssertLessThanOrEqual(elapsedMs, 17.0, "7z ARMv8 SHA-256 KDF (524,288 轮) 耗时必须在 17ms 以内 (Debug 模式)")
        #else
        XCTAssertLessThanOrEqual(elapsedMs, 15.0, "7z ARMv8 SHA-256 KDF (524,288 轮) 耗时必须在 15ms 以内 (Release 模式)")
        #endif
    }

    // MARK: - 9. LZ4 进程内流式压缩性能硬门禁 (>= 6000 MB/s Debug / >= 10000 MB/s Release)

    func testLZ4_Compression_ThroughputFloor() async throws {
        let metrics = try await AsyncBenchmarkRunner.measure(
            name: "LZ4 Compression",
            payloadBytes: 10 * 1024 * 1024,
            iterations: 3,
            setUp: { sandbox in
                let logFileURL = sandbox.fileURL(named: "sample_lz4_10m.log")
                try TestFileGenerator.createRealisticLogFile(at: logFileURL, linesCount: 50000)
            },
            block: { sandbox in
                let logFileURL = sandbox.fileURL(named: "sample_lz4_10m.log")
                let outArchive = sandbox.fileURL(named: "measure_lz4.lz4").path
                let writer = ArchiveWriter()
                try await writer.createArchive(
                    outputPath: outArchive,
                    format: .lz4,
                    level: .fastest,
                    inputPaths: [logFileURL.path]
                )
                XCTAssertTrue(FileManager.default.fileExists(atPath: outArchive))
            }
        )
        #if DEBUG
        XCTAssertGreaterThan(metrics.throughputMBs, 6000.0, "LZ4 压缩吞吐速率必须高于 6000 MB/s (Debug 模式硬门禁)")
        #else
        XCTAssertGreaterThan(metrics.throughputMBs, 10000.0, "LZ4 压缩吞吐速率必须高于 10000 MB/s (Release 模式硬门禁)")
        #endif
    }

    // MARK: - 10. TAR.XZ 进程内多核流式打包性能硬门禁 (>= 1200 MB/s Debug / >= 1800 MB/s Release)

    func testTarXz_Compression_ThroughputFloor() async throws {
        let metrics = try await AsyncBenchmarkRunner.measure(
            name: "TAR.XZ Compression",
            payloadBytes: 10 * 1024 * 1024,
            iterations: 2,
            setUp: { sandbox in
                let logFileURL = sandbox.fileURL(named: "sample_tar_xz_10m.log")
                try TestFileGenerator.createRealisticLogFile(at: logFileURL, linesCount: 50000)
            },
            block: { sandbox in
                let logFileURL = sandbox.fileURL(named: "sample_tar_xz_10m.log")
                let outArchive = sandbox.fileURL(named: "measure_tar_xz.tar.xz").path
                let writer = ArchiveWriter()
                try await writer.createArchive(
                    outputPath: outArchive,
                    format: .tarXz,
                    level: .level1,
                    inputPaths: [logFileURL.path]
                )
                XCTAssertTrue(FileManager.default.fileExists(atPath: outArchive))
            }
        )
        #if DEBUG
        XCTAssertGreaterThan(metrics.throughputMBs, 1200.0, "TAR.XZ 压缩吞吐速率必须高于 1200 MB/s (Debug 模式硬门禁)")
        #else
        XCTAssertGreaterThan(metrics.throughputMBs, 1800.0, "TAR.XZ 压缩吞吐速率必须高于 1800 MB/s (Release 模式硬门禁)")
        #endif
    }
}
