// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class ReedSolomonRecoveryRecordTests: XCTestCase {
    private var tempDirectoryURL: URL!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent("TTZip_FECTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        if let url = tempDirectoryURL {
            try? FileManager.default.removeItem(at: url)
        }
        try super.tearDownWithError()
    }
    
    func testReedSolomonEncodeAndDecodeExactReconstruction() {
        let sliceSize = 1024
        let K = 8
        let M = 2
        
        var dataSlices = [Data]()
        for i in 0..<K {
            let slice = Data((0..<sliceSize).map { UInt8(($0 + i * 37) & 0xFF) })
            dataSlices.append(slice)
        }
        
        let parities = ReedSolomonFEC.encode(dataSlices: dataSlices, parityCount: M)
        XCTAssertEqual(parities.count, M)
        
        // Simulate corruption: drop slices 2 and 5
        var intactSlices = [Int: Data]()
        for i in 0..<K {
            if i != 2 && i != 5 {
                intactSlices[i] = dataSlices[i]
            }
        }
        // Add both parities
        intactSlices[K + 0] = parities[0]
        intactSlices[K + 1] = parities[1]
        
        let reconstructed = ReedSolomonFEC.decode(
            intactSlices: intactSlices,
            totalK: K,
            totalM: M,
            sliceSize: sliceSize
        )
        
        XCTAssertNotNil(reconstructed)
        XCTAssertEqual(reconstructed?[2], dataSlices[2])
        XCTAssertEqual(reconstructed?[5], dataSlices[5])
    }
    
    func testRecoveryRecordInjectionAndSelfHealing() throws {
        let testFile = tempDirectoryURL.appendingPathComponent("archive_fec.tar").path
        let sampleContent = Data((0..<(64 * 1024)).map { UInt8($0 & 0xFF) })
        try sampleContent.write(to: URL(fileURLWithPath: testFile))
        
        let engine = ArchiveRecoveryRecordEngine.shared
        let payload = try engine.appendRecoveryRecord(to: testFile, redundancyPercent: 10.0, sliceSize: 8192)
        
        XCTAssertEqual(payload.dataSlicesCount, 8)
        XCTAssertEqual(payload.paritySlicesCount, 1)
        
        // Verify inspection
        let inspected = engine.inspectRecoveryRecord(archivePath: testFile)
        XCTAssertNotNil(inspected)
        XCTAssertEqual(inspected?.protectedPayloadLength, Int64(sampleContent.count))
        
        // Corrupt 512 bytes in slice 3
        var fileData = try Data(contentsOf: URL(fileURLWithPath: testFile))
        let corruptOffset = 3 * 8192 + 100
        for i in 0..<512 {
            fileData[corruptOffset + i] ^= 0xFF
        }
        try fileData.write(to: URL(fileURLWithPath: testFile))
        
        // Perform self-healing
        let success = try engine.repairArchive(archivePath: testFile)
        XCTAssertTrue(success)
        
        let restoredData = try Data(contentsOf: URL(fileURLWithPath: testFile))
        let restoredPayload = Data(restoredData.prefix(sampleContent.count))
        XCTAssertEqual(restoredPayload, sampleContent)
    }
}
