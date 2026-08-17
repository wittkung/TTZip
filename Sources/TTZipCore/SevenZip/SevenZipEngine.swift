import Foundation
import CTTZipBridge

/// 7z 格式全能核心编解码与调度引擎 (统一收敛 7z 打包、解压、零拷贝 Store 及多核 LZMA2 流处理)
public final class SevenZipEngine: @unchecked Sendable {
    public static let shared = SevenZipEngine()
    
    private static let _mmtArg: String = "-mmt=on"
    private static let mxArgs = ["-mx=0", "-mx=1", "-mx=2", "-mx=3", "-mx=4", "-mx=5", "-mx=6", "-mx=7", "-mx=8", "-mx=9"]
    
    private init() {}
    
    // MARK: - Compression Entry
    
    /// 执行 7z 归档文件创建与打包
    @inline(__always)
    public func createArchive(
        outputPath: String,
        inputPaths: [String],
        level: ArchiveCompressionLevel = .normal,
        password: String? = nil,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        return try SevenZipCAdapter.shared.createArchive(
            outputPath: outputPath,
            inputPaths: inputPaths,
            level: level,
            password: password,
            progressHandler: progressHandler
        )
    }
    
    // MARK: - Extraction Entry
    
    /// 解压 7z 归档文件（100% 自研原生 C 引擎）
    public func extract(
        archivePath: String,
        destinationDir: String,
        password: String? = nil
    ) throws -> Bool {
        let pwd = (password != nil && !password!.isEmpty) ? password : nil

        if archivePath.hasSuffix(".001") || archivePath.contains(".7z.") {
            TTLogger.info("[SevenZipEngine] 分卷归档解压: \(archivePath)")
            let joinedTemp = FileManager.default.temporaryDirectory.appendingPathComponent("joined_\(UUID().uuidString).7z").path
            defer { try? FileManager.default.removeItem(atPath: joinedTemp) }
            if ArchiveExtractor().joinSplitVolumes(firstVolumePath: archivePath, outputPath: joinedTemp) {
                return try SevenZipCAdapter.shared.extractArchive(archivePath: joinedTemp, destinationDir: destinationDir, skipMacJunk: true, password: pwd)
            }
            let ok = try SevenZipCAdapter.shared.extractArchive(archivePath: archivePath, destinationDir: destinationDir, skipMacJunk: true, password: pwd)
            if !ok {
                TTLogger.debug("[SevenZipEngine] 分卷解压 C 层返回失败, archive=\(archivePath)")
            }
            return ok
        }
        
        let ok = try SevenZipCAdapter.shared.extractArchive(archivePath: archivePath, destinationDir: destinationDir, skipMacJunk: true, password: pwd)
        if !ok {
            TTLogger.debug("[SevenZipEngine] C 层解压返回失败, archive=\(archivePath)")
            return false
        }
        
        let items = (try? FileManager.default.contentsOfDirectory(atPath: destinationDir)) ?? []
        TTLogger.debug("[SevenZipEngine] destinationDir: \(destinationDir), itemsCount: \(items.count), items: \(items)")
        if items.isEmpty {
            TTLogger.warning("[SevenZipEngine] C 层返回成功但输出目录为空, dest=\(destinationDir)")
            return false
        }
        
        return true
    }
    
    // MARK: - Helpers
    
    private func splitPath(_ path: String) -> (String?, String) {
        if let lastSlash = path.lastIndex(of: "/") {
            return (String(path[..<lastSlash]), String(path[path.index(after: lastSlash)...]))
        }
        return (nil, path)
    }
}
