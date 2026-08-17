import Foundation

/// 4. Magic Bytes 标头魔数匹配与归档完整性校验处理者 (ArchiveHeaderMagicHandler)
public final class ArchiveHeaderMagicHandler: BaseArchiveValidationHandler, @unchecked Sendable {
    
    public override init(nextHandler: ArchiveValidationHandlerProtocol? = nil) {
        super.init(nextHandler: nextHandler)
    }
    
    override public func process(context: ArchiveValidationContext) throws -> ArchiveValidationResult {
        // 仅在解压 (.extract)、探索 (.inspect) 或修复 (.repair) 模式下对输入归档文件校验魔数
        guard context.operation == .extract || context.operation == .inspect || context.operation == .repair else {
            return .success
        }
        
        guard let archivePath = context.sourcePaths.first, !archivePath.isEmpty else {
            return .failure(.fileNotFound(path: "EMPTY_ARCHIVE_PATH"))
        }
        
        guard let fileHandle = FileHandle(forReadingAtPath: archivePath) else {
            return .failure(.fileNotReadable(path: archivePath))
        }
        defer {
            try? fileHandle.close()
        }
        
        // 读取文件前 4096 字节（支持 SFX 自解压 Stub 标头扫描）
        let headerData: Data
        do {
            headerData = try fileHandle.read(upToCount: 4096) ?? Data()
        } catch {
            return .failure(.invalidHeaderMagic(expected: "Valid Archive Header", actual: "Read error: \(error.localizedDescription)"))
        }
        
        guard !headerData.isEmpty else {
            return .failure(.invalidHeaderMagic(expected: "Non-empty Archive File", actual: "0 bytes (Empty File)"))
        }
        
        let expectedFormat = context.format
        if let targetFmt = expectedFormat {
            let matches = verifyHeaderMatchesFormat(headerData: headerData, format: targetFmt)
            if !matches {
                let actualHex = headerData.prefix(8).map { String(format: "%02X", $0) }.joined(separator: " ")
                return .failure(.invalidHeaderMagic(expected: targetFmt.rawValue.uppercased(), actual: "0x[\(actualHex)]"))
            }
        } else {
            // 未显式指定格式时，自动匹配是否满足任意已知归档魔数或文件扩展名
            let (isRecognized, _) = detectArchiveFormat(headerData: headerData, path: archivePath)
            if !isRecognized {
                let actualHex = headerData.prefix(8).map { String(format: "%02X", $0) }.joined(separator: " ")
                return .failure(.invalidHeaderMagic(expected: "Valid Archive Magic / Extension", actual: "0x[\(actualHex)]"))
            }
        }
        
        return .success
    }
    
    /// 校验标头 Data 是否符合指定 ArchiveCompressionFormat 的 Magic Signature
    private func verifyHeaderMatchesFormat(headerData: Data, format: ArchiveCompressionFormat) -> Bool {
        let bytes = [UInt8](headerData)
        guard !bytes.isEmpty else { return false }
        
        switch format {
        case .zip, .aar:
            return isZipMagic(bytes)
        case .sevenZip:
            return isSevenZipMagic(bytes)
        case .wim:
            return isWimMagic(bytes)
        case .lz4:
            return isLz4Magic(bytes)
        case .lzip:
            return isLzipMagic(bytes)
        case .lrzip:
            return isLrzipMagic(bytes)
        case .snappy:
            return isSnappyMagic(bytes)
        case .tar:
            return isTarMagic(bytes) || isGzipMagic(bytes) || isBzip2Magic(bytes) || isXzMagic(bytes) || isZstdMagic(bytes) || isZipMagic(bytes)
        case .tarGz, .gz:
            return isGzipMagic(bytes) || isTarMagic(bytes)
        case .tarBz2, .bz2:
            return isBzip2Magic(bytes) || isTarMagic(bytes)
        case .tarXz, .xz:
            return isXzMagic(bytes) || isTarMagic(bytes)
        case .tarZst, .zst:
            return isZstdMagic(bytes) || isTarMagic(bytes)
        default:
            return true
        }
    }
    
    /// 识别标头魔数格式
    private func detectArchiveFormat(headerData: Data, path: String) -> (Bool, String) {
        let bytes = [UInt8](headerData)
        guard !bytes.isEmpty else { return (false, "empty") }
        
        if isZipMagic(bytes) { return (true, "ZIP") }
        if isSevenZipMagic(bytes) { return (true, "7Z") }
        if isGzipMagic(bytes) { return (true, "GZIP") }
        if isBzip2Magic(bytes) { return (true, "BZIP2") }
        if isXzMagic(bytes) { return (true, "XZ") }
        if isZstdMagic(bytes) { return (true, "ZSTD") }
        if isWimMagic(bytes) { return (true, "WIM") }
        if isLz4Magic(bytes) { return (true, "LZ4") }
        if isLzipMagic(bytes) { return (true, "LZIP") }
        if isLrzipMagic(bytes) { return (true, "LRZIP") }
        if isSnappyMagic(bytes) { return (true, "SNAPPY") }
        if isTarMagic(bytes) { return (true, "TAR") }
        
        // 文件名后缀兜底识别
        let ext = (path as NSString).pathExtension.lowercased()
        let knownExts: Set<String> = [
            "zip", "7z", "tar", "gz", "tgz", "bz2", "tbz2", "xz", "txz", "zst", "tzst",
            "wim", "lz4", "lz", "br", "brotli", "lrz", "snappy", "aar", "dmg", "iso", "apk", "jar", "exe", "cbr", "cbz", "cab"
        ]
        if knownExts.contains(ext) || Int(ext) != nil {
            return (true, ext.uppercased())
        }
        
        return (false, "UNKNOWN")
    }
    
