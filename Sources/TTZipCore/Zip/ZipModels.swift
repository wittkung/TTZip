import Foundation

/// ZIP 归档内部单个条目的高阶物理特征描述符
public struct ZipEntryDescriptor: Sendable {
    public let path: String
    public let uncompressedSize: Int64
    public let compressedSize: Int64
    public let lfhOffset: Int64
    public let crc32: UInt32
    public let compressionMethod: UInt16
    public let isDirectory: Bool
    public let isEncrypted: Bool
    public let encryptionMethod: ZipEncryptionMethod
}

/// ZIP 条目支持的加密模式类型
public enum ZipEncryptionMethod: Sendable, Equatable {
    case none
    case zipCrypto
    case aes128
    case aes192
    case aes256
}

/// 避免并发闭包 capture 非 Sendable 类型的内部 helper 容器
final class StateBoxInt64: @unchecked Sendable {
    var value: Int64
    init(_ value: Int64) { self.value = value }
}

final class StateBoxResults<T: Sendable>: @unchecked Sendable {
    var values: [T?]
    private let lock = NSLock()
    init(_ values: [T?]) { self.values = values }
    func set(idx: Int, res: T) {
        lock.lock()
        values[idx] = res
        lock.unlock()
    }
}

final class SendablePointerBox: @unchecked Sendable {
    let pointer: UnsafePointer<UInt8>
    let size: Int
    init(pointer: UnsafePointer<UInt8>, size: Int) {
        self.pointer = pointer
        self.size = size
    }
}
