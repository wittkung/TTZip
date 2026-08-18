// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - Algorithm Engine Protocol Abstractions for Clean Architecture & Dependency Injection

/// Hardware topology tuning interface for thread pool sizing, buffer alignment, and QoS boosting.
public protocol HardwareTunerProtocol: Sendable {
    /// Total logical/physical core count available for concurrency.
    var totalCores: Int { get }
    /// Optimal Zstandard long distance matching window log base 2.
    var optimalZstdLongWindowLog: Int { get }
    /// Optimal page-aligned memory buffer size in bytes.
    var optimalAlignedBufferSize: Int { get }
    /// Elevates current thread QoS priority to userInteractive/userInitiated.
    func boostCurrentThreadPriority()
}

/// Interface for native parallel ZIP format creation engines.
public protocol ZipEngineProtocol: Sendable {
    func createZipParallel(
        outputPath: String,
        inputPaths: [String],
        level: ArchiveCompressionLevel,
        skipMacJunk: Bool,
        password: String?,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)?
    ) throws -> Bool
}

/// Interface for 7z format creation and extraction engines.
public protocol SevenZipEngineProtocol: Sendable {
    func createArchive(
        outputPath: String,
        inputPaths: [String],
        level: ArchiveCompressionLevel,
        password: String?,
        useZstd: Bool,
        solidBlockSizeMb: Int,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)?
    ) throws -> Bool

    func extractArchive(
        archivePath: String,
        destinationDir: String,
        password: String?
    ) throws -> Bool
}

extension SevenZipEngineProtocol {
    public func createArchive(
        outputPath: String,
        inputPaths: [String],
        level: ArchiveCompressionLevel = .normal,
        password: String? = nil,
        useZstd: Bool = false,
        solidBlockSizeMb: Int = 128,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        return try createArchive(
            outputPath: outputPath,
            inputPaths: inputPaths,
            level: level,
            password: password,
            useZstd: useZstd,
            solidBlockSizeMb: solidBlockSizeMb,
            progressHandler: progressHandler
        )
    }

    public func extractArchive(
        archivePath: String,
        destinationDir: String,
        password: String? = nil
    ) throws -> Bool {
        return try extractArchive(
            archivePath: archivePath,
            destinationDir: destinationDir,
            password: password
        )
    }
}

/// Interface for Zstandard (zst) file compression and decompression engines.
public protocol ZstdEngineProtocol: Sendable {
    func compressFile(
        srcPath: String,
        dstPath: String,
        level: ArchiveCompressionLevel,
        enableLDM: Bool,
        dictPath: String?,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)?
    ) throws -> Bool
    
    func decompressFile(
        srcPath: String,
        dstPath: String,
        dictPath: String?,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)?
    ) throws -> Bool
}

/// Interface for libdeflate fast DEFLATE / zlib compression primitives.
public protocol LibdeflateEngineProtocol: Sendable {
    func compress(src: UnsafeRawPointer, srcSize: Int, dst: UnsafeMutableRawPointer, dstCapacity: Int, level: Int) -> Int
    func decompress(src: UnsafeRawPointer, srcSize: Int, dst: UnsafeMutableRawPointer, dstCapacity: Int) -> Int
    func compressData(_ data: Data, level: Int) -> Data?
    func decompressData(_ data: Data, originalSize: Int) -> Data?
}

/// Interface for POSIX tar process spawning and tar stream packaging.
public protocol POSIXTarEngineProtocol: Sendable {
    func spawnProcess(binaryPath: String, arguments: [String], workingDirectory: String?) throws -> Int32
    func extractTar(archivePath: String, destinationDir: String) throws -> Bool
    func createTar(outputPath: String, inputPaths: [String], workingDirectory: String?) throws -> Bool
}

// Extension conformances for standard engine implementations
extension AppleSiliconTuner: HardwareTunerProtocol {
    public var totalCores: Int {
        return self.topology.totalCores
    }
}

extension NativeZipEngine: ZipEngineProtocol {}
extension SevenZipParallelWriter: SevenZipEngineProtocol {}
extension NativeZstdEngine: ZstdEngineProtocol {}
