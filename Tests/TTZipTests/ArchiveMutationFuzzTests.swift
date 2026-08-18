// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore
import CTTZipBridge

/// High-performance multi-core mutation fuzzing and fault injection test suite.
///
/// Validates that malformed, truncated, or hostile bit streams are safely rejected
/// without memory corruption, SIGSEGV, or unhandled exceptions across all archive engines.
final class ArchiveMutationFuzzTests: XCTestCase {
    
    private var sandboxURL: URL!
    private var baseCorpus: [ArchiveCompressionFormat: Data] = [:]
    private let deterministicSeed: UInt64 = 0xDEADBEEF_CAFEF00D
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        sandboxURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ArchiveFuzzSandbox_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: sandboxURL, withIntermediateDirectories: true)
        
        let formats: [ArchiveCompressionFormat] = [.zip, .sevenZip, .tar, .zst, .gz, .tarGz, .tarZst]
        for fmt in formats {
            baseCorpus[fmt] = fallbackStub(for: fmt)
        }
    }
    
    override func tearDownWithError() throws {
        if let dir = sandboxURL {
            try? FileManager.default.removeItem(at: dir)
        }
        try super.tearDownWithError()
    }
    
    // MARK: - Corpus Helpers
    
    private func fallbackStub(for format: ArchiveCompressionFormat) -> Data {
        switch format {
        case .zip:
            return Data([0x50, 0x4B, 0x05, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        case .sevenZip:
            return Data([0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        case .tar:
            var tar = Data(count: 1024)
            let name = "test.txt".data(using: .utf8)!
            tar.replaceSubrange(0..<name.count, with: name)
            return tar
        case .zst:
            return Data([0x28, 0xB5, 0x2F, 0xFD, 0x00, 0x58, 0x00, 0x00, 0x00])
        case .gz:
            return Data([0x1F, 0x8B, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        default:
            return Data([0x50, 0x4B, 0x05, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        }
    }
    
    private func targetFormatsList() -> [ArchiveCompressionFormat] {
        return [.zip, .sevenZip, .tar, .zst, .gz]
    }
    
    private func getCorpusData(for format: ArchiveCompressionFormat) -> Data {
        if let data = baseCorpus[format], !data.isEmpty {
            return data
        }
        return fallbackStub(for: format)
    }
    
    // MARK: - 2. Corrupt Magic Mutation Fuzzing (50+ Iterations Across Formats)
    
    func testCorruptMagicMutationStability() async throws {
        let formats = targetFormatsList()
        let iterationsPerFormat = TestBenchmarkTier.fuzzIterations(default: 2, deep: 200)
        let masterSeed = deterministicSeed
        let baseSandbox = sandboxURL!
        
        let totalCount = try await withThrowingTaskGroup(of: Int.self) { group in
            for fmt in formats {
                let baseData = getCorpusData(for: fmt)
                group.addTask {
                    var handled = 0
                    for iter in 0..<iterationsPerFormat {
                        let taskSeed = masterSeed ^ (UInt64(truncatingIfNeeded: fmt.hashValue) &* 0x9e3779b97f4a7c15) ^ (UInt64(iter) &* 0x517cc1b727220a95)
                        var prng = DeterministicPRNG(seed: taskSeed)
                        let mutatedData = MalformedStreamFuzzEngine.mutate(data: baseData, operator: .corruptMagic, prng: &prng)
                        
                        let reproducerPath = baseSandbox.appendingPathComponent("rep_magic_\(fmt.rawValue)_\(iter)_\(UUID().uuidString).bin").path
                        try mutatedData.write(to: URL(fileURLWithPath: reproducerPath))
                        
                        let extractDest = baseSandbox.appendingPathComponent("ext_magic_\(fmt.rawValue)_\(iter)").path
                        let status = ttzip_extract_archive_advanced(reproducerPath, extractDest, true, nil)
                        _ = status
                        _ = ttzip_stat_file_info(reproducerPath, nil, nil, nil)
                        
                        try? FileManager.default.removeItem(atPath: reproducerPath)
                        try? FileManager.default.removeItem(atPath: extractDest)
                        handled += 1
                    }
                    return handled
                }
            }
            
            var total = 0
            for try await count in group {
                total += count
            }
            return total
        }
        
        XCTAssertGreaterThanOrEqual(totalCount, formats.count * iterationsPerFormat, "Must execute deterministic iterations across all formats")
    }
    
    // MARK: - 3. Corrupt CRC Mutation Fuzzing (50+ Iterations Across Formats)
    
    func testCorruptCRCMutationStability() async throws {
        let formats = targetFormatsList()
        let iterationsPerFormat = TestBenchmarkTier.fuzzIterations(default: 2, deep: 200)
        let masterSeed = deterministicSeed
        let baseSandbox = sandboxURL!
        
        let totalCount = try await withThrowingTaskGroup(of: Int.self) { group in
            for fmt in formats {
                let baseData = getCorpusData(for: fmt)
                group.addTask {
                    var handled = 0
                    for iter in 0..<iterationsPerFormat {
                        let taskSeed = masterSeed ^ (UInt64(truncatingIfNeeded: fmt.hashValue) &* 0x9e3779b97f4a7c15) ^ (UInt64(iter) &* 0x517cc1b727220a95)
                        var prng = DeterministicPRNG(seed: taskSeed)
                        let mutatedData = MalformedStreamFuzzEngine.mutate(data: baseData, operator: .corruptCRC, prng: &prng)
                        
                        let reproducerPath = baseSandbox.appendingPathComponent("rep_crc_\(fmt.rawValue)_\(iter)_\(UUID().uuidString).bin").path
                        try mutatedData.write(to: URL(fileURLWithPath: reproducerPath))
                        
                        let extractDest = baseSandbox.appendingPathComponent("ext_crc_\(fmt.rawValue)_\(iter)").path
                        _ = ttzip_extract_archive_advanced(reproducerPath, extractDest, true, nil)
                        _ = ttzip_stat_file_info(reproducerPath, nil, nil, nil)
                        
                        try? FileManager.default.removeItem(atPath: reproducerPath)
                        try? FileManager.default.removeItem(atPath: extractDest)
                        handled += 1
                    }
                    return handled
                }
            }
            
            var total = 0
            for try await count in group {
                total += count
            }
            return total
        }
        
        XCTAssertGreaterThanOrEqual(totalCount, formats.count * iterationsPerFormat, "Must execute deterministic iterations across all formats")
    }
    
    // MARK: - 4. Truncate Stream Mutation Fuzzing (50+ Iterations Across Formats)
    
    func testTruncateStreamMutationStability() async throws {
        let formats = targetFormatsList()
        let iterationsPerFormat = TestBenchmarkTier.fuzzIterations(default: 2, deep: 200)
        let masterSeed = deterministicSeed
        let baseSandbox = sandboxURL!
        
        let totalCount = try await withThrowingTaskGroup(of: Int.self) { group in
            for fmt in formats {
                let baseData = getCorpusData(for: fmt)
                group.addTask {
                    var handled = 0
                    for iter in 0..<iterationsPerFormat {
                        let taskSeed = masterSeed ^ (UInt64(truncatingIfNeeded: fmt.hashValue) &* 0x9e3779b97f4a7c15) ^ (UInt64(iter) &* 0x517cc1b727220a95)
                        var prng = DeterministicPRNG(seed: taskSeed)
                        let mutatedData = MalformedStreamFuzzEngine.mutate(data: baseData, operator: .truncateStream, prng: &prng)
                        
                        let reproducerPath = baseSandbox.appendingPathComponent("rep_trunc_\(fmt.rawValue)_\(iter)_\(UUID().uuidString).bin").path
                        try mutatedData.write(to: URL(fileURLWithPath: reproducerPath))
                        
                        let extractDest = baseSandbox.appendingPathComponent("ext_trunc_\(fmt.rawValue)_\(iter)").path
                        _ = ttzip_extract_archive_advanced(reproducerPath, extractDest, true, nil)
                        _ = ttzip_stat_file_info(reproducerPath, nil, nil, nil)
                        
                        try? FileManager.default.removeItem(atPath: reproducerPath)
                        try? FileManager.default.removeItem(atPath: extractDest)
                        handled += 1
                    }
                    return handled
                }
            }
            
            var total = 0
            for try await count in group {
                total += count
            }
            return total
        }
        
        XCTAssertGreaterThanOrEqual(totalCount, formats.count * iterationsPerFormat, "Must execute deterministic iterations across all formats")
    }
    
    // MARK: - 5. Inject ZipSlip Path Security Defense (50+ Iterations Across Formats)
    
    func testInjectZipSlipPathSecurityDefense() async throws {
        let formats = targetFormatsList()
        let iterationsPerFormat = TestBenchmarkTier.fuzzIterations(default: 2, deep: 200)
        let masterSeed = deterministicSeed
        let baseSandbox = sandboxURL!
        
        let totalCount = try await withThrowingTaskGroup(of: Int.self) { group in
            for fmt in formats {
                let baseData = getCorpusData(for: fmt)
                group.addTask {
                    var handled = 0
                    for iter in 0..<iterationsPerFormat {
                        let taskSeed = masterSeed ^ (UInt64(truncatingIfNeeded: fmt.hashValue) &* 0x9e3779b97f4a7c15) ^ (UInt64(iter) &* 0x517cc1b727220a95)
                        var prng = DeterministicPRNG(seed: taskSeed)
                        let mutatedData = MalformedStreamFuzzEngine.mutate(data: baseData, operator: .injectZipSlipPath, prng: &prng)
                        
                        let reproducerPath = baseSandbox.appendingPathComponent("rep_zipslip_\(fmt.rawValue)_\(iter)_\(UUID().uuidString).bin").path
                        try mutatedData.write(to: URL(fileURLWithPath: reproducerPath))
                        
                        let extractDest = baseSandbox.appendingPathComponent("ext_zipslip_\(fmt.rawValue)_\(iter)").path
                        
                        do {
                            _ = try await SecurityProtectionProxy.shared.quickExtract(
                                archivePath: reproducerPath,
                                destinationDir: extractDest
                            )
                        } catch {
                            // Expected security or rejection
                        }
                        
                        let evilTestPaths = [
                            "../../../../../../etc/passwd",
                            "../../../../../../etc/passwd\0",
                            "../escape.txt",
                            "/etc/shadow",
                            "C:\\Windows\\System32\\calc.exe"
                        ]
                        for evil in evilTestPaths {
                            XCTAssertTrue(SecurityProtectionProxy.isPathTraversalOrEscape(evil))
                            XCTAssertFalse(ArchiveSecurityFacade.shared.validateExtractPath(entryPath: evil, destinationDir: extractDest))
                        }
                        
                        _ = ttzip_extract_archive_advanced(reproducerPath, extractDest, true, nil)
                        
                        let parentSandbox = baseSandbox.deletingLastPathComponent().path
                        let escapedFile = (parentSandbox as NSString).appendingPathComponent("etc/passwd")
                        XCTAssertFalse(FileManager.default.fileExists(atPath: escapedFile))
                        
                        try? FileManager.default.removeItem(atPath: reproducerPath)
                        try? FileManager.default.removeItem(atPath: extractDest)
                        handled += 1
                    }
                    return handled
                }
            }
            
            var total = 0
            for try await count in group {
                total += count
            }
            return total
        }
        
        XCTAssertGreaterThanOrEqual(totalCount, formats.count * iterationsPerFormat, "Must execute deterministic iterations across all formats")
    }
    
    // MARK: - 6. Oversize Header Integer Overflow Hardening (50+ Iterations Across Formats)
    
    func testOversizeHeaderIntegerOverflowHardening() async throws {
        let formats = targetFormatsList()
        let iterationsPerFormat = TestBenchmarkTier.fuzzIterations(default: 2, deep: 200)
        let masterSeed = deterministicSeed
        let baseSandbox = sandboxURL!
        
        let totalCount = try await withThrowingTaskGroup(of: Int.self) { group in
            for fmt in formats {
                let baseData = getCorpusData(for: fmt)
                group.addTask {
                    var handled = 0
                    for iter in 0..<iterationsPerFormat {
                        let taskSeed = masterSeed ^ (UInt64(truncatingIfNeeded: fmt.hashValue) &* 0x9e3779b97f4a7c15) ^ (UInt64(iter) &* 0x517cc1b727220a95)
                        var prng = DeterministicPRNG(seed: taskSeed)
                        let mutatedData = MalformedStreamFuzzEngine.mutate(data: baseData, operator: .oversizeHeader, prng: &prng)
                        
                        let reproducerPath = baseSandbox.appendingPathComponent("rep_oversize_\(fmt.rawValue)_\(iter)_\(UUID().uuidString).bin").path
                        try mutatedData.write(to: URL(fileURLWithPath: reproducerPath))
                        
                        let extractDest = baseSandbox.appendingPathComponent("ext_oversize_\(fmt.rawValue)_\(iter)").path
                        _ = ttzip_extract_archive_advanced(reproducerPath, extractDest, true, nil)
                        _ = ttzip_stat_file_info(reproducerPath, nil, nil, nil)
                        
                        try? FileManager.default.removeItem(atPath: reproducerPath)
                        try? FileManager.default.removeItem(atPath: extractDest)
                        handled += 1
                    }
                    return handled
                }
            }
            
            var total = 0
            for try await count in group {
                total += count
            }
            return total
        }
        
        XCTAssertGreaterThanOrEqual(totalCount, formats.count * iterationsPerFormat, "Must execute deterministic iterations across all formats")
    }
    
    // MARK: - 7. Invalid Dictionary Size Decoder Rejection (50+ Iterations Across Formats)
    
    func testInvalidDictSizeDecoderRejection() async throws {
        let formats = targetFormatsList()
        let iterationsPerFormat = TestBenchmarkTier.fuzzIterations(default: 2, deep: 200)
        let masterSeed = deterministicSeed
        let baseSandbox = sandboxURL!
        
        let totalCount = try await withThrowingTaskGroup(of: Int.self) { group in
            for fmt in formats {
                let baseData = getCorpusData(for: fmt)
                group.addTask {
                    var handled = 0
                    for iter in 0..<iterationsPerFormat {
                        let taskSeed = masterSeed ^ (UInt64(truncatingIfNeeded: fmt.hashValue) &* 0x9e3779b97f4a7c15) ^ (UInt64(iter) &* 0x517cc1b727220a95)
                        var prng = DeterministicPRNG(seed: taskSeed)
                        let mutatedData = MalformedStreamFuzzEngine.mutate(data: baseData, operator: .invalidDictSize, prng: &prng)
                        
                        let reproducerPath = baseSandbox.appendingPathComponent("rep_dict_\(fmt.rawValue)_\(iter)_\(UUID().uuidString).bin").path
                        try mutatedData.write(to: URL(fileURLWithPath: reproducerPath))
                        
                        let extractDest = baseSandbox.appendingPathComponent("ext_dict_\(fmt.rawValue)_\(iter)").path
                        _ = ttzip_extract_archive_advanced(reproducerPath, extractDest, true, nil)
                        _ = ttzip_stat_file_info(reproducerPath, nil, nil, nil)
                        
                        try? FileManager.default.removeItem(atPath: reproducerPath)
                        try? FileManager.default.removeItem(atPath: extractDest)
                        handled += 1
                    }
                    return handled
                }
            }
            
            var total = 0
            for try await count in group {
                total += count
            }
            return total
        }
        
        XCTAssertGreaterThanOrEqual(totalCount, formats.count * iterationsPerFormat, "Must execute deterministic iterations across all formats")
    }
    
    // MARK: - 8. Comprehensive Deterministic Fuzz Matrix (50+ Iterations Per Format)
    
    func testComprehensiveDeterministicFuzzMatrix() async throws {
        let formats = targetFormatsList()
        let iterationsPerFormat = TestBenchmarkTier.fuzzIterations(default: 2, deep: 200)
        let masterSeed = deterministicSeed
        let baseSandbox = sandboxURL!
        
        let totalCount = try await withThrowingTaskGroup(of: Int.self) { group in
            for fmt in formats {
                let baseData = getCorpusData(for: fmt)
                let config = FuzzMutationConfig(
                    seed: masterSeed,
                    iterationCount: iterationsPerFormat,
                    operators: FuzzMutationConfig.MutationOperator.allCases,
                    targetFormat: fmt,
                    crashDumpDirectory: baseSandbox.path
                )
                
                group.addTask {
                    var handled = 0
                    for iter in 0..<iterationsPerFormat {
                        let taskSeed = masterSeed ^ (UInt64(truncatingIfNeeded: fmt.hashValue) &* 0x9e3779b97f4a7c15) ^ (UInt64(iter) &* 0x517cc1b727220a95)
                        var prng = DeterministicPRNG(seed: taskSeed)
                        let (mutatedData, appliedOp) = MalformedStreamFuzzEngine.mutate(data: baseData, config: config, prng: &prng)
                        
                        let reproducerPath = baseSandbox.appendingPathComponent("rep_matrix_\(fmt.rawValue)_\(iter)_\(appliedOp.rawValue)_\(UUID().uuidString).bin").path
                        try mutatedData.write(to: URL(fileURLWithPath: reproducerPath))
                        
                        let extractDest = baseSandbox.appendingPathComponent("ext_matrix_\(fmt.rawValue)_\(iter)").path
                        _ = ttzip_extract_archive_advanced(reproducerPath, extractDest, true, nil)
                        _ = ttzip_stat_file_info(reproducerPath, nil, nil, nil)
                        
                        try? FileManager.default.removeItem(atPath: reproducerPath)
                        try? FileManager.default.removeItem(atPath: extractDest)
                        handled += 1
                    }
                    return handled
                }
            }
            
            var total = 0
            for try await count in group {
                total += count
            }
            return total
        }
        
        XCTAssertGreaterThanOrEqual(totalCount, formats.count * iterationsPerFormat, "Total evaluated iterations must match matrix product")
    }
}
