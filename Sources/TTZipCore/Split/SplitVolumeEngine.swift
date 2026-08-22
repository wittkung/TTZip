// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-level engine providing multi-volume split archive management, slicing, and reassembly.
public final class SplitVolumeEngine: @unchecked Sendable {
    public static let shared = SplitVolumeEngine()
    
    public init() {}
    
    /// Slices an existing monolithic archive file into multi-volume segments.
    public func sliceArchive(
        archivePath: String,
        splitSizeBytes: Int64,
        namingPattern: VolumeNamingPattern = .numberedExtension,
        cleanOnFailure: Bool = true
    ) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: archivePath) else { return }
        let attrs = try fm.attributesOfItem(atPath: archivePath)
        guard let fileSize = attrs[.size] as? Int64, fileSize > 0 else { return }
        guard splitSizeBytes >= 65536 && splitSizeBytes < fileSize else { return }
        
        let schemeVal: Int32
        switch namingPattern {
        case .numberedExtension:
            schemeVal = Int32(TTZIP_VOLUME_NAMING_NUMBERED.rawValue)
        case .pkzipSpanned:
            schemeVal = Int32(TTZIP_VOLUME_NAMING_PKZIP.rawValue)
        case .rawSplit:
            schemeVal = Int32(TTZIP_VOLUME_NAMING_RAW.rawValue)
        }
        
        let res = archivePath.withCString { cSrc in
            archivePath.withCString { cDst in
                ttzip_rust_split_file(cSrc, cDst, UInt64(splitSizeBytes), schemeVal, cleanOnFailure)
            }
        }
        
        guard res == TTZIP_STATUS_OK else {
            throw ArchiveError.readFailed(code: res.rawValue)
        }
        
        if namingPattern != .pkzipSpanned {
            try? fm.removeItem(atPath: archivePath)
        }
    }
    
    /// Joins multi-volume split files into a continuous output archive.
    public func joinVolumes(
        firstVolumePath: String,
        outputPath: String,
        progressHandler: (@Sendable (Double) -> Bool)? = nil
    ) throws {
        try SplitVolumeConcatenator.shared.join(
            firstVolumePath: firstVolumePath,
            outputPath: outputPath,
            progressHandler: progressHandler
        )
    }
    
    /// Creates a streaming multi-volume writer for pipeline-based archive operations.
    public func makeStreamWriter(
        baseOutputPath: String,
        config: SplitVolumeConfig
    ) throws -> SplitVolumeStreamWriter {
        return try SplitVolumeStreamWriter(
            baseOutputPath: baseOutputPath,
            volumeSizeBytes: config.volumeSizeBytes,
            namingPattern: config.namingPattern,
            cleanOnFailure: config.cleanOnFailure
        )
    }
    
    /// Discovers and lists all volume paths belonging to a split archive set from a seed volume.
    public func resolveVolumes(seedPath: String) -> [String] {
        return SplitVolumeConcatenator.shared.inspect(seedPath: seedPath)?.volumePaths ?? [seedPath]
    }
}

// MARK: - Split Volume Config

//
//


/// Predefined media size presets for split volume generation.
public enum VolumePreset: String, Sendable, Codable, CaseIterable {
    case cd700MB = "cd_700mb"
    case dvd4700MB = "dvd_4700mb"
    case fat32_4GB = "fat32_4gb"
    case email25MB = "email_25mb"
    case wechat100MB = "wechat_100mb"
    case custom = "custom"
}

/// Volume naming conventions for spanned archives.
public enum VolumeNamingPattern: String, Sendable, Codable, CaseIterable {
    case numberedExtension = "numbered_extension" // .7z.001, .zip.001, .tar.001
    case pkzipSpanned = "pkzip_spanned"           // .z01, .z02, .zip
    case rawSplit = "raw_split"                   // .001, .002
}

/// Configuration for creating multi-volume / split archives.
public struct SplitVolumeConfig: Sendable, Codable, Equatable {
    public let volumeSizeBytes: Int64
    public let preset: VolumePreset
    public let namingPattern: VolumeNamingPattern
    public let cleanOnFailure: Bool

    public init(
        volumeSizeBytes: Int64,
        preset: VolumePreset = .custom,
        namingPattern: VolumeNamingPattern = .numberedExtension,
        cleanOnFailure: Bool = true
    ) {
        self.volumeSizeBytes = volumeSizeBytes
        self.preset = preset
        self.namingPattern = namingPattern
        self.cleanOnFailure = cleanOnFailure
    }
}

// MARK: - Stream Writer

//
//


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

// MARK: - Concatenator

//
//


/// High-performance Rust-backed engine for concatenating and reading multi-volume split archives.
public final class SplitVolumeConcatenator: @unchecked Sendable {
    public static let shared = SplitVolumeConcatenator()
    
    public init() {}
    
