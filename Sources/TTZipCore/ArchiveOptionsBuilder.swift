// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - Archive Options Fluent Builder

/// Fluent Builder Pattern: Configures fine-grained compression and format parameters.
public struct ArchiveOptionsBuilder: Sendable, Equatable {
    public var format: ArchiveCompressionFormat?
    public var level: ArchiveCompressionLevel?
    public var password: String?
    public var cpuThreads: Int
    public var zipOptions: ZipFormatOptions
    public var sevenZipOptions: SevenZipFormatOptions
    public var zstdOptions: ZstdFormatOptions
    public var tarOptions: TarFormatOptions
    public var appleArchiveOptions: AppleArchiveFormatOptions
    public var diskImageOptions: DiskImageFormatOptions
    public var wimOptions: WimFormatOptions
    
    public init(baseOptions: ArchiveAdvancedOptions = .defaultOptions) {
        self.cpuThreads = baseOptions.cpuThreads
        self.zipOptions = baseOptions.zipOptions
        self.sevenZipOptions = baseOptions.sevenZipOptions
        self.zstdOptions = baseOptions.zstdOptions
        self.tarOptions = baseOptions.tarOptions
        self.appleArchiveOptions = baseOptions.appleArchiveOptions
        self.diskImageOptions = baseOptions.diskImageOptions
        self.wimOptions = baseOptions.wimOptions
    }
    
    @discardableResult
    public func withFormat(_ format: ArchiveCompressionFormat) -> ArchiveOptionsBuilder {
        var copy = self
        copy.format = format
        return copy
    }
    
    @discardableResult
    public func withLevel(_ level: ArchiveCompressionLevel) -> ArchiveOptionsBuilder {
        var copy = self
        copy.level = level
        return copy
    }
    
    @discardableResult
    public func withPassword(_ password: String?) -> ArchiveOptionsBuilder {
        var copy = self
        copy.password = password
        return copy
    }
    
    @discardableResult
    public func withCpuThreads(_ threads: Int) -> ArchiveOptionsBuilder {
        var copy = self
        copy.cpuThreads = threads
        return copy
    }
    
    @discardableResult
    public func withSolidArchive(_ enable: Bool) -> ArchiveOptionsBuilder {
        var copy = self
        copy.sevenZipOptions.enableSolidArchive = enable
        return copy
    }
    
    @discardableResult
    public func withSolidBlockSizeMB(_ sizeMB: Int) -> ArchiveOptionsBuilder {
        var copy = self
        copy.sevenZipOptions.dictionarySizeMB = sizeMB
        return copy
    }
    
    @discardableResult
    public func withZipEncryptionMethod(_ method: String) -> ArchiveOptionsBuilder {
        var copy = self
        copy.zipOptions.zipEncryptionMethod = method
        return copy
    }

    @discardableResult
    public func withZipEncryption(_ method: String) -> ArchiveOptionsBuilder {
        return withZipEncryptionMethod(method)
    }
    
    @discardableResult
    public func withZstdLevel(_ level: Int) -> ArchiveOptionsBuilder {
        var copy = self
        copy.zstdOptions.zstdLevel = level
        return copy
    }
    
    @discardableResult
    public func withZipEncodingUTF8(_ enable: Bool) -> ArchiveOptionsBuilder {
        var copy = self
        copy.zipOptions.zipEncodingUTF8 = enable
        return copy
    }
    
    @discardableResult
    public func withPreservePosixAttributes(_ enable: Bool) -> ArchiveOptionsBuilder {
        var copy = self
        copy.zipOptions.preservePosixAttributes = enable
        return copy
    }
    
    @discardableResult
    public func withZip64Mode(_ mode: String) -> ArchiveOptionsBuilder {
        var copy = self
        copy.zipOptions.zip64Mode = mode
        return copy
    }
    
    @discardableResult
    public func withEnableZeroCopy(_ enable: Bool) -> ArchiveOptionsBuilder {
        var copy = self
        copy.zipOptions.enableZeroCopy = enable
        return copy
    }
    
    @discardableResult
    public func withAlgorithm(_ algorithm: String) -> ArchiveOptionsBuilder {
        var copy = self
        copy.sevenZipOptions.algorithm = algorithm
        return copy
    }
    
    @discardableResult
    public func withDictionarySizeMB(_ sizeMB: Int) -> ArchiveOptionsBuilder {
        var copy = self
        copy.sevenZipOptions.dictionarySizeMB = sizeMB
        return copy
    }
    
    @discardableResult
    public func withEncryptFileNames(_ enable: Bool) -> ArchiveOptionsBuilder {
        var copy = self
        copy.sevenZipOptions.encryptFileNames = enable
        return copy
    }
    
    @discardableResult
    public func withMatchFinder(_ matchFinder: String) -> ArchiveOptionsBuilder {
        var copy = self
        copy.sevenZipOptions.matchFinder = matchFinder
        return copy
    }
    
    @discardableResult
    public func withNumFastBytes(_ numFastBytes: Int) -> ArchiveOptionsBuilder {
        var copy = self
        copy.sevenZipOptions.numFastBytes = numFastBytes
        return copy
    }
    
    @discardableResult
    public func withZstdEnableLDM(_ enable: Bool) -> ArchiveOptionsBuilder {
        var copy = self
        copy.zstdOptions.zstdEnableLDM = enable
        return copy
    }
    
    @discardableResult
    public func withZstdJobSizeMB(_ sizeMB: Int) -> ArchiveOptionsBuilder {
        var copy = self
        copy.zstdOptions.zstdJobSizeMB = sizeMB
        return copy
    }
    
    @discardableResult
    public func withZstdWindowLog(_ windowLog: Int) -> ArchiveOptionsBuilder {
        var copy = self
        copy.zstdOptions.zstdWindowLog = windowLog
        return copy
    }
    
    @discardableResult
    public func withZstdChecksum(_ enable: Bool) -> ArchiveOptionsBuilder {
        var copy = self
        copy.zstdOptions.zstdChecksum = enable
        return copy
    }
    
    @discardableResult
    public func withZstdDictPath(_ path: String?) -> ArchiveOptionsBuilder {
        var copy = self
        copy.zstdOptions.zstdDictPath = path
        return copy
    }
    
    @discardableResult
    public func withTarOptions(_ options: TarFormatOptions) -> ArchiveOptionsBuilder {
        var copy = self
        copy.tarOptions = options
        return copy
    }
    
    @discardableResult
    public func withAppleArchiveOptions(_ options: AppleArchiveFormatOptions) -> ArchiveOptionsBuilder {
        var copy = self
        copy.appleArchiveOptions = options
        return copy
    }
    
    @discardableResult
    public func withDiskImageOptions(_ options: DiskImageFormatOptions) -> ArchiveOptionsBuilder {
        var copy = self
        copy.diskImageOptions = options
        return copy
    }
    
    @discardableResult
    public func withWimOptions(_ options: WimFormatOptions) -> ArchiveOptionsBuilder {
        var copy = self
        copy.wimOptions = options
        return copy
    }
    
    public func build() -> ArchiveAdvancedOptions {
        return ArchiveAdvancedOptions(
            cpuThreads: cpuThreads,
            zipOptions: zipOptions,
            sevenZipOptions: sevenZipOptions,
            zstdOptions: zstdOptions,
            tarOptions: tarOptions,
            appleArchiveOptions: appleArchiveOptions,
            diskImageOptions: diskImageOptions,
            wimOptions: wimOptions
        )
    }
}

extension ArchiveAdvancedOptions {
    public static func builder() -> ArchiveOptionsBuilder {
        return ArchiveOptionsBuilder()
    }
}
