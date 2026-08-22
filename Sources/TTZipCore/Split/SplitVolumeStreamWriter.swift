// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-performance Rust-backed in-stream multi-volume split archive writer.
///
/// Intercepts archive byte streams in real time with byte-level accuracy, seamlessly rotating
/// volume files without intermediate disk or memory buffering.
public final class SplitVolumeStreamWriter: @unchecked Sendable {
    public let baseOutputPath: String
    public let volumeSizeBytes: Int64
    public let namingPattern: VolumeNamingPattern
    public let cleanOnFailure: Bool
    
    private var writerHandle: OpaquePointer?
    private let lock = NSLock()
    private var isClosed = false
    
    public var totalBytes: Int64 {
        lock.lock()
        defer { lock.unlock() }
        guard let handle = writerHandle else { return 0 }
        return Int64(ttzip_rust_split_writer_get_total_bytes(handle))
    }
    
    public var generatedVolumes: [String] {
        lock.lock()
        defer { lock.unlock() }
        guard let handle = writerHandle else { return [] }
        return fetchVolumePaths(from: handle)
    }
    
    public init(
        baseOutputPath: String,
        volumeSizeBytes: Int64,
        namingPattern: VolumeNamingPattern = .numberedExtension,
        cleanOnFailure: Bool = true
    ) throws {
        guard volumeSizeBytes >= 65536 else {
            throw ArchiveError.invalidFormat
        }
        self.baseOutputPath = baseOutputPath
        self.volumeSizeBytes = volumeSizeBytes
        self.namingPattern = namingPattern
        self.cleanOnFailure = cleanOnFailure
        
        let schemeVal: Int32
        switch namingPattern {
        case .numberedExtension:
            schemeVal = Int32(TTZIP_VOLUME_NAMING_NUMBERED.rawValue)
        case .pkzipSpanned:
            schemeVal = Int32(TTZIP_VOLUME_NAMING_PKZIP.rawValue)
        case .rawSplit:
            schemeVal = Int32(TTZIP_VOLUME_NAMING_RAW.rawValue)
        }
        
        let handle = baseOutputPath.withCString { cPath in
            ttzip_rust_split_writer_new(cPath, UInt64(volumeSizeBytes), schemeVal, cleanOnFailure)
        }
        
        guard let validHandle = handle else {
            throw ArchiveError.readFailed(code: -1)
        }
        self.writerHandle = validHandle
    }
    
    /// Writes a data buffer across volume boundaries.
    public func write(data: Data) throws {
        try data.withUnsafeBytes { rawBuffer in
            try write(buffer: rawBuffer)
        }
    }
    
    /// Writes raw byte buffer across volume boundaries with zero intermediate allocations.
    public func write(buffer: UnsafeRawBufferPointer) throws {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isClosed, let handle = writerHandle, let basePtr = buffer.baseAddress else { return }
        let res = ttzip_rust_split_writer_write(handle, basePtr.assumingMemoryBound(to: UInt8.self), buffer.count)
        if res != 0 {
            throw ArchiveError.readFailed(code: res)
        }
    }
    
    /// Flushes any pending buffered data to the current volume.
    public func flush() throws {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isClosed, let handle = writerHandle else { return }
        let status = ttzip_rust_split_writer_flush(handle)
        guard status == TTZIP_STATUS_OK else {
            throw ArchiveError.readFailed(code: status.rawValue)
        }
    }
    
    /// Computes volume file path for the given 1-based index according to the naming pattern.
    public func volumePath(for index: Int) -> String {
        switch namingPattern {
        case .numberedExtension, .rawSplit:
            return String(format: "%@.%03d", baseOutputPath, index)
        case .pkzipSpanned:
            let baseWithoutExt = (baseOutputPath as NSString).deletingPathExtension
            return String(format: "%@.z%02d", baseWithoutExt, index)
        }
    }
    
    /// Flushes and closes all volume handles, returning the complete list of generated volume paths.
    @discardableResult
    public func close() throws -> [String] {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isClosed, let handle = writerHandle else {
            return writerHandle.map { fetchVolumePaths(from: $0) } ?? []
        }
        isClosed = true
        
        let status = ttzip_rust_split_writer_close(handle)
        guard status == TTZIP_STATUS_OK else {
            throw ArchiveError.readFailed(code: status.rawValue)
        }
        
        return fetchVolumePaths(from: handle)
    }
    
    /// Purges all generated volumes in the event of an archive failure.
    public func cancelAndCleanup() {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isClosed, let handle = writerHandle else { return }
        isClosed = true
        ttzip_rust_split_writer_cancel(handle)
    }
    
    private func fetchVolumePaths(from handle: OpaquePointer) -> [String] {
        let count = ttzip_rust_split_writer_get_volume_count(handle)
        var paths: [String] = []
        paths.reserveCapacity(count)
        
        var buf = [CChar](repeating: 0, count: 1024)
        for i in 0..<count {
            let res = ttzip_rust_split_writer_get_volume_path(handle, i, &buf, buf.count)
            if res == TTZIP_STATUS_OK {
                buf.withUnsafeBufferPointer { ptr in
                    if let base = ptr.baseAddress {
                        paths.append(String(cString: base))
                    }
                }
            }
        }
        return paths
    }
    
    deinit {
        if let handle = writerHandle {
            ttzip_rust_split_writer_free(handle)
        }
    }
}
