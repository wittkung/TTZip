// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class CompetitorGapModelTests: XCTestCase {
    
    // MARK: - HardwareBenchmarkMetric Tests
    
    func testHardwareBenchmarkMetricSerialization() throws {
        let metric = HardwareBenchmarkMetric(
            dictionarySizeMB: 64,
            threadCount: 16,
            compressMIPS: 14500.5,
            decompressMIPS: 22800.0,
            totalMIPS: 18650.25,
            compressSpeedMBs: 1850.4,
            decompressSpeedMBs: 3200.8,
            cpuUsagePercent: 1580.0,
            ratingPerUsageMIPS: 11.80
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(metric)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(HardwareBenchmarkMetric.self, from: data)
        
        XCTAssertEqual(metric, decoded)
        XCTAssertEqual(decoded.dictionarySizeMB, 64)
        XCTAssertEqual(decoded.threadCount, 16)
        XCTAssertEqual(decoded.compressMIPS, 14500.5, accuracy: 0.001)
        XCTAssertEqual(decoded.decompressMIPS, 22800.0, accuracy: 0.001)
        XCTAssertEqual(decoded.totalMIPS, 18650.25, accuracy: 0.001)
        XCTAssertEqual(decoded.compressSpeedMBs, 1850.4, accuracy: 0.001)
        XCTAssertEqual(decoded.decompressSpeedMBs, 3200.8, accuracy: 0.001)
        XCTAssertEqual(decoded.cpuUsagePercent, 1580.0, accuracy: 0.001)
        XCTAssertEqual(decoded.ratingPerUsageMIPS, 11.80, accuracy: 0.001)
    }
    
    // MARK: - SplitVolumeConfig Tests
    
    func testSplitVolumeConfigSerialization() throws {
        for preset in VolumePreset.allCases {
            let config = SplitVolumeConfig(
                volumeSizeBytes: 700 * 1024 * 1024,
                preset: preset,
                namingPattern: .numberedExtension,
                cleanOnFailure: true
            )
            
            let data = try JSONEncoder().encode(config)
            let decoded = try JSONDecoder().decode(SplitVolumeConfig.self, from: data)
            XCTAssertEqual(config, decoded)
            XCTAssertEqual(decoded.preset, preset)
        }
        
        for pattern in VolumeNamingPattern.allCases {
            let config = SplitVolumeConfig(
                volumeSizeBytes: 100 * 1024 * 1024,
                preset: .custom,
                namingPattern: pattern,
                cleanOnFailure: false
            )
            let data = try JSONEncoder().encode(config)
            let decoded = try JSONDecoder().decode(SplitVolumeConfig.self, from: data)
            XCTAssertEqual(config, decoded)
            XCTAssertEqual(decoded.namingPattern, pattern)
            XCTAssertFalse(decoded.cleanOnFailure)
        }
    }
    
    // MARK: - RecoveryRecordPayload Tests
    
    func testRecoveryRecordPayloadSerialization() throws {
        let payload = RecoveryRecordPayload(
            recoveryPercent: 5.0,
            sliceSizeBytes: 65536,
            dataSlicesCount: 100,
            paritySlicesCount: 5,
            protectedPayloadLength: 6553600,
            rootChecksum: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
            eccAlgorithm: "cauchy_rs_gf16"
        )
        
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(RecoveryRecordPayload.self, from: data)
        
        XCTAssertEqual(payload, decoded)
        XCTAssertEqual(decoded.recoveryPercent, 5.0, accuracy: 0.0001)
        XCTAssertEqual(decoded.sliceSizeBytes, 65536)
        XCTAssertEqual(decoded.dataSlicesCount, 100)
        XCTAssertEqual(decoded.paritySlicesCount, 5)
        XCTAssertEqual(decoded.protectedPayloadLength, 6553600)
        XCTAssertEqual(decoded.rootChecksum, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        XCTAssertEqual(decoded.eccAlgorithm, "cauchy_rs_gf16")
    }
}
