// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Value type describing physical entry metadata inside a ZIP archive.
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

/// Encryption schemes supported by ZIP entries.
public enum ZipEncryptionMethod: Sendable, Equatable {
    case none
    case zipCrypto
    case aes128
    case aes192
    case aes256
}

/// Internal thread-safe box container for Int64 state.
final class StateBoxInt64: @unchecked Sendable {
    var value: Int64
    init(_ value: Int64) { self.value = value }
}

/// Internal thread-safe results accumulator for concurrent iterations.
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

/// Internal container wrapping raw pointers across Sendable boundaries.
final class SendablePointerBox: @unchecked Sendable {
    let pointer: UnsafePointer<UInt8>
    let size: Int
    init(pointer: UnsafePointer<UInt8>, size: Int) {
        self.pointer = pointer
        self.size = size
    }
}

final class SendableMutablePointerBox: @unchecked Sendable {
    let pointer: UnsafeMutablePointer<UInt8>
    let size: Int
    init(pointer: UnsafeMutablePointer<UInt8>, size: Int) {
        self.pointer = pointer
        self.size = size
    }
}
