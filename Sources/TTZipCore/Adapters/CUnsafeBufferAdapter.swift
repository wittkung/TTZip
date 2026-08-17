import Foundation
import CTTZipBridge

/// 内存安全 C 指针与 Buffer 辅助适配包装器 (Adapter Pattern)
/// 消除悬挂指针 (Dangling Pointer) 与内存泄露风险
public enum CUnsafeBufferAdapter {
    
    /// 安全转换 Swift 可选 String 为 C 语言 const char* 指针
    @inline(__always)
    public static func withCString<R>(_ string: String?, _ body: (UnsafePointer<CChar>?) throws -> R) rethrows -> R {
        guard let string = string else {
            return try body(nil)
        }
        return try string.withCString { cStr in
            try body(cStr)
        }
    }

    /// 安全转换 Swift [String] 为 C 语言 const char* const* 连续指针数组（作用域安全，自动清理，零栈溢出）
    public static func withCStringsArray<R>(_ strings: [String], _ body: (UnsafePointer<UnsafePointer<CChar>?>) throws -> R) rethrows -> R {
        var cStrings: [UnsafeMutablePointer<CChar>?] = []
        cStrings.reserveCapacity(strings.count + 1)
        for str in strings {
            cStrings.append(strdup(str))
        }
        defer {
            for ptr in cStrings {
                if let ptr = ptr {
                    free(ptr)
                }
            }
        }

        return try cStrings.withUnsafeBufferPointer { bufPtr in
            guard let base = bufPtr.baseAddress else {
                var dummy: UnsafePointer<CChar>? = nil
                return try withUnsafePointer(to: &dummy) { try body($0) }
            }
            return try base.withMemoryRebound(to: UnsafePointer<CChar>?.self, capacity: bufPtr.count) { reboundPtr in
                try body(reboundPtr)
            }
        }
    }

    /// 安全转换 Swift [String] 为 C 语言 posix_spawn argv 专属的 NULL 结尾指针数组
    public static func withCStringsNullTerminatedArray<R>(_ strings: [String], _ body: (UnsafePointer<UnsafePointer<CChar>?>) throws -> R) rethrows -> R {
        var cStrings: [UnsafeMutablePointer<CChar>?] = []
        cStrings.reserveCapacity(strings.count + 1)
        for str in strings {
            cStrings.append(strdup(str))
        }
        cStrings.append(nil)
        defer {
            for ptr in cStrings {
                if let ptr = ptr {
                    free(ptr)
                }
            }
        }

        return try cStrings.withUnsafeBufferPointer { bufPtr in
            guard let base = bufPtr.baseAddress else {
                var dummy: UnsafePointer<CChar>? = nil
                return try withUnsafePointer(to: &dummy) { try body($0) }
            }
            return try base.withMemoryRebound(to: UnsafePointer<CChar>?.self, capacity: bufPtr.count) { reboundPtr in
                try body(reboundPtr)
            }
        }
    }

    /// 安全转换 Swift Data 为 C 语言 RawPointer 及其字节长度
    @inline(__always)
    public static func withBufferPointer<R>(_ data: Data, _ body: (UnsafeRawPointer, Int) throws -> R) rethrows -> R {
        if data.isEmpty {
            var dummy: UInt8 = 0
            return try body(&dummy, 0)
        }
        return try data.withUnsafeBytes { rawBuffer in
            if let baseAddress = rawBuffer.baseAddress {
                return try body(baseAddress, data.count)
            } else {
                var dummy: UInt8 = 0
                return try body(&dummy, 0)
            }
        }
    }

    /// 安全转换 Swift Data 为 C 语言 MutableRawPointer 及其容量
    @inline(__always)
    public static func withMutableBufferPointer<R>(_ data: inout Data, _ body: (UnsafeMutableRawPointer, Int) throws -> R) rethrows -> R {
        let count = data.count
        if count == 0 {
            var dummy: UInt8 = 0
            return try body(&dummy, 0)
        }
        return try data.withUnsafeMutableBytes { rawBuffer in
            if let baseAddress = rawBuffer.baseAddress {
                return try body(baseAddress, count)
            } else {
                var dummy: UInt8 = 0
                return try body(&dummy, 0)
            }
        }
    }

    /// 分配 Apple Silicon 16KB 物理页界限对齐内存块
    @inline(__always)
    public static func allocateAlignedBuffer(capacity: Int) -> UnsafeMutableRawPointer? {
        return ttzip_core_aligned_alloc_16k(capacity)
    }

    /// 释放对齐内存块
    @inline(__always)
    public static func deallocateAlignedBuffer(_ pointer: UnsafeMutableRawPointer) {
        ttzip_core_aligned_free_16k(pointer)
    }

    /// 享元模式: 从 MemoryPageFlyweightPool 借出 4K/64K 页面对齐 Buffer 享元
    @inline(__always)
    public static func borrowPageBuffer(size: MemoryPageSize = .page64K) -> MemoryPageBufferFlyweight {
        return MemoryPageFlyweightPool.shared.borrowBuffer(size: size)
    }

    /// 归还 Buffer 享元
    @inline(__always)
    public static func returnPageBuffer(_ buffer: MemoryPageBufferFlyweight) {
        MemoryPageFlyweightPool.shared.returnBuffer(buffer)
    }
}
