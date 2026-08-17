import Foundation
import CTTZipBridge

/// 极速 mmap 零拷贝 ZIP 中央目录 (Central Directory) 安全对齐解析器
public final class ZipCentralDirectoryReader: @unchecked Sendable {
    public static let shared = ZipCentralDirectoryReader()
    
    private init() {}
    
    @inline(__always)
    private func readU16(_ ptr: UnsafePointer<UInt8>, _ offset: Int) -> UInt16 {
        var val: UInt16 = 0
        memcpy(&val, ptr.advanced(by: offset), 2)
        return val
    }
    
    @inline(__always)
    private func readU32(_ ptr: UnsafePointer<UInt8>, _ offset: Int) -> UInt32 {
        var val: UInt32 = 0
        memcpy(&val, ptr.advanced(by: offset), 4)
        return val
    }
    
    @inline(__always)
    private func readU64(_ ptr: UnsafePointer<UInt8>, _ offset: Int) -> UInt64 {
        var val: UInt64 = 0
        memcpy(&val, ptr.advanced(by: offset), 8)
        return val
    }
    
    @inline(__always)
    private func readI64(_ ptr: UnsafePointer<UInt8>, _ offset: Int) -> Int64 {
        var val: Int64 = 0
        memcpy(&val, ptr.advanced(by: offset), 8)
        return val
    }
    
    public func readDescriptors(from bytePtr: UnsafePointer<UInt8>, fileSize: Int, skipMacJunk: Bool = true) -> [ZipEntryDescriptor]? {
        guard fileSize >= 22 else { return nil }
        
        var eocdInfo = ttzip_eocd_info_t()
        guard ttzip_find_eocd(bytePtr, fileSize, &eocdInfo) else { return nil }
        
        let cdOffset = eocdInfo.cd_offset
        let totalEntries = eocdInfo.total_entries
        
        guard cdOffset < fileSize else { return nil }
        
        var descriptors: [ZipEntryDescriptor] = []
        descriptors.reserveCapacity(min(Int(totalEntries), 65536))
        var currPos = Int(cdOffset)
        
        for _ in 0..<totalEntries {
            if currPos + 46 > fileSize { break }
            let sig = readU32(bytePtr, currPos)
            if sig != 0x02014b50 { break }
            
            let flag = readU16(bytePtr, currPos + 8)
            var method = readU16(bytePtr, currPos + 10)
            let crc = readU32(bytePtr, currPos + 16)
            var compSize = Int64(readU32(bytePtr, currPos + 20))
            var uncompSize = Int64(readU32(bytePtr, currPos + 24))
            let fnLen = Int(readU16(bytePtr, currPos + 28))
            let extraLen = Int(readU16(bytePtr, currPos + 30))
            let commentLen = Int(readU16(bytePtr, currPos + 32))
            let extAttr = readU32(bytePtr, currPos + 38)
            var relOffset = Int64(readU32(bytePtr, currPos + 42))
            
            let recLen = 46 + fnLen + extraLen + commentLen
            if currPos + recLen > fileSize { break }
            
            let fnPtr = bytePtr.advanced(by: currPos + 46)
            let isAscii = ttzip_is_ascii_fast(fnPtr, fnLen)
            let rawPath: String
            if isAscii {
                rawPath = String(decoding: UnsafeRawBufferPointer(start: fnPtr, count: fnLen), as: UTF8.self)
            } else {
                let fnBytes = Data(bytes: fnPtr, count: fnLen)
                rawPath = CharsetDetector.sanitizeFilename(bytes: fnBytes)
            }
            
            var encryption: ZipEncryptionMethod = .none
            let isEncrypted = (flag & 0x0001) != 0
            if isEncrypted {
                encryption = .zipCrypto
            }
            
            if (uncompSize == 0xFFFFFFFF || compSize == 0xFFFFFFFF || relOffset == 0xFFFFFFFF || method == 99) && extraLen >= 4 {
                var extraPos = currPos + 46 + fnLen
                let extraEnd = extraPos + extraLen
                while extraPos + 4 <= extraEnd {
                    let headerId = readU16(bytePtr, extraPos)
                    let dataSize = Int(readU16(bytePtr, extraPos + 2))
                    
                    if headerId == 0x0001 { // Zip64
                        var fieldOffset = extraPos + 4
                        if uncompSize == 0xFFFFFFFF && fieldOffset + 8 <= extraEnd {
                            uncompSize = readI64(bytePtr, fieldOffset)
                            fieldOffset += 8
                        }
                        if compSize == 0xFFFFFFFF && fieldOffset + 8 <= extraEnd {
                            compSize = readI64(bytePtr, fieldOffset)
                            fieldOffset += 8
                        }
                        if relOffset == 0xFFFFFFFF && fieldOffset + 8 <= extraEnd {
                            relOffset = readI64(bytePtr, fieldOffset)
                        }
                    } else if headerId == 0x9901 && dataSize >= 7 { // WinZip AES Extra Field
                        let aesStrength = bytePtr[extraPos + 8]
                        let actualMethod = readU16(bytePtr, extraPos + 9)
                        method = actualMethod
                        switch aesStrength {
                        case 1: encryption = .aes128
                        case 2: encryption = .aes192
                        case 3: encryption = .aes256
                        default: encryption = .aes256
                        }
                    }
                    extraPos += 4 + dataSize
                }
            }
            
            let isDir = rawPath.hasSuffix("/") || ((extAttr & 0x10) != 0)
            let cleanPath = sanitizePath(rawPath)
            
            if !skipMacJunk || !isMacJunk(cleanPath) {
                descriptors.append(ZipEntryDescriptor(
                    path: cleanPath,
                    uncompressedSize: uncompSize,
                    compressedSize: compSize,
                    lfhOffset: relOffset,
                    crc32: crc,
                    compressionMethod: method,
                    isDirectory: isDir,
                    isEncrypted: isEncrypted,
                    encryptionMethod: encryption
                ))
            }
            
            currPos += recLen
        }
        
        return descriptors
    }
    
    private func sanitizePath(_ raw: String) -> String {
        var clean = raw.replacingOccurrences(of: "\\", with: "/")
        while clean.hasPrefix("/") || clean.hasPrefix("./") {
            if clean.hasPrefix("/") { clean = String(clean.dropFirst()) }
            else if clean.hasPrefix("./") { clean = String(clean.dropFirst(2)) }
        }
        if !SecurityScanner.isPathSafe(clean) {
            clean = SecurityScanner.sanitizePath(clean) ?? "unnamed"
        }
        return clean.isEmpty ? "unnamed" : clean
    }
    
    private func isMacJunk(_ path: String) -> Bool {
        if path.contains(".DS_Store") || path.contains("__MACOSX") || path.contains("Thumbs.db") || path.contains(".Spotlight-V100") || path.contains(".Trashes") {
            return true
        }
        let filename = (path as NSString).lastPathComponent
        if filename.hasPrefix("._") { return true }
        return false
    }
}
