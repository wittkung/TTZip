// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class RealWorldPerformanceTests: XCTestCase {
    
    // MARK: - 1. Tiny Files Scenario (High I/O Overhead)
    
    func testZipPerformance_TinyFiles() async throws {
        let metrics = try await AsyncBenchmarkRunner.measure(
            name: "Zip Tiny Files",
            payloadBytes: 1000 * 10240, // ~10MB
            iterations: TestBenchmarkTier.isBenchmarkMode ? 2 : 1,
            setUp: { sandbox in
                let inputDir = sandbox.fileURL(named: "tiny_files_in")
                try TestFileGenerator.createBatchSmallFiles(in: inputDir, count: 1000, sizePerFileInKB: 10)
            },
            block: { sandbox in
                let inputDir = sandbox.fileURL(named: "tiny_files_in")
                let outArchive = sandbox.fileURL(named: "tiny_test.zip").path
                let writer = ArchiveWriter()
                try await writer.createArchive(
                    outputPath: outArchive,
                    format: .zip,
                    level: .normal,
                    inputPaths: [inputDir.path]
                )
                XCTAssertTrue(FileManager.default.fileExists(atPath: outArchive))
            }
        )
        XCTAssertGreaterThan(metrics.throughputMBs, 1.0)
    }
    
    func testSevenZipPerformance_TinyFiles() async throws {
        guard SevenZipBinaryResolver.resolveBinaryPath() != nil else {
            throw XCTSkip("7z binary not found, skipping 7z tests.")
        }
        
        let metrics = try await AsyncBenchmarkRunner.measure(
            name: "7Z Tiny Files",
            payloadBytes: 1000 * 10240,
            iterations: TestBenchmarkTier.isBenchmarkMode ? 2 : 1,
            setUp: { sandbox in
                let inputDir = sandbox.fileURL(named: "tiny_files_in_7z")
                try TestFileGenerator.createBatchSmallFiles(in: inputDir, count: 1000, sizePerFileInKB: 10)
            },
            block: { sandbox in
                let inputDir = sandbox.fileURL(named: "tiny_files_in_7z")
                let outArchive = sandbox.fileURL(named: "tiny_test.7z").path
                let writer = ArchiveWriter()
                try await writer.createArchive(
                    outputPath: outArchive,
                    format: .sevenZip,
                    level: .normal,
                    inputPaths: [inputDir.path]
                )
                XCTAssertTrue(FileManager.default.fileExists(atPath: outArchive))
            }
        )
        XCTAssertGreaterThan(metrics.throughputMBs, 0.5)
    }
    
    // MARK: - 2. Large Compressible Data Scenario
    
    func testZipPerformance_LargeCompressible() async throws {
        let metrics = try await AsyncBenchmarkRunner.measure(
            name: "Zip Large Compressible",
            payloadBytes: 20 * 1024 * 1024, // 20MB
            iterations: TestBenchmarkTier.isBenchmarkMode ? 2 : 1,
            setUp: { sandbox in
                let logFileURL = sandbox.fileURL(named: "large_comp.log")
                try TestFileGenerator.createRealisticLogFile(at: logFileURL, linesCount: 100000)
            },
            block: { sandbox in
                let inputFile = sandbox.fileURL(named: "large_comp.log").path
                let outArchive = sandbox.fileURL(named: "large_comp.zip").path
                let writer = ArchiveWriter()
                try await writer.createArchive(
                    outputPath: outArchive,
                    format: .zip,
                    level: .fast,
                    inputPaths: [inputFile]
                )
                XCTAssertTrue(FileManager.default.fileExists(atPath: outArchive))
            }
        )
        XCTAssertGreaterThan(metrics.throughputMBs, 5.0)
    }
    
    func testSevenZipPerformance_LargeCompressible() async throws {
        guard SevenZipBinaryResolver.resolveBinaryPath() != nil else { throw XCTSkip() }
        
        let metrics = try await AsyncBenchmarkRunner.measure(
            name: "7Z Large Compressible",
            payloadBytes: 20 * 1024 * 1024,
            iterations: TestBenchmarkTier.isBenchmarkMode ? 2 : 1,
            setUp: { sandbox in
                let logFileURL = sandbox.fileURL(named: "large_comp_7z.log")
                try TestFileGenerator.createRealisticLogFile(at: logFileURL, linesCount: 100000)
            },
            block: { sandbox in
                let inputFile = sandbox.fileURL(named: "large_comp_7z.log").path
                let outArchive = sandbox.fileURL(named: "large_comp.7z").path
                let writer = ArchiveWriter()
                try await writer.createArchive(
                    outputPath: outArchive,
                    format: .sevenZip,
                    level: .normal,
                    inputPaths: [inputFile]
                )
                XCTAssertTrue(FileManager.default.fileExists(atPath: outArchive))
            }
        )
        XCTAssertGreaterThan(metrics.throughputMBs, 2.0)
    }
    
    // MARK: - 3. Large Incompressible Data Scenario
    
    func testZipPerformance_LargeIncompressible() async throws {
        let metrics = try await AsyncBenchmarkRunner.measure(
            name: "Zip Large Incompressible",
            payloadBytes: 20 * 1024 * 1024,
            iterations: TestBenchmarkTier.isBenchmarkMode ? 2 : 1,
            setUp: { sandbox in
                let binFile = sandbox.fileURL(named: "large_incomp.bin").path
                TestFileGenerator.createInstantHugeFile(atPath: binFile, sizeInMB: 20)
            },
            block: { sandbox in
                let inputFile = sandbox.fileURL(named: "large_incomp.bin").path
                let outArchive = sandbox.fileURL(named: "large_incomp.zip").path
                let writer = ArchiveWriter()
                try await writer.createArchive(
                    outputPath: outArchive,
                    format: .zip,
                    level: .store,
                    inputPaths: [inputFile]
                )
                XCTAssertTrue(FileManager.default.fileExists(atPath: outArchive))
            }
        )
        XCTAssertGreaterThan(metrics.throughputMBs, 10.0)
    }
    
    func testSevenZipPerformance_LargeIncompressible() async throws {
        guard SevenZipBinaryResolver.resolveBinaryPath() != nil else { throw XCTSkip() }
        
        let metrics = try await AsyncBenchmarkRunner.measure(
            name: "7Z Large Incompressible",
            payloadBytes: 20 * 1024 * 1024,
            iterations: TestBenchmarkTier.isBenchmarkMode ? 2 : 1,
            setUp: { sandbox in
                let binFile = sandbox.fileURL(named: "large_incomp_7z.bin").path
                TestFileGenerator.createInstantHugeFile(atPath: binFile, sizeInMB: 20)
            },
            block: { sandbox in
                let inputFile = sandbox.fileURL(named: "large_incomp_7z.bin").path
                let outArchive = sandbox.fileURL(named: "large_incomp.7z").path
                let writer = ArchiveWriter()
                try await writer.createArchive(
                    outputPath: outArchive,
                    format: .sevenZip,
                    level: .store,
                    inputPaths: [inputFile]
                )
                XCTAssertTrue(FileManager.default.fileExists(atPath: outArchive))
            }
        )
        XCTAssertGreaterThan(metrics.throughputMBs, 5.0)
    }
}
