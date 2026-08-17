import Foundation
import CTTZipBridge

/// POSIX Tar / posix_spawn 底层系统引擎适配器 (Adapter Pattern)
/// 将 /usr/bin/tar 与 ttzip_core_posix_spawn_fast 适配为标准的 Swift 归档/子进程协议
public final class POSIXTarCAdapter: POSIXTarEngineProtocol, Sendable {
    public static let shared = POSIXTarCAdapter()
    
    private init() {}
    
    /// 调度底层极速 posix_spawn 子进程
    public func spawnProcess(
        binaryPath: String,
        arguments: [String],
        workingDirectory: String? = nil
    ) throws -> Int32 {
        let fullArgs = [binaryPath] + arguments
        return CUnsafeBufferAdapter.withCString(binaryPath) { cBinPath in
            CUnsafeBufferAdapter.withCStringsNullTerminatedArray(fullArgs) { cArgv in
                CUnsafeBufferAdapter.withCString(workingDirectory) { cWorkDir in
                    guard let cBinPath = cBinPath else { return Int32(-1) }
                    return ttzip_core_posix_spawn_fast(cBinPath, cArgv, cWorkDir)
                }
            }
        }
    }
    
    /// 进程内极速解压 Tar 归档包 (100% 纯原生 C 静态库驱动)
    public func extractTar(
        archivePath: String,
        destinationDir: String
    ) throws -> Bool {
        try FileManager.default.createDirectory(atPath: destinationDir, withIntermediateDirectories: true)
        let status = ttzip_extract_tar_native_c(archivePath, destinationDir, false)
        return status == 0
    }
    
    /// 进程内极速创建打包 Tar 归档包 (100% 纯原生 C 静态库驱动)
    public func createTar(
        outputPath: String,
        inputPaths: [String],
        workingDirectory: String? = nil
    ) throws -> Bool {
        let fullInputPaths: [String] = inputPaths.map { p in
            if p.hasPrefix("/") {
                return p
            } else if let wd = workingDirectory {
                return (wd as NSString).appendingPathComponent(p)
            } else {
                return p
            }
        }
        let status = CUnsafeBufferAdapter.withCStringsArray(fullInputPaths) { cInputPaths in
            ttzip_create_tar_native_c(outputPath, "tar", cInputPaths, fullInputPaths.count, false, 1)
        }
        return status == 0
    }
}
