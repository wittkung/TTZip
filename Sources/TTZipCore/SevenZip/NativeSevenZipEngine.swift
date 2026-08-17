import Foundation

/// 全核 7z 原生物理极限封装与编解码引擎统一门面
public final class NativeSevenZipEngine: @unchecked Sendable {
    public static let shared = NativeSevenZipEngine()
    
    private init() {}
    
    /// 解析 7z 归档头与条目描述符
    public func inspectSevenZip(archivePath: String, password: String? = nil) -> [ArchiveEntry]? {
        let fd = open(archivePath, O_RDONLY)
        if fd < 0 { return nil }
        defer { close(fd) }
        
        var st = stat()
        if fstat(fd, &st) != 0 || st.st_size < 32 { return nil }
        let fileSize = size_t(st.st_size)
        
        guard let mapped = mmap(nil, fileSize, PROT_READ, MAP_SHARED, fd, 0), mapped != MAP_FAILED else {
            return nil
        }
        let bytePtr = mapped.assumingMemoryBound(to: UInt8.self)
        defer { munmap(mapped, fileSize) }
        
        guard let descriptors = SevenZipHeaderReader.shared.readDescriptors(from: bytePtr, fileSize: fileSize) else {
            return nil
        }
        
        return descriptors.map { desc in
            ArchiveEntry(
                path: desc.path,
                uncompressedSize: desc.uncompressedSize,
                isDirectory: desc.isDirectory,
                detectedEncoding: "UTF-8",
                modificationDate: Date()
            )
        }
    }
    
    /// 执行 7z 归档全核多固实块零拷贝解压
    public func extractSevenZipParallel(
        archivePath: String,
        destinationDir: String,
        password: String? = nil,
        skipMacJunk: Bool = true,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        return try SevenZipParallelExtractor.shared.extract(
            archivePath: archivePath,
            destinationDir: destinationDir,
            password: password,
            skipMacJunk: skipMacJunk,
            progressHandler: progressHandler
        )
    }
    
    /// 执行 7z 归档全核多固实块 (-ms=4g) 打包压缩
    public func createSevenZipParallel(
        outputPath: String,
        inputPaths: [String],
        level: ArchiveCompressionLevel = .normal,
        password: String? = nil,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        return try SevenZipParallelWriter.shared.createArchive(
            outputPath: outputPath,
            inputPaths: inputPaths,
            level: level,
            password: password,
            progressHandler: progressHandler
        )
    }
}
