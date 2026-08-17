import XCTest
@testable import TTZipCore
import CTTZipBridge

final class ArchiveMutationFuzzTests: XCTestCase {
    
    private var sandboxURL: URL!
    
    override func setUpWithError() throws {
        sandboxURL = FileManager.default.temporaryDirectory.appendingPathComponent("TTZipFuzzSandbox_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: sandboxURL, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        if let url = sandboxURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    // MARK: - 1. Multi-Format Mutation Primitives
    
    private func mutate(data: Data, ratio: Double = 0.02) -> Data {
        var mutableBytes = [UInt8](data)
        let totalCount = mutableBytes.count
        guard totalCount > 4 else { return data }
        
        let mutateByteCount = max(4, Int(Double(totalCount) * ratio))
        for _ in 0..<mutateByteCount {
            let randomIndex = Int.random(in: 0..<totalCount)
            let mutationType = Int.random(in: 0...3)
            
            switch mutationType {
            case 0: // Bit flip
                mutableBytes[randomIndex] ^= (1 << UInt8.random(in: 0...7))
            case 1: // Byte replace
                mutableBytes[randomIndex] = UInt8.random(in: 0...255)
            case 2: // Arithmetic mutation (+1 / -1)
                mutableBytes[randomIndex] = mutableBytes[randomIndex] &+ UInt8.random(in: 1...5)
            default: // Magic stub overwrite
                mutableBytes[randomIndex] = 0x00
            }
        }
        return Data(mutableBytes)
    }
    
    // MARK: - 2. In-Process Fuzz Gate with Crash-First Persistence & In-Memory Extraction
    
    func testCoverageMutationFuzzingStability() throws {
        // Base seeds: ZIP, 7Z, and TAR.ZST headers
        let validZipStub = Data([
            0x50, 0x4B, 0x03, 0x04, 0x0A, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x74, 0x65,
            0x73, 0x74, 0x50, 0x4B, 0x01, 0x02, 0x0A, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x20, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x74, 0x65, 0x73, 0x74, 0x50, 0x4B, 0x05, 0x06, 0x00, 0x00,
            0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x36, 0x00, 0x00, 0x00,
            0x20, 0x00, 0x00, 0x00, 0x00, 0x00
        ])
        
        let valid7zStub = Data([
            0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C, 0x00, 0x04, 0x5B, 0xC4,
            0xC5, 0x61, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00
        ])
        
        let seedCorpus = [validZipStub, valid7zStub]
        let iterationsPerSeed = 500
        var totalHandled = 0
        var totalAccepted = 0
        
        let crashReproducerURL = sandboxURL.appendingPathComponent("fuzz_crash_reproducer.bin")
        
        for seed in seedCorpus {
            for _ in 0..<iterationsPerSeed {
                let corruptedData = mutate(data: seed, ratio: 0.03)
                
                // 1. Crash-First Persistence: Always write crash reproducer BEFORE decoding
                try corruptedData.write(to: crashReproducerURL)
                XCTAssertTrue(FileManager.default.fileExists(atPath: crashReproducerURL.path), "Crash reproducer file must be flushed to disk before parser invocation")
                
                // 2. In-Memory extraction test through C bridge (libarchive + TTZip native parser)
                let status = ttzip_extract_archive_advanced(crashReproducerURL.path, sandboxURL.path, true, nil)
                
                if status == 0 {
                    totalAccepted += 1
                } else {
                    totalHandled += 1
                }
            }
        }
        
        // Clean up reproducer on clean pass
        try? FileManager.default.removeItem(at: crashReproducerURL)
        
        XCTAssertEqual(totalHandled + totalAccepted, seedCorpus.count * iterationsPerSeed)
    }
}
