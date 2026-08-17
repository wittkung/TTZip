import Foundation
import CTTZipBridge

private final class MmapZipAccumulator: @unchecked Sendable {
    var entries: [ArchiveEntry] = []
}

/// 极速 Native ZIP 封装引擎统一门面 (底层由模块化 ZipCentralDirectoryReader / ZipParallelExtractor / ZipParallelWriter 协同构建)
public final class NativeZipEngine: @unchecked Sendable {
    public static let shared = NativeZipEngine()
    
    private init() {}
    
    // MARK: - 1. 零拷贝 mmap 中央目录表列举 (<1ms 秒级查表)
    
    public func inspectZip(archivePath: String) -> [ArchiveEntry]? {
        let accumulator = MmapZipAccumulator()
        let contextPtr = Unmanaged.passUnretained(accumulator).toOpaque()
        
        let status = withExtendedLifetime(accumulator) {
            archivePath.withCString { pathPtr in
                ttzip_mmap_zip_inspect(pathPtr, contextPtr) { ctx, cPathname, size, isDir in
                    guard let ctx = ctx, let cPathname = cPathname else { return }
                    let acc = Unmanaged<MmapZipAccumulator>.fromOpaque(ctx).takeUnretainedValue()
                    let rawLen = strlen(cPathname)
                    let pathData = Data(bytes: cPathname, count: rawLen)
                    let sanitizedPath = CharsetDetector.sanitizeFilename(bytes: pathData)
                    let detectedCharset = CharsetDetector.detectCharset(data: pathData)
                    let entry = ArchiveEntry(
                        path: sanitizedPath,
                        uncompressedSize: size,
                        isDirectory: isDir,
                        detectedEncoding: detectedCharset
                    )
                    acc.entries.append(entry)
                }
            }
        }
        
        if status == 0 && !accumulator.entries.isEmpty {
            return accumulator.entries
        }
        return nil
    }
    
    // MARK: - 2. 全核并发 libdeflate 极速解压引擎
    
    public func extractZipParallel(
        archivePath: String,
        destinationDir: String,
        password: String? = nil,
        skipMacJunk: Bool = true,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        return try ZipParallelExtractor.shared.extract(
            archivePath: archivePath,
            destinationDir: destinationDir,
            password: password,
            skipMacJunk: skipMacJunk,
            progressHandler: progressHandler
        )
    }
    
    // MARK: - 3. 全核并发 libdeflate 极速打包引擎
    
    public func createZipParallel(
        outputPath: String,
        inputPaths: [String],
        level: ArchiveCompressionLevel = .normal,
        skipMacJunk: Bool = true,
        password: String? = nil,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        return try ZipParallelWriter.shared.createArchive(
            outputPath: outputPath,
            inputPaths: inputPaths,
            level: level,
            skipMacJunk: skipMacJunk,
            password: password,
            progressHandler: progressHandler
        )
    }
}
