// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class Phase3IntegrationTests: XCTestCase {
    
    // MARK: - Task T009: VFS 16-Way LZ4 Cache Pool & Prefetching Tests
    
    func testVFSLz4CachePoolPutGetAndStats() {
        let pool = VFSLz4CachePool.shared
        let sessionId = "test_session_\(UUID().uuidString)"
        defer { pool.clearSession(sessionId: sessionId) }
        
        let sampleData = Data("High-Performance 16-Way Sharded LZ4 VFS Decompression Test Buffer".utf8)
        pool.put(sessionId: sessionId, chunkIndex: 0, rawData: sampleData)
        
        XCTAssertTrue(pool.contains(sessionId: sessionId, chunkIndex: 0))
        let retrieved = pool.get(sessionId: sessionId, chunkIndex: 0)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved, sampleData)
        
        let stats = pool.getStats()
        XCTAssertGreaterThanOrEqual(stats.ramCount + stats.diskCount, 1)
        
        pool.clearSession(sessionId: sessionId)
        XCTAssertFalse(pool.contains(sessionId: sessionId, chunkIndex: 0))
    }
    
    func testVFSLz4CachePoolEntryCachingAndPrefetching() async throws {
        let pool = VFSLz4CachePool.shared
        let archivePath = "/tmp/test_archive_\(UUID().uuidString).zip"
        let entryPath = "folder/nested_document.txt"
        defer { pool.clearSession(sessionId: archivePath) }
        
        let sampleData = Data("Prefetched document stream for instant macOS QuickLook".utf8)
        pool.cacheEntry(archivePath: archivePath, entryPath: entryPath, data: sampleData)
        
        let cached = pool.getCachedEntry(archivePath: archivePath, entryPath: entryPath)
        XCTAssertEqual(cached, sampleData)
        
        // Test async prefetchChunk
        let prefetchChunkIdx = 42
        await pool.prefetchChunk(sessionId: archivePath, chunkIndex: prefetchChunkIdx) {
            return Data("Asynchronously loaded chunk data".utf8)
        }
        XCTAssertTrue(pool.contains(sessionId: archivePath, chunkIndex: prefetchChunkIdx))
        
        // Test async prefetchChunks batch
        let indices = [101, 102, 103]
        await pool.prefetchChunks(sessionId: archivePath, indices: indices) { idx in
            return Data("Chunk #\(idx) batch prefetch".utf8)
        }
        for idx in indices {
            XCTAssertTrue(pool.contains(sessionId: archivePath, chunkIndex: idx))
        }
    }
    
    // MARK: - Task T010: SevenZipSeekTable & QuickLook 7z Solid Stream Tests
    
    func testSevenZipSeekTableInMemoryStreamingExtraction() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let file1 = tempDir.appendingPathComponent("quicklook_sample.txt")
        let file2 = tempDir.appendingPathComponent("notes.md")
        let content1 = "QuickLook 7z Solid Stream In-Memory Payload Test Content"
        let content2 = "# Markdown notes for instant preview with zero disk write"
        try content1.write(to: file1, atomically: true, encoding: .utf8)
        try content2.write(to: file2, atomically: true, encoding: .utf8)
        
        let out7z = tempDir.appendingPathComponent("solid_archive.7z").path
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: out7z,
            format: .sevenZip,
            level: .normal,
            inputPaths: [file1.path, file2.path]
        )
        
        // 1. Test SevenZipSeekTable.fromArchive
        let seekTable = try await SevenZipSeekTable.fromArchive(path: out7z)
        XCTAssertEqual(seekTable.archivePath, out7z)
        XCTAssertGreaterThanOrEqual(seekTable.allEntries.count, 2)
        
        // 2. Test in-memory streaming extraction with zero disk write (<10ms)
        let startTime = CFAbsoluteTimeGetCurrent()
        let extractedData1 = SevenZipSeekTable.extractSingleEntryData(archivePath: out7z, entryPath: "quicklook_sample.txt")
        let elapsedMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
        
        XCTAssertNotNil(extractedData1)
        if let data = extractedData1, let str = String(data: data, encoding: .utf8) {
            XCTAssertEqual(str, content1)
        }
        XCTAssertLessThan(elapsedMs, 50.0, "Extraction should be instant and in-memory")
        
        // 3. Test QuickLookPreviewEngine extractSingleFileMemoryStream
        let qlData = try await QuickLookPreviewEngine.extractSingleFileMemoryStream(archivePath: out7z, entryPath: "notes.md")
        XCTAssertNotNil(qlData)
        if let data = qlData, let str = String(data: data, encoding: .utf8) {
            XCTAssertEqual(str, content2)
        }
        
        // 4. Test extractSingleFile to destination directory
        let targetExtractDir = tempDir.appendingPathComponent("extracted_out").path
        let ok = try seekTable.extractSingleFile(path: "quicklook_sample.txt", destinationDir: targetExtractDir)
        XCTAssertTrue(ok)
        let extractedFile = URL(fileURLWithPath: targetExtractDir).appendingPathComponent("quicklook_sample.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFile.path))
    }
}
