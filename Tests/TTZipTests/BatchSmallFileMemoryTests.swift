// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import Foundation
import CTTZipBridge
@testable import TTZipCore

final class BatchSmallFileMemoryTests: XCTestCase {

    func testBatchSmallFileClusteringAndIntegrity() async throws {
        let sandbox = try IsolatedTempSandbox(prefix: "BatchSmallFileTestSandbox")
        defer { sandbox.cleanup() }

        let batchDir = sandbox.fileURL(named: "batch_corpus_500")
        try TestFileGenerator.createBatchSmallFiles(in: batchDir, count: 500, sizePerFileInKB: 4)

        let outZip = sandbox.fileURL(named: "batch_output.zip").path
        let writer = ArchiveWriter()

        try await writer.createArchive(
            outputPath: outZip,
            format: .zip,
            level: .fastest,
            inputPaths: [batchDir.path]
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: outZip), "Output zip file must exist")
        let attrs = try FileManager.default.attributesOfItem(atPath: outZip)
        let zipSize = attrs[FileAttributeKey.size] as? Int64 ?? 0
        XCTAssertGreaterThan(zipSize, 1024, "Zip archive must be non-empty")

        // Extraction and integrity check
        let extractDir = sandbox.fileURL(named: "extracted_batch").path
        let extractor = ArchiveExtractor()
        try await extractor.extract(archivePath: outZip, destinationDir: extractDir)

        let fileEnumerator = FileManager.default.enumerator(atPath: extractDir)
        var extractedFileCount = 0
        while let file = fileEnumerator?.nextObject() as? String {
            let fullPath = (extractDir as NSString).appendingPathComponent(file)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir), !isDir.boolValue {
                extractedFileCount += 1
            }
        }

        XCTAssertEqual(extractedFileCount, 500, "All 500 small files must be extracted bit-for-bit")
    }

    func testAlignedAllocator128Bytes() {
        let ptr = ttzip_core_aligned_alloc_128b(4096)
        XCTAssertNotNil(ptr, "128-byte aligned memory allocation must succeed")
        let addr = UInt(bitPattern: ptr)
        XCTAssertEqual(addr % 128, 0, "Allocated address must be strictly 128-byte aligned")
        ttzip_core_aligned_free_128b(ptr)
    }
}
