import Foundation

// MARK: - Algorithm Engine Protocol Abstractions for Clean Architecture & DI

public protocol HardwareTunerProtocol: Sendable {
    var totalCores: Int { get }
    var optimalZstdLongWindowLog: Int { get }
    var optimalAlignedBufferSize: Int { get }
    func boostCurrentThreadPriority()
}

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

public protocol LibdeflateEngineProtocol: Sendable {
    func compress(src: UnsafeRawPointer, srcSize: Int, dst: UnsafeMutableRawPointer, dstCapacity: Int, level: Int) -> Int
    func decompress(src: UnsafeRawPointer, srcSize: Int, dst: UnsafeMutableRawPointer, dstCapacity: Int) -> Int
    func compressData(_ data: Data, level: Int) -> Data?
    func decompressData(_ data: Data, originalSize: Int) -> Data?
}

public protocol POSIXTarEngineProtocol: Sendable {
    func spawnProcess(binaryPath: String, arguments: [String], workingDirectory: String?) throws -> Int32
    func extractTar(archivePath: String, destinationDir: String) throws -> Bool
    func createTar(outputPath: String, inputPaths: [String], workingDirectory: String?) throws -> Bool
}

// Extension conformance for standard engines
extension AppleSiliconTuner: HardwareTunerProtocol {
    public var totalCores: Int {
        return self.topology.totalCores
    }
}

extension NativeZipEngine: ZipEngineProtocol {}
extension SevenZipParallelWriter: SevenZipEngineProtocol {}
extension NativeZstdEngine: ZstdEngineProtocol {}

