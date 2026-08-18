// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class PerformanceRegressionGuardTests: XCTestCase {
    
    struct ScenarioBaselineKey: Hashable {
        let format: ArchiveCompressionFormat
        let level: ArchiveCompressionLevel
        let isEncrypted: Bool
    }
    
    // Historical peak floor tolerance (Debug: 80% adaptation / Release: strictly 90%)
    #if DEBUG
    private static let floorRatio: Double = 0.80
    #else
    private static let floorRatio: Double = 0.90
    #endif
    
    func testTopFormatsDynamicScenarioPerformanceFloor() async throws {
        let sandbox = try IsolatedTempSandbox(prefix: "perf_guard")
        defer { sandbox.cleanup() }
        
        let calibrator = HardwareCalibrator.shared
        let writer = ArchiveWriter()
        
        // 50MB standardized dataset matching HardwareCalibrator baseline
        let dataSize = 50 * 1024 * 1024
        let sampleData = Data(count: dataSize)
        let sampleFile = sandbox.url.appendingPathComponent("bench_payload.bin")
        try sampleData.write(to: sampleFile)
        
        let testScenarios: [ScenarioBaselineKey] = [
            ScenarioBaselineKey(format: .zip, level: .level1, isEncrypted: false),
            ScenarioBaselineKey(format: .zip, level: .level6, isEncrypted: false),
            ScenarioBaselineKey(format: .sevenZip, level: .level1, isEncrypted: false),
            ScenarioBaselineKey(format: .tar, level: .store, isEncrypted: false),
            ScenarioBaselineKey(format: .tarZst, level: .level1, isEncrypted: false),
            ScenarioBaselineKey(format: .tarGz, level: .level6, isEncrypted: false)
        ]
        
        for key in testScenarios {
            let encSuffix = key.isEncrypted ? "_enc" : ""
            let ext: String
            switch key.format {
            case .sevenZip: ext = "7z"
            case .zip: ext = "zip"
            case .tar: ext = "tar"
            case .tarZst, .zst: ext = "tar.zst"
            case .tarGz, .gz: ext = "tar.gz"
            case .bz2, .tarBz2: ext = "tar.bz2"
            default: ext = key.format.rawValue
            }
            
            let outPath = sandbox.fileURL(named: "test_\(ext)_L\(key.level.rawValue)\(encSuffix).\(ext)").path
            let pwd = key.isEncrypted ? "P@ssw0rd2026!" : nil
            
            let clock = ContinuousClock()
            let elapsed = try await clock.measure {
                try await writer.createArchive(
                    outputPath: outPath,
                    format: key.format,
                    level: key.level,
                    inputPaths: [sampleFile.path],
                    password: pwd
                )
            }
            
            let seconds = max(0.001, Double(elapsed.components.seconds) + (Double(elapsed.components.attoseconds) / 1e18))
            let currentMBs = (Double(dataSize) / (1024.0 * 1024.0)) / seconds
            
            if let localPeak = calibrator.localPeakThroughput(format: key.format, level: key.level, isEncrypted: key.isEncrypted) {
                let minAllowedMBs = localPeak * Self.floorRatio
                
                XCTAssertGreaterThanOrEqual(
                    currentMBs,
                    minAllowedMBs,
                    "🚨 [Performance Regression Warning] Scenario [\(key.format.rawValue.uppercased()) | Level: \(key.level.rawValue) | Encrypted: \(key.isEncrypted)] current throughput (\(String(format: "%.1f", currentMBs)) MB/s) dropped below local historical peak (\(String(format: "%.1f", localPeak)) MB/s) floor threshold (\(String(format: "%.1f", minAllowedMBs)) MB/s)!"
                )
            }
            
            calibrator.recordLocalPeak(format: key.format, level: key.level, isEncrypted: key.isEncrypted, compressMBs: currentMBs)
        }
    }
}
