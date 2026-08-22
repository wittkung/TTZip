// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-performance multi-format archive compression engine (Ultra-Thin Rust C-ABI Facade).
public final class ArchiveWriter: ArchiveWriting, @unchecked Sendable {
    internal let hardwareTuner: HardwareTunerProtocol
    public let targetFormat: ArchiveCompressionFormat?

    public init(
        hardwareTuner: HardwareTunerProtocol = AppleSiliconTuner.shared,
        targetFormat: ArchiveCompressionFormat? = nil
    ) {
        self.hardwareTuner = hardwareTuner
        self.targetFormat = targetFormat
    }

    /// Backward-compatible initializer accepting legacy engine parameters.
    public convenience init(
        zipEngine: Any? = nil,
        sevenZipEngine: Any? = nil,
        zstdEngine: Any? = nil,
        hardwareTuner: HardwareTunerProtocol = AppleSiliconTuner.shared,
        targetFormat: ArchiveCompressionFormat? = nil
    ) {
        self.init(hardwareTuner: hardwareTuner, targetFormat: targetFormat)
    }

    /// Asynchronously compresses files and directories into an archive with validation and progress tracking.
    public func createArchive(
        outputPath: String,
        format: ArchiveCompressionFormat = .zip,
        level: ArchiveCompressionLevel = .normal,
        inputPaths: [String],
        options: ArchiveFilterOptions = .defaultClean,
        splitVolumeSizeBytes: Int64? = nil,
        password: String? = nil,
        advancedOptions: ArchiveAdvancedOptions = .defaultOptions,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) async throws {
        guard !inputPaths.isEmpty else {
            throw ArchiveError.readFailed(code: -10)
        }

        try Task.checkCancellation()

        try await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            try self.createArchiveSync(
                outputPath: outputPath,
                format: format,
                level: level,
                inputPaths: inputPaths,
                options: options,
                password: password,
                splitVolumeSizeBytes: splitVolumeSizeBytes,
                advancedOptions: advancedOptions,
                progressHandler: progressHandler
            )
        }.value
    }

    /// Synchronously creates an archive bypassing Task queue context-switches.
    @inline(__always)
    public func createArchiveSync(
        outputPath: String,
        format: ArchiveCompressionFormat = .zip,
        level: ArchiveCompressionLevel = .normal,
        inputPaths: [String],
        options: ArchiveFilterOptions = .defaultClean,
        password: String? = nil,
        splitVolumeSizeBytes: Int64? = nil,
        advancedOptions: ArchiveAdvancedOptions = .defaultOptions,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws {
        guard !inputPaths.isEmpty else {
            throw ArchiveError.readFailed(code: -10)
        }
        if (level == .ultra || level.rawValue >= 9) && !LicenseManager.shared.isPro {
            throw ArchiveError.readFailed(code: -403)
        }

        let startTime = Date()
        let totalBytes = inputPaths.reduce(Int64(0)) { $0 + Self.recursivePathSize(at: $1) }

        try createArchiveInternal(
            outputPath: outputPath,
            format: format,
            level: level,
            inputPaths: inputPaths,
            options: options,
            splitVolumeSizeBytes: splitVolumeSizeBytes,
            password: password,
            advancedOptions: advancedOptions,
            progressHandler: progressHandler,
            startTime: startTime,
            totalBytes: totalBytes
        )
    }

    // MARK: - Format Mappings

    internal static func mapFormat(_ format: ArchiveCompressionFormat) -> TTZipArchiveFormat {
        switch format {
        case .sevenZip: return TTZIP_ARCHIVE_FORMAT_SEVEN_ZIP
        case .zip: return TTZIP_ARCHIVE_FORMAT_ZIP
        case .tar: return TTZIP_ARCHIVE_FORMAT_TAR
        case .tarGz, .gz: return TTZIP_ARCHIVE_FORMAT_TAR_GZ
        case .tarBz2, .bz2: return TTZIP_ARCHIVE_FORMAT_TAR_BZ2
        case .tarXz, .xz: return TTZIP_ARCHIVE_FORMAT_TAR_XZ
        case .tarZst, .zst: return TTZIP_ARCHIVE_FORMAT_TAR_ZSTD
        case .dmg: return TTZIP_ARCHIVE_FORMAT_DMG
        case .snappy: return TTZIP_ARCHIVE_FORMAT_SNAPPY
        case .aar: return TTZIP_ARCHIVE_FORMAT_LZFSE
        default: return TTZIP_ARCHIVE_FORMAT_ZIP
        }
    }

    internal static func mapLevel(_ level: ArchiveCompressionLevel) -> TTZipCompressionLevel {
        switch level {
        case .store: return TTZIP_COMPRESSION_LEVEL_STORE
        case .fastest, .fast: return TTZIP_COMPRESSION_LEVEL_FASTEST
        case .normal: return TTZIP_COMPRESSION_LEVEL_NORMAL
        case .maximum: return TTZIP_COMPRESSION_LEVEL_MAXIMUM
        case .ultra: return TTZIP_COMPRESSION_LEVEL_ULTRA
        default: return TTZIP_COMPRESSION_LEVEL_NORMAL
        }
    }
}