    // MARK: - Magic Signature Helpers
    
    private func isZipMagic(_ bytes: [UInt8]) -> Bool {
        guard bytes.count >= 4 else { return false }
        // PK\x03\x04 (Local Header), PK\x05\x06 (EOCD), PK\x07\x08 (Data Descriptor)
        if bytes[0] == 0x50 && bytes[1] == 0x4B && ((bytes[2] == 0x03 && bytes[3] == 0x04) || (bytes[2] == 0x05 && bytes[3] == 0x06) || (bytes[2] == 0x07 && bytes[3] == 0x08)) {
            return true
        }
        // Self-Extracting (.exe / SFX) Zip 支持: 标头包含 MZ 且在缓冲中存在 PK\x03\x04
        if bytes.count >= 16 && bytes[0] == 0x4D && bytes[1] == 0x5A {
            let limit = bytes.count - 3
            for i in 0..<limit {
                if bytes[i] == 0x50 && bytes[i+1] == 0x4B && bytes[i+2] == 0x03 && bytes[i+3] == 0x04 {
                    return true
                }
            }
        }
        return false
    }
    
    private func isSevenZipMagic(_ bytes: [UInt8]) -> Bool {
        guard bytes.count >= 6 else { return false }
        // 37 7A BC AF 27 1C (7z\xBC\xAF\x27\x1C)
        if bytes[0] == 0x37 && bytes[1] == 0x7A && bytes[2] == 0xBC && bytes[3] == 0xAF && bytes[4] == 0x27 && bytes[5] == 0x1C {
            return true
        }
        // Self-Extracting (.exe / SFX) 7z 支持: 标头包含 MZ 且在缓冲中存在 37 7A BC AF 27 1C
        if bytes.count >= 16 && bytes[0] == 0x4D && bytes[1] == 0x5A {
            let limit = bytes.count - 5
            for i in 0..<limit {
                if bytes[i] == 0x37 && bytes[i+1] == 0x7A && bytes[i+2] == 0xBC && bytes[i+3] == 0xAF && bytes[i+4] == 0x27 && bytes[i+5] == 0x1C {
                    return true
                }
            }
        }
        return false
    }
    
    private func isGzipMagic(_ bytes: [UInt8]) -> Bool {
        guard bytes.count >= 2 else { return false }
        // 1F 8B
        return bytes[0] == 0x1F && bytes[1] == 0x8B
    }
    
    private func isBzip2Magic(_ bytes: [UInt8]) -> Bool {
        guard bytes.count >= 3 else { return false }
        // 42 5A 68 (BZh)
        return bytes[0] == 0x42 && bytes[1] == 0x5A && bytes[2] == 0x68
    }
    
    private func isXzMagic(_ bytes: [UInt8]) -> Bool {
        guard bytes.count >= 6 else { return false }
        // FD 37 7A 58 5A 00
        return bytes[0] == 0xFD && bytes[1] == 0x37 && bytes[2] == 0x7A && bytes[3] == 0x58 && bytes[4] == 0x5A && bytes[5] == 0x00
    }
    
    private func isZstdMagic(_ bytes: [UInt8]) -> Bool {
        guard bytes.count >= 4 else { return false }
        // 28 B5 2F FD
        return bytes[0] == 0x28 && bytes[1] == 0xB5 && bytes[2] == 0x2F && bytes[3] == 0xFD
    }
    
    private func isWimMagic(_ bytes: [UInt8]) -> Bool {
        guard bytes.count >= 8 else { return false }
        // MSWIM\0\0\0
        return bytes[0] == 0x4D && bytes[1] == 0x53 && bytes[2] == 0x57 && bytes[3] == 0x49 && bytes[4] == 0x4D && bytes[5] == 0x00 && bytes[6] == 0x00 && bytes[7] == 0x00
    }
    
    private func isLz4Magic(_ bytes: [UInt8]) -> Bool {
        guard bytes.count >= 4 else { return false }
        return bytes[0] == 0x04 && bytes[1] == 0x22 && bytes[2] == 0x4D && bytes[3] == 0x18
    }
    
    private func isLzipMagic(_ bytes: [UInt8]) -> Bool {
        guard bytes.count >= 4 else { return false }
        return bytes[0] == 0x4C && bytes[1] == 0x5A && bytes[2] == 0x49 && bytes[3] == 0x50
    }
    
    private func isLrzipMagic(_ bytes: [UInt8]) -> Bool {
        guard bytes.count >= 4 else { return false }
        return bytes[0] == 0x4C && bytes[1] == 0x52 && bytes[2] == 0x5A && bytes[3] == 0x49
    }
    
    private func isSnappyMagic(_ bytes: [UInt8]) -> Bool {
        guard bytes.count >= 10 else { return false }
        return bytes[0] == 0xFF && bytes[1] == 0x06 && bytes[2] == 0x00 && bytes[3] == 0x00 && bytes[4] == 0x73 && bytes[5] == 0x4E && bytes[6] == 0x61 && bytes[7] == 0x50 && bytes[8] == 0x70 && bytes[9] == 0x59
    }
    
    private func isTarMagic(_ bytes: [UInt8]) -> Bool {
        guard bytes.count >= 262 else { return false }
        // TAR header "ustar" magic at byte 257
        let magic = String(bytes: bytes[257..<262], encoding: .ascii) ?? ""
        return magic == "ustar"
    }
}
