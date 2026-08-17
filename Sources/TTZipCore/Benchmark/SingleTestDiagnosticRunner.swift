import Foundation
import CTTZipBridge

/// 单项格式测试诊断失败阶段
public enum DiagnosticFailureStage: String, Sendable {
    case datasetPreparation = "STAGE 1 - Dataset Generation (测试数据集生成阶段)"
    case compressionExecution = "STAGE 2 - Compression Execution (归档压缩打包阶段)"
    case archiveValidation = "STAGE 3 - Archive File Validation (压缩包文件合法性校验阶段)"
    case extractionExecution = "STAGE 4 - Extraction Decompression (归档解压缩提解阶段)"
    case integrityVerification = "STAGE 5 - Byte & Hash Integrity Audit (数据完整性与 CRC32 校验阶段)"
}

/// 全格式单项测试极速诊断与精确排查日志引擎
public final class SingleTestDiagnosticRunner: @unchecked Sendable {
    public static let shared = SingleTestDiagnosticRunner()
    
    private init() {}
    
    /// 打印单项测试开始 Banner
    public func logBanner(
        format: ArchiveCompressionFormat,
        level: ArchiveCompressionLevel,
        password: String? = nil,
        sandboxPath: String
    ) {
        let isEnc = (password != nil && !password!.isEmpty)
        let encDesc = isEnc ? "AES-256 加密 (密码: \(password!))" : "未加密"
        TTLogger.info("\n====================================================================================================")
        TTLogger.info("🔬 [TTZip 单项格式诊断测试] 目标格式: \(format.rawValue.uppercased()) (\(format.fileExtension)) | 级别: \(level.title) (\(level.rawValue))")
        TTLogger.info("⚙️ 配置参数: 加密: \(encDesc) | 支持多卷: \(format.supportsSplitVolume) | 运行平台: macOS arm64e")
        TTLogger.info("📁 隔离沙盒: \(sandboxPath)")
        TTLogger.info("====================================================================================================")
    }
    
    /// 打印诊断失败报告 (提供 100% 精确的根因线索与现场快照)
    public func reportFailure(
        stage: DiagnosticFailureStage,
        format: ArchiveCompressionFormat,
        level: ArchiveCompressionLevel,
        password: String? = nil,
        error: Error? = nil,
        errorMessage: String,
        archivePath: String? = nil,
        destinationDir: String? = nil,
        expectedBytes: Int64? = nil,
        actualBytes: Int64? = nil,
        sandboxPath: String? = nil
    ) {
        let isEnc = (password != nil && !password!.isEmpty)
        let encDesc = isEnc ? "AES-256 密码加密 (密码: \(password!))" : "未加密"
        
        TTLogger.error("\n====================================================================================================")
        TTLogger.error("🚨 [单项测试诊断失败报告 - DIAGNOSTIC FAILURE REPORT]")
        TTLogger.error("====================================================================================================")
        TTLogger.error("📌 失败阶段: \(stage.rawValue)")
        TTLogger.error("📦 目标格式: \(format.rawValue.uppercased()) (\(format.fileExtension))")
        TTLogger.error("⚙️ 运行参数: \(level.title) (Level \(level.rawValue)) | \(encDesc)")
        if let s = sandboxPath { TTLogger.error("📁 隔离沙盒: \(s)") }
        if let a = archivePath {
            let sz = (try? FileManager.default.attributesOfItem(atPath: a)[.size] as? Int64) ?? 0
            TTLogger.error("📄 压缩包路径: \(a) (大小: \(sz) 字节)")
        }
        if let d = destinationDir { TTLogger.error("📂 提解目标: \(d)") }
        
        TTLogger.error("\n----------------------------------------------------------------------------------------------------")
        TTLogger.error("🔍 现场错误日志与系统状态:")
        TTLogger.error("  - 错误描述: \(errorMessage)")
        if let err = error {
            TTLogger.error("  - 捕获异常: \(err.localizedDescription) (\(err))")
        }
        if let exp = expectedBytes, let act = actualBytes {
            let diff = act - exp
            let diffStr = diff > 0 ? "+\(diff) 字节 (有残留未清理文件)" : "\(diff) 字节 (数据丢失/解压不完整)"
            TTLogger.error("  - 字节比对: 期望原始 \(exp) 字节 vs 实测提解 \(act) 字节 | 偏差: \(diffStr)")
        }
        
        // 打印针对性根因定位指南 (Actionable Debugging Hints)
        TTLogger.error("\n💡 关键排查点与诊断线索 (Root Cause Diagnostic Hints):")
        let hints = generateDiagnosticHints(stage: stage, format: format, errorMessage: errorMessage, archivePath: archivePath, destinationDir: destinationDir)
        for (idx, hint) in hints.enumerated() {
            TTLogger.error("  \(idx + 1). \(hint)")
        }
        TTLogger.error("====================================================================================================\n")
    }
    
