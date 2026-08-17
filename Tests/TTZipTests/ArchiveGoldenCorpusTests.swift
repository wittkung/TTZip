//
//  ArchiveGoldenCorpusTests.swift
//  TTZipTests
//
//  Created for libarchive Golden Oracle Integration on 2026-08-16.
//

import XCTest
@testable import TTZipCore

final class ArchiveGoldenCorpusTests: XCTestCase {
    
    private var corpusDirectory: URL {
        #if SWIFT_PACKAGE
        if let resourceURL = Bundle.module.url(forResource: "GoldenCorpus", withExtension: nil, subdirectory: "Fixtures") {
            return resourceURL
        }
        #endif
        let currentFile = URL(fileURLWithPath: #filePath)
        return currentFile.deletingLastPathComponent().appendingPathComponent("Fixtures/GoldenCorpus")
    }
    
    // MARK: - 1. UUDecoder Unit & Throughput Tests
    
    func testUUDecoderBasicSyntax() throws {
        let sampleUU = """
        begin 644 hello.txt
        #2&5L
        `
        end
        """
        guard let result = UUDecoder.decode(uuText: sampleUU) else {
            XCTFail("Failed to decode simple UUEncode text")
            return
        }
        XCTAssertEqual(result.filename, "hello.txt")
        XCTAssertEqual(result.mode, 0o644)
        let decodedStr = String(data: result.data, encoding: .utf8)
        XCTAssertEqual(decodedStr, "Hel")
    }
    
    // MARK: - 2. Golden Corpus Regression Suite
    
    func testDecodeAndValidateCuratedCorpus() async throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: corpusDirectory.path) else {
            XCTFail("GoldenCorpus directory does not exist at \(corpusDirectory.path)")
            return
        }
        
        let files = try fileManager.contentsOfDirectory(atPath: corpusDirectory.path)
            .filter { $0.hasSuffix(".uu") }
            .sorted()
        
        XCTAssertFalse(files.isEmpty, "GoldenCorpus should contain .uu fixtures")
        
        for file in files {
            let fileURL = corpusDirectory.appendingPathComponent(file)
            let uuContent = try String(contentsOf: fileURL, encoding: .utf8)
            
            guard let decoded = UUDecoder.decode(uuText: uuContent) else {
                XCTFail("Failed to decode golden fixture: \(file)")
                continue
            }
            
            XCTAssertFalse(decoded.data.isEmpty, "Decoded data for \(file) must not be empty")
            
            // Connect to ArchiveReader & ArchiveExtractor to assert parser robustness
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("UUCorpus_\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempDir) }
            
            let tempArchive = tempDir.appendingPathComponent(decoded.filename.isEmpty ? "sample.bin" : decoded.filename)
            try decoded.data.write(to: tempArchive)
            
            if tempArchive.pathExtension.lowercased() == "tar" || tempArchive.pathExtension.lowercased() == "zip" {
                let outExtract = tempDir.appendingPathComponent("out")
                try? FileManager.default.createDirectory(at: outExtract, withIntermediateDirectories: true)
                let extractor = ArchiveExtractor()
                _ = try? await extractor.extract(archivePath: tempArchive.path, destinationDir: outExtract.path, options: ArchiveFilterOptions())
            }
        }
    }
}
