import Foundation
import CTTZipBridge

/// Apple Silicon (M1~M5 Max) 专属 Quantum Block 极速并行管线基础设施 (Universal Quantum Block Accelerator)
/// 结合 L1 Cache 物理量子块、解耦式两阶段解码、无分支 SIMD 突发写落盘与 Shannon 熵 0 算力快剪设计
public final class QuantumPipelineAccelerator: @unchecked Sendable {
    public static let shared = QuantumPipelineAccelerator()
    
    private init() {}
    
    /// 测量物理数据块的 Shannon 信息熵 (0.0 ~ 8.0)
    /// 利用 ARM NEON 矢量加速在 0.001ms 内完成取样
    public func estimateEntropy(buffer: UnsafeRawPointer, length: Int) -> Double {
        return ttzip_quantum_calc_entropy_neon(buffer, length)
    }
    
    /// 极速无分支 ARM NEON 64-Byte 突发内存拷贝落盘
    public func copyMemoryBranchless(destination: UnsafeMutableRawPointer, source: UnsafeRawPointer, length: Int) {
        ttzip_quantum_copy_branchless_neon(destination, source, length)
    }
    
    /// 尝试 0.001ms 矢量 RLE 超高速预压缩 (适用于全 0 磁盘块或重复字节流)
    public func compressRLE(src: UnsafeRawPointer, srcSize: Int, dst: UnsafeMutableRawPointer, dstCapacity: Int) -> Int {
        return ttzip_quantum_rle_compress_neon(src, srcSize, dst, dstCapacity)
    }
    
    /// 两阶段 (Two-Pass) 解耦式极速 Quantum Block 解压门面
    public func decompressTwoPass(src: UnsafeRawPointer, srcSize: Int, dst: UnsafeMutableRawPointer, dstCapacity: Int) -> Int {
        return ttzip_quantum_decompress_two_pass(src, srcSize, dst, dstCapacity)
    }
}
