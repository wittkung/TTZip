// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import CTTZipBridge
@testable import TTZipCore

/// HyperCompressBench fast-path performance floor gates (500+ files >= 50 MB/s Debug / >= 70 MB/s Release).
final class HyperCompressBatchGateTests: XCTestCase {
    
    // MARK: - 1. ZIP Fast-Path
    
    func testHyperCompressBatchZipFastPathGate() async throws {
        let generator = HyperCompressCorpusGenerator(profile: .standardCiGate)
        let generated = try generator.writeToTemporaryDirectory()
        defer { generated.cleanup() }
        
        let totalBytes = Int64(generated.items.reduce(0) { $0 + $1.byteLength })
        
        let metrics = try await AsyncBenchmarkRunner.measure(
            name: "HyperCompress ZIP Batch (500 Files)",
            payloadBytes: totalBytes,
            iterations: TestBenchmarkTier.isBenchmarkMode ? 2 : 1,
            setUp: { _ in },
            block: { sandbox in
                let outArchive = sandbox.fileURL(named: "hypercompress_batch.zip").path
                let writer = ArchiveWriter()
                try await writer.createArchive(
                    outputPath: outArchive,
                    format: .zip,
                    level: .fastest,
                    inputPaths: [generated.rootURL.path]
                )
                XCTAssertTrue(FileManager.default.fileExists(atPath: outArchive))
            }
        )
        
        #if DEBUG
        XCTAssertGreaterThanOrEqual(metrics.throughputMBs, 50.0, "HyperCompress ZIP 500 small files batch throughput must be >= 50.0 MB/s (Debug gate)")
        #else
        XCTAssertGreaterThanOrEqual(metrics.throughputMBs, 70.0, "HyperCompress ZIP 500 small files batch throughput must be >= 70.0 MB/s (Release gate)")
        #endif
    }
    
    // MARK: - 2. TAR.ZST Fast-Path
    
    func testHyperCompressBatchTarZstFastPathGate() async throws {
        let generator = HyperCompressCorpusGenerator(profile: .standardCiGate)
        let generated = try generator.writeToTemporaryDirectory()
        defer { generated.cleanup() }
        
        let totalBytes = Int64(generated.items.reduce(0) { $0 + $1.byteLength })
        
        let metrics = try await AsyncBenchmarkRunner.measure(
            name: "HyperCompress TAR.ZST Batch (500 Files)",
            payloadBytes: totalBytes,
            iterations: TestBenchmarkTier.isBenchmarkMode ? 2 : 1,
            setUp: { _ in },
            block: { sandbox in
                let outArchive = sandbox.fileURL(named: "hypercompress_batch.tar.zst").path
                let writer = ArchiveWriter()
                try await writer.createArchive(
                    outputPath: outArchive,
                    format: .tarZst,
                    level: .level1,
                    inputPaths: [generated.rootURL.path]
                )
                XCTAssertTrue(FileManager.default.fileExists(atPath: outArchive))
            }
        )
        
        #if DEBUG
        XCTAssertGreaterThanOrEqual(metrics.throughputMBs, 50.0, "HyperCompress TAR.ZST 500 small files batch throughput must be >= 50.0 MB/s (Debug gate)")
        #else
        XCTAssertGreaterThanOrEqual(metrics.throughputMBs, 70.0, "HyperCompress TAR.ZST 500 small files batch throughput must be >= 70.0 MB/s (Release gate)")
        #endif
    }
    
    // MARK: - 3. 7Z Fast-Path
    
    func testHyperCompressBatch7zFastPathGate() async throws {
        let generator = HyperCompressCorpusGenerator(profile: .standardCiGate)
        let generated = try generator.writeToTemporaryDirectory()
        defer { generated.cleanup() }
        
        let totalBytes = Int64(generated.items.reduce(0) { $0 + $1.byteLength })
        
        let metrics = try await AsyncBenchmarkRunner.measure(
            name: "HyperCompress 7Z Batch (500 Files)",
            payloadBytes: totalBytes,
            iterations: TestBenchmarkTier.isBenchmarkMode ? 2 : 1,
            setUp: { _ in },
            block: { sandbox in
                let outArchive = sandbox.fileURL(named: "hypercompress_batch.7z").path
                let writer = ArchiveWriter()
                try await writer.createArchive(
                    outputPath: outArchive,
                    format: .sevenZip,
                    level: .fastest,
                    inputPaths: [generated.rootURL.path]
                )
                XCTAssertTrue(FileManager.default.fileExists(atPath: outArchive))
            }
        )
        
        #if DEBUG
        XCTAssertGreaterThanOrEqual(metrics.throughputMBs, 50.0, "HyperCompress 7Z 500 small files batch throughput must be >= 50.0 MB/s (Debug gate)")
        #else
        XCTAssertGreaterThanOrEqual(metrics.throughputMBs, 70.0, "HyperCompress 7Z 500 small files batch throughput must be >= 70.0 MB/s (Release gate)")
        #endif
    }
}
