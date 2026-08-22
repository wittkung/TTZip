// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - Unified Archive Advanced Options

/// Unified multi-format advanced configuration options model.
public struct ArchiveAdvancedOptions: Sendable, Equatable {
    public var cpuThreads: Int
    public var zipOptions: ZipFormatOptions
    public var sevenZipOptions: SevenZipFormatOptions
    public var zstdOptions: ZstdFormatOptions
    public var tarOptions: TarFormatOptions
    public var appleArchiveOptions: AppleArchiveFormatOptions
    public var diskImageOptions: DiskImageFormatOptions
    public var wimOptions: WimFormatOptions
    
    // Convenient property accessors
    public var algorithm: String { get { sevenZipOptions.algorithm } set { sevenZipOptions.algorithm = newValue } }
    public var dictionarySizeMB: Int { get { sevenZipOptions.dictionarySizeMB } set { sevenZipOptions.dictionarySizeMB = newValue } }
    public var enableSolidArchive: Bool { get { sevenZipOptions.enableSolidArchive } set { sevenZipOptions.enableSolidArchive = newValue } }
    public var encryptFileNames: Bool { get { sevenZipOptions.encryptFileNames } set { sevenZipOptions.encryptFileNames = newValue } }
    public var zipEncryptionMethod: String { get { zipOptions.zipEncryptionMethod } set { zipOptions.zipEncryptionMethod = newValue } }
    public var zipEncodingUTF8: Bool { get { zipOptions.zipEncodingUTF8 } set { zipOptions.zipEncodingUTF8 = newValue } }
    public var preservePosixAttributes: Bool { get { zipOptions.preservePosixAttributes } set { zipOptions.preservePosixAttributes = newValue } }
    public var enableZeroCopy: Bool { get { zipOptions.enableZeroCopy } set { zipOptions.enableZeroCopy = newValue } }
    public var zstdLevel: Int { get { zstdOptions.zstdLevel } set { zstdOptions.zstdLevel = newValue } }
    public var zstdEnableLDM: Bool { get { zstdOptions.zstdEnableLDM } set { zstdOptions.zstdEnableLDM = newValue } }
    public var zstdDictPath: String? { get { zstdOptions.zstdDictPath } set { zstdOptions.zstdDictPath = newValue } }
    
    public init(
        cpuThreads: Int = 0,
        zipOptions: ZipFormatOptions = ZipFormatOptions(),
        sevenZipOptions: SevenZipFormatOptions = SevenZipFormatOptions(),
        zstdOptions: ZstdFormatOptions = ZstdFormatOptions(),
        tarOptions: TarFormatOptions = TarFormatOptions(),
        appleArchiveOptions: AppleArchiveFormatOptions = AppleArchiveFormatOptions(),
        diskImageOptions: DiskImageFormatOptions = DiskImageFormatOptions(),
        wimOptions: WimFormatOptions = WimFormatOptions()
    ) {
        self.cpuThreads = cpuThreads
        self.zipOptions = zipOptions
        self.sevenZipOptions = sevenZipOptions
        self.zstdOptions = zstdOptions
        self.tarOptions = tarOptions
        self.appleArchiveOptions = appleArchiveOptions
        self.diskImageOptions = diskImageOptions
        self.wimOptions = wimOptions
    }
    
    public init(
        algorithm: String = "LZMA2",
        dictionarySizeMB: Int = 64,
        cpuThreads: Int = 0,
        enableSolidArchive: Bool = true,
        encryptFileNames: Bool = false,
        zipEncryptionMethod: String = "AES-256",
        zipEncodingUTF8: Bool = true,
        zstdLevel: Int = 3,
        zstdEnableLDM: Bool = false,
        preservePosixAttributes: Bool = true,
        zstdDictPath: String? = nil
    ) {
        self.cpuThreads = cpuThreads
        self.sevenZipOptions = SevenZipFormatOptions(algorithm: algorithm, dictionarySizeMB: dictionarySizeMB, enableSolidArchive: enableSolidArchive, encryptFileNames: encryptFileNames)
        self.zipOptions = ZipFormatOptions(zipEncryptionMethod: zipEncryptionMethod, zipEncodingUTF8: zipEncodingUTF8, preservePosixAttributes: preservePosixAttributes)
        self.zstdOptions = ZstdFormatOptions(zstdLevel: zstdLevel, zstdEnableLDM: zstdEnableLDM, zstdDictPath: zstdDictPath)
        self.tarOptions = TarFormatOptions()
        self.appleArchiveOptions = AppleArchiveFormatOptions()
        self.diskImageOptions = DiskImageFormatOptions()
        self.wimOptions = WimFormatOptions()
    }
    
    public static var defaultOptions: ArchiveAdvancedOptions {
        let cores = AppleSiliconTuner.shared.topology.totalCores
        return ArchiveAdvancedOptions(
            cpuThreads: cores,
            zipOptions: ZipFormatOptions(),
            sevenZipOptions: SevenZipFormatOptions(),
            zstdOptions: ZstdFormatOptions(),
            tarOptions: TarFormatOptions(),
            appleArchiveOptions: AppleArchiveFormatOptions(),
            diskImageOptions: DiskImageFormatOptions(),
            wimOptions: WimFormatOptions()
        )
    }
}

// MARK: - PrototypeCopyable Prototype Pattern Extension

extension ArchiveAdvancedOptions: PrototypeCopyable {
    /// Deep-copies this configuration model.
    public func clone() -> ArchiveAdvancedOptions {
        return ArchiveAdvancedOptions(
            cpuThreads: self.cpuThreads,
            zipOptions: self.zipOptions,
            sevenZipOptions: self.sevenZipOptions,
            zstdOptions: self.zstdOptions,
            tarOptions: self.tarOptions,
            appleArchiveOptions: self.appleArchiveOptions,
            diskImageOptions: self.diskImageOptions,
            wimOptions: self.wimOptions
        )
    }
}
