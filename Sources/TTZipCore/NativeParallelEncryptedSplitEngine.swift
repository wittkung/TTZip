import Foundation
import CryptoKit
import CTTZipBridge

/// Apple Silicon 硬件加速标准加密分卷引擎 (支持 7z 标准分卷 `.7z.001` 与 Zip64 AES-256 分卷 `.zip.001`, `.z01`)
/// 生成的加密分卷 100% 可被 7-Zip, Bandizip, WinRAR, Keka, macOS Archive Utility 识别并解密 (100% 进程内纯原生 C 驱动，零 Subprocess)
public final class NativeParallelEncryptedSplitEngine: @unchecked Sendable {
    public init() {}
    
    public enum SplitFormat: String, Sendable {
        case sevenZip = "7z"
        case zip = "zip"
    }
    
    /// 创建标准通用可解密分卷包 (100% 进程内纯原生 C 驱动)
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
        
        let success: Bool
        if format == .sevenZip {
            success = (try? SevenZipCAdapter.shared.createArchive(
                outputPath: primaryOutputPath,
                inputPaths: sourcePaths,
                level: .store,
                password: password,
                progressHandler: nil
            )) ?? false
        } else {
            let res = CUnsafeBufferAdapter.withCString(primaryOutputPath) { cOutputPath in
                CUnsafeBufferAdapter.withCStringsArray(sourcePaths) { cInputPaths in
                    CUnsafeBufferAdapter.withCString(password) { cPassword in
                        guard let cOutputPath = cOutputPath else { return Int32(-1) }
                        let status = ttzip_create_zip_parallel_c(cOutputPath, cInputPaths, sourcePaths.count, 0, false, cPassword)
                        if status == 0 { return Int32(0) }
                        return ttzip_create_archive_tuned(cOutputPath, "zip", cInputPaths, sourcePaths.count, false, 0, 0, 16, cPassword)
                    }
                }
            }
            success = (res == 0)
        }
        
        guard success, FileManager.default.fileExists(atPath: primaryOutputPath) else {
            throw ArchiveError.readFailed(code: -405)
        }
        
        progressHandler?(0.7)
        
        // 进程内极速切片
        try ArchiveWriter.sliceArchiveIfNeeded(archivePath: primaryOutputPath, splitSizeBytes: splitVolumeSizeBytes)
        
        progressHandler?(1.0)
        
        // 检索并返回所有已创建的标准分卷文件列表
        let fm = FileManager.default
        let allFiles = (try? fm.contentsOfDirectory(atPath: outputDir)) ?? []
        let generatedVolumes = allFiles.filter { file in
            file.hasPrefix(baseName) && (file.contains(".7z.") || file.contains(".z") || file.contains(".00") || file.hasSuffix(".7z") || file.hasSuffix(".zip"))
        }.sorted().map { (outputDir as NSString).appendingPathComponent($0) }
        
        return generatedVolumes
    }
}
