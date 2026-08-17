import XCTest
@testable import TTZipCore

final class QuantumPipelineTests: XCTestCase {
    
    func testQuantumRLEFastCompressAndDecompress() throws {
        // 100KB 全 0 重复字节数据
        let count = 100 * 1024
        let sample = Data(repeating: 0x41, count: count)
        
        var compressed = Data(count: 64)
        let compSize = sample.withUnsafeBytes { srcPtr in
            compressed.withUnsafeMutableBytes { dstPtr in
                QuantumPipelineAccelerator.shared.compressRLE(
                    src: srcPtr.baseAddress!,
                    srcSize: count,
                    dst: dstPtr.baseAddress!,
                    dstCapacity: 64
                )
            }
        }
        
        XCTAssertEqual(compSize, 9, "100KB 全重复数据 RLE 编码后大小必须紧凑收敛至 9 字节")
        
        var decompressed = Data(count: count)
        let decompSize = compressed.withUnsafeBytes { srcPtr in
            decompressed.withUnsafeMutableBytes { dstPtr in
                QuantumPipelineAccelerator.shared.decompressTwoPass(
                    src: srcPtr.baseAddress!,
                    srcSize: compSize,
                    dst: dstPtr.baseAddress!,
                    dstCapacity: count
                )
            }
        }
        
        XCTAssertEqual(decompSize, count, "RLE 还原大小必须一致")
        XCTAssertEqual(decompressed, sample, "RLE 还原内容必须 100% 精准匹配")
    }
    
    func testQuantumEntropyFilter() throws {
        // 纯低熵数据
        let lowEntropyText = String(repeating: "AAAAAAABBBBBBBCCCCCCC", count: 100).data(using: .utf8)!
        let lowEntropy = lowEntropyText.withUnsafeBytes { ptr in
            QuantumPipelineAccelerator.shared.estimateEntropy(buffer: ptr.baseAddress!, length: lowEntropyText.count)
        }
        XCTAssertLessThan(lowEntropy, 2.5, "重复文本熵值必须低")
    }
}