// MARK: - Zip Dispatch

//
//


extension ArchiveWriter {
    /// Dispatches compression requests targeting the ZIP archive format directly via Rust C-ABI.
    /// - Returns: `true` if the archive creation was handled and completed successfully, `false` otherwise.
    internal func dispatchZipCreation(
        outputPath: String,
        level: ArchiveCompressionLevel,
        inputPaths: [String],
        options: ArchiveFilterOptions,
        splitVolumeSizeBytes: Int64?,
        password: String?,
        advancedOptions: ArchiveAdvancedOptions,
        startTime: Date,
        totalBytes: Int64,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)?
    ) throws -> Bool {
        return createArchiveWithRust(
            outputPath: outputPath,
            format: .zip,
            inputPaths: inputPaths,
            level: level,
            password: password,
            splitVolumeSizeBytes: splitVolumeSizeBytes,
            skipMacJunk: options.skipMacJunk,
            startTime: startTime,
            totalBytes: totalBytes,
            progressHandler: progressHandler
        )
    }
}

// MARK: - Tar & 7z Dispatch

//
//


extension ArchiveWriter {
    internal func notifyCompletion(
        totalBytes: Int64,
        startTime: Date,
        message: String,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)?
    ) {
        let duration = max(0.001, Date().timeIntervalSince(startTime))
        let throughput = (Double(totalBytes) / (1024 * 1024)) / duration
        progressHandler?(ArchiveProgress(
            state: .completed,
            bytesProcessed: totalBytes,
            totalBytes: totalBytes,
            currentFileName: message,
            throughputMBs: throughput
        ))
    }

    /// Internal synchronous archive creation implementation.
    internal func createArchiveInternal(
        outputPath: String,
        format: ArchiveCompressionFormat,
        level: ArchiveCompressionLevel,
        inputPaths: [String],
        options: ArchiveFilterOptions,
        splitVolumeSizeBytes: Int64?,
        password: String?,
        advancedOptions: ArchiveAdvancedOptions,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)?,
        startTime: Date,
        totalBytes: Int64
    ) throws {
        hardwareTuner.boostCurrentThreadPriority()

        let targetFmt = self.targetFormat ?? format
        if targetFmt == .zip {
            let handled = try dispatchZipCreation(
                outputPath: outputPath,
                level: level,
                inputPaths: inputPaths,
                options: options,
                splitVolumeSizeBytes: splitVolumeSizeBytes,
                password: password,
                advancedOptions: advancedOptions,
                startTime: startTime,
                totalBytes: totalBytes,
                progressHandler: progressHandler
            )
            if handled { return }
        }

        let actualFormat: ArchiveCompressionFormat
        if targetFmt == .zst {
            actualFormat = .tarZst
        } else if targetFmt == .iso {
            actualFormat = .tar
        } else {
            actualFormat = targetFmt
        }

        let success = createArchiveWithRust(
            outputPath: outputPath,
            format: actualFormat,
            inputPaths: inputPaths,
            level: level,
            password: password,
            splitVolumeSizeBytes: splitVolumeSizeBytes,
            skipMacJunk: options.skipMacJunk,
            startTime: startTime,
            totalBytes: totalBytes,
            progressHandler: progressHandler
        )

        if success {
            return
        }

        throw ArchiveError.readFailed(code: -1)
    }

    /// Directly drives archive compression through the Rust C-ABI microkernel.
    internal func createArchiveWithRust(
        outputPath: String,
        format: ArchiveCompressionFormat,
        inputPaths: [String],
        level: ArchiveCompressionLevel,
        password: String?,
        splitVolumeSizeBytes: Int64? = nil,
        skipMacJunk: Bool = true,
        startTime: Date = Date(),
        totalBytes: Int64 = 0,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) -> Bool {
        let rustFormat = ArchiveWriter.mapFormat(format)
        let lvlMap = ArchiveWriter.mapLevel(level)

        let enc: TTZipEncryptionMethod = (password != nil && !password!.isEmpty) ? TTZIP_ENCRYPTION_AES256 : TTZIP_ENCRYPTION_NONE
        let pwd = (password != nil && !password!.isEmpty) ? password : nil
        let splitSize = UInt64(max(0, splitVolumeSizeBytes ?? 0))

        let status = CUnsafeBufferAdapter.withCString(outputPath) { cOutputPath in
            CUnsafeBufferAdapter.withCStringsArray(inputPaths) { cInputPaths in
                CUnsafeBufferAdapter.withCString(pwd) { cPassword in
                    guard let cOutputPath = cOutputPath else { return TTZIP_STATUS_ERR_INVALID_PARAM }
                    var opt = TTZipCreateOptions(
                        format: rustFormat,
                        level: lvlMap,
                        encryption: enc,
                        password: cPassword,
                        thread_budget: 0,
                        solid_block_size_mb: 0,
                        progress_callback: nil,
                        user_data: nil
                    )
                    return ttzip_rust_archive_create_unified(cInputPaths, inputPaths.count, cOutputPath, &opt, splitSize)
                }
            }
        }

        if status == TTZIP_STATUS_OK {
            notifyCompletion(totalBytes: totalBytes, startTime: startTime, message: "Archive created", progressHandler: progressHandler)
            return true
        }
        return false
    }
}