    /// 根据失败阶段与格式生成精准排查建议
    private func generateDiagnosticHints(
        stage: DiagnosticFailureStage,
        format: ArchiveCompressionFormat,
        errorMessage: String,
        archivePath: String?,
        destinationDir: String?
    ) -> [String] {
        var hints: [String] = []
        
        switch stage {
        case .datasetPreparation:
            hints.append("检查磁盘空间与临时目录读写权限 (/tmp 或 system temp directory)。")
            hints.append("确认 FileHandle 写入或字符串编码 Data 转换未抛出 OOM/IO Error。")
            
        case .compressionExecution:
            if format == .zip {
                hints.append("检查 CTTZipBridge (libdeflate / WinZip AES-256) C 语言层函数指针与 CStruct 初始化。")
                hints.append("检查 POSIX path 路径中是否包含未转义特殊字符或多线程写入竞争。")
            } else if format == .sevenZip {
                hints.append("检查 7zz 命令行工具是否安装 (/opt/homebrew/bin/7zz 或 system PATH)。")
                hints.append("确认 CTTZipBridge_7z.c 传入 posix_spawn 的 working_dir 与 relative local_file 路径无误 (避免 0 字节压缩包)。")
            } else if format == .zst || format == .tarZst {
                hints.append("检查 NativeZstdEngine 的 libzstd C 库 API 调用 (zstdContext / zstdCompressBound)。")
            } else {
                hints.append("检查 /usr/bin/tar 或 competitor binary 路径解析，确认 posix_spawn argv[0] 指向有效可执行文件。")
            }
            
        case .archiveValidation:
            hints.append("压缩包大小为 0 字节，表明压缩引擎在创建文件后未写入任何数据流。")
            hints.append("请检查打包逻辑中的文件枚举器是否正常获取到 source input files。")
            
        case .extractionExecution:
            if errorMessage.contains("TTZIP_ERR_INVALID_PASSWORD") || errorMessage.contains("password") {
                hints.append("解密密码校验失败：请核验 PBKDF2-SHA1 2-byte Pwd Verification 逻辑与 WinZip Extra Field 0x9901 解析。")
            } else if errorMessage.contains("chdir") || errorMessage.contains("No such file") {
                hints.append("解压目标目录不存在：请确认在执行 posix_spawn /usr/bin/tar -C dest 前已提前调用 ttzip_common_mkdir_p(dest)。")
            } else {
                hints.append("检查 ArchiveExtractor+Dispatch.swift 中针对该格式的分发逻辑。")
            }
            
        case .integrityVerification:
            hints.append("若解压字节数大于原始字节数：极可能是 tar.gz / tar.zst 解压后遗留了中转 .tar 归档文件未自动 removeItem 删除。")
            hints.append("若解压字节数小于原始字节数：可能存在过滤规则 (如 MacJunk 过滤) 或目录递归枚举跳过了某些特殊点开头文件。")
            hints.append("若 CRC32 指纹不匹配：请检查 Block/Buffer 解压流在解包时是否存在截断或多线程并发写入未同步。")
        }
        
        return hints
    }
}