    /// Joins multi-volume split archive files starting from the first volume seed into a single continuous file.
    public func join(
        firstVolumePath: String,
        outputPath: String,
        progressHandler: (@Sendable (Double) -> Bool)? = nil
    ) throws {
        let status = firstVolumePath.withCString { cFirst in
            outputPath.withCString { cOut in
                if let progressHandler = progressHandler {
                    return withUnsafePointer(to: progressHandler) { ptr in
                        let callback: TTZipProgressCallback = { current, total, _, userData in
                            guard let userData = userData else { return true }
                            let handler = userData.assumingMemoryBound(to: (@Sendable (Double) -> Bool).self).pointee
                            let fraction = total > 0 ? Double(current) / Double(total) : 0.0
                            return handler(fraction)
                        }
                        return ttzip_rust_join_split_volumes(cFirst, cOut, callback, UnsafeMutableRawPointer(mutating: ptr))
                    }
                } else {
                    return ttzip_rust_join_split_volumes(cFirst, cOut, nil, nil)
                }
            }
        }
        
        guard status == TTZIP_STATUS_OK else {
            if status == TTZIP_STATUS_CANCELLED {
                throw ArchiveError.cancelled
            }
            throw ArchiveError.readFailed(code: status.rawValue)
        }
    }
    
    /// Queries the total uncompressed continuous size and volume count for a split volume series.
    public func inspect(seedPath: String) -> (totalSize: UInt64, volumePaths: [String])? {
        guard let handle = seedPath.withCString({ ttzip_rust_split_reader_open($0) }) else {
            return nil
        }
        defer { ttzip_rust_split_reader_free(handle) }
        
        let totalSize = ttzip_rust_split_reader_get_total_size(handle)
        let count = ttzip_rust_split_reader_get_volume_count(handle)
        
        var paths: [String] = []
        paths.reserveCapacity(count)
        var buf = [CChar](repeating: 0, count: 1024)
        for i in 0..<count {
            let res = ttzip_rust_split_reader_get_volume_path(handle, i, &buf, buf.count)
            if res == TTZIP_STATUS_OK {
                buf.withUnsafeBufferPointer { ptr in
                    if let base = ptr.baseAddress {
                        paths.append(String(cString: base))
                    }
                }
            }
        }
        return (totalSize, paths)
    }
}

// MARK: - Parallel Encrypted Split Engine

//
//


/// Hardware-accelerated encrypted multi-volume archive engine (7z `.7z.001` and ZIP `.zip.001`).
///
/// Output volumes are 100% compliant with standard 7-Zip, Bandizip, WinRAR, Keka, and macOS Archive Utility.
public final class NativeParallelEncryptedSplitEngine: @unchecked Sendable {
    public init() {}
    
    public enum SplitFormat: String, Sendable {
        case sevenZip = "7z"
        case zip = "zip"
    }
    
    /// Creates standard encrypted multi-volume split archives (100% in-process C execution).
    public func createStandardEncryptedSplitVolume(
        format: SplitFormat = .sevenZip,
        sourcePaths: [String],
        outputDir: String,
        baseName: String,
        splitVolumeSizeBytes: Int64,
        password: String,
        encryptFileNames: Bool = true,
        progressHandler: (@Sendable (Double) -> Void)? = nil
    ) async throws -> [String] {
        guard !sourcePaths.isEmpty else {
            throw ArchiveError.readFailed(code: -404)
        }
        
        AppleSiliconTuner.shared.boostCurrentThreadPriority()
        
        let targetExtension = (format == .sevenZip) ? "7z" : "zip"
        let primaryOutputPath = (outputDir as NSString).appendingPathComponent("\(baseName).\(targetExtension)")
        try? FileManager.default.removeItem(atPath: primaryOutputPath)
        
        progressHandler?(0.1)
        
        let enc: TTZipEncryptionMethod = !password.isEmpty ? TTZIP_ENCRYPTION_AES256 : TTZIP_ENCRYPTION_NONE
        let pwd = !password.isEmpty ? password : nil
        let rustFormat = (format == .sevenZip) ? TTZIP_ARCHIVE_FORMAT_SEVEN_ZIP : TTZIP_ARCHIVE_FORMAT_ZIP
        
        let res = CUnsafeBufferAdapter.withCString(primaryOutputPath) { cOutputPath in
            CUnsafeBufferAdapter.withCStringsArray(sourcePaths) { cInputPaths in
                CUnsafeBufferAdapter.withCString(pwd) { cPassword in
                    guard let cOutputPath = cOutputPath else { return TTZIP_STATUS_ERR_INVALID_PARAM }
                    var opt = TTZipCreateOptions(
                        format: rustFormat,
                        level: TTZIP_COMPRESSION_LEVEL_STORE,
                        encryption: enc,
                        password: cPassword,
                        thread_budget: 0,
                        solid_block_size_mb: 0,
                        progress_callback: nil,
                        user_data: nil
                    )
                    return ttzip_rust_create_archive(cInputPaths, sourcePaths.count, cOutputPath, &opt)
                }
            }
        }
        let success = (res == TTZIP_STATUS_OK)
        
        guard success, FileManager.default.fileExists(atPath: primaryOutputPath) else {
            throw ArchiveError.readFailed(code: -405)
        }
        
        progressHandler?(0.7)
        
        // In-process slicing
        try ArchiveWriter.sliceArchiveIfNeeded(archivePath: primaryOutputPath, splitSizeBytes: splitVolumeSizeBytes)
        
        progressHandler?(1.0)
        
        // Retrieve generated volume list
        let fm = FileManager.default
        let allFiles = (try? fm.contentsOfDirectory(atPath: outputDir)) ?? []
        let generatedVolumes = allFiles.filter { file in
            file.hasPrefix(baseName) && (file.contains(".7z.") || file.contains(".z") || file.contains(".00") || file.hasSuffix(".7z") || file.hasSuffix(".zip"))
        }.sorted().map { (outputDir as NSString).appendingPathComponent($0) }
        
        return generatedVolumes
    }
}