// MARK: - Helpers

//
//


final class SafeAtomicInt64: @unchecked Sendable {
    private var _val: Int64
    private let lock = NSLock()
    
    init(_ val: Int64) {
        self._val = val
    }
    
    var val: Int64 {
        get { lock.withLock { _val } }
        set { lock.withLock { _val = newValue } }
    }
}

extension ArchiveWriter {
    /// Calculates physical directory byte size using high-performance parallel Rust scanner.
    static func recursivePathSize(at path: String) -> Int64 {
        var st = stat()
        if lstat(path, &st) != 0 { return 0 }
        if (st.st_mode & S_IFMT) != S_IFDIR {
            return Int64(st.st_size)
        }
        
        var totalBytes: Int64 = 0
        var config = TTZipScanConfigRaw(
            include_hidden: true,
            skip_mac_junk: false,
            max_depth: 0,
            thread_budget: 0
        )
        
        _ = path.withCString { cPath in
            withUnsafeMutablePointer(to: &totalBytes) { totalPtr in
                ttzip_rust_scan_directory_parallel(
                    cPath,
                    &config,
                    { itemPtr, userData in
                        guard let item = itemPtr, let ptr = userData else { return true }
                        if !item.pointee.is_directory {
                            let bound = ptr.assumingMemoryBound(to: Int64.self)
                            bound.pointee += Int64(item.pointee.file_size)
                        }
                        return true
                    },
                    totalPtr
                )
            }
        }
        
        return totalBytes
    }
    
    /// Splits an archive file into numbered or spanned volumes via Rust C-ABI when split volume size is specified.
    public static func sliceArchiveIfNeeded(
        archivePath: String,
        splitSizeBytes: Int64,
        namingPattern: VolumeNamingPattern = .numberedExtension
    ) throws {
        let scheme: TTZipVolumeNamingScheme
        switch namingPattern {
        case .numberedExtension:
            scheme = TTZIP_VOLUME_NAMING_NUMBERED
        case .pkzipSpanned:
            scheme = TTZIP_VOLUME_NAMING_PKZIP
        case .rawSplit:
            scheme = TTZIP_VOLUME_NAMING_RAW
        }
        let status = CUnsafeBufferAdapter.withCString(archivePath) { cPath in
            guard let cPath = cPath else { return TTZIP_STATUS_ERR_INVALID_PARAM }
            return ttzip_rust_split_file(cPath, cPath, UInt64(splitSizeBytes), Int32(scheme.rawValue), true)
        }
        if status != TTZIP_STATUS_OK {
            throw ArchiveError.readFailed(code: status.rawValue)
        }
    }
}
