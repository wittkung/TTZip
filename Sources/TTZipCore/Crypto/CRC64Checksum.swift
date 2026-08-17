import Foundation
import CTTZipBridge

/// ARM64 硬件 PMULL 加速与零拷贝 CRC64 (ECMA-182) 计算引擎
@frozen
public enum CRC64Checksum: Sendable {
    /// 零拷贝计算 Data 的 CRC64 (ECMA-182)
    /// - Parameters:
    ///   - data: 待计算的二进制数据
    ///   - seed: 初始 CRC 种子（默认为 0）
    /// - Returns: 计算后的 64 位校验码
    @inlinable
    public static func calculate(for data: Data, seed: UInt64 = 0) -> UInt64 {
        guard !data.isEmpty else { return seed }
        return data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return seed
            }
            return ttzip_crc64(baseAddress, rawBuffer.count, seed)
        }
    }

    /// 零拷贝计算 UnsafeRawBufferPointer 的 CRC64 (ECMA-182)
    /// - Parameters:
    ///   - buffer: 待计算的连续内存缓冲区
    ///   - seed: 初始 CRC 种子（默认为 0）
    /// - Returns: 计算后的 64 位校验码
    @inlinable
    public static func calculate(buffer: UnsafeRawBufferPointer, seed: UInt64 = 0) -> UInt64 {
        guard let base = buffer.baseAddress, buffer.count > 0 else { return seed }
        let bytePtr = base.assumingMemoryBound(to: UInt8.self)
        return ttzip_crc64(bytePtr, buffer.count, seed)
    }

    /// 零拷贝计算 UnsafeBufferPointer<UInt8> 的 CRC64 (ECMA-182)
    /// - Parameters:
    ///   - buffer: 待计算的字节缓冲区
    ///   - seed: 初始 CRC 种子（默认为 0）
    /// - Returns: 计算后的 64 位校验码
    @inlinable
    public static func calculate(buffer: UnsafeBufferPointer<UInt8>, seed: UInt64 = 0) -> UInt64 {
        guard let base = buffer.baseAddress, buffer.count > 0 else { return seed }
        return ttzip_crc64(base, buffer.count, seed)
    }
}
