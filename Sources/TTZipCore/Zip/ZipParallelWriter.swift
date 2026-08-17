import Foundation
import CTTZipBridge

/// 全核并发 LIBDEFLATE 极速 ZIP 打包压缩引擎
public final class ZipParallelWriter: @unchecked Sendable {
    public static let shared = ZipParallelWriter()
    
    private init() {}
    
    public func createArchive(
        outputPath: String,
        inputPaths: [String],
        level: ArchiveCompressionLevel = .normal,
        skipMacJunk: Bool = true,
        password: String? = nil,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        let captureItems = ZipDirectoryScanner.scan(inputPaths: inputPaths, skipMacJunk: skipMacJunk)
        
        struct CompressedResult: Sendable {
            let relPath: String
            let isDirectory: Bool
            let uncompressedSize: Int64
            let compressedSize: Int64
            let crc32: UInt32
            let compressionMethod: UInt16
            let payload: Data
            let aesExtraField: Data?
        }
        
        let totalOriginalBytes = captureItems.reduce(0) { $0 + $1.fileSize }
        let compressedResultsBox = StateBoxResults([CompressedResult?](repeating: nil, count: captureItems.count))
        let libdeflateLevel: Int32 = Int32(min(12, max(0, level.rawValue)))
        
        let startTime = Date()
        let processedBytesBox = StateBoxInt64(0)
        let lock = NSLock()
        
        DispatchQueue.concurrentPerform(iterations: captureItems.count) { idx in
            let item = captureItems[idx]
            if item.isDirectory {
                let dirPath = item.relPath.hasSuffix("/") ? item.relPath : item.relPath + "/"
                let res = CompressedResult(
                    relPath: dirPath,
                    isDirectory: true,
                    uncompressedSize: 0,
                    compressedSize: 0,
                    crc32: 0,
                    compressionMethod: 0,
                    payload: Data(),
                    aesExtraField: nil
                )
                compressedResultsBox.set(idx: idx, res: res)
                return
            }
            
            guard let rawData = try? Data(contentsOf: URL(fileURLWithPath: item.srcPath), options: .alwaysMapped) else { return }
            let uncompSize = Int64(rawData.count)
            
            let crc: UInt32
            if password != nil && !password!.isEmpty {
                crc = 0 // WinZip AES-256 规范强制要求 CRC32 设为 0
            } else {
                crc = rawData.withUnsafeBytes { ptr -> UInt32 in
                    guard let base = ptr.baseAddress else { return 0 }
                    return ttzip_compute_buffer_crc32(base, rawData.count)
                }
            }
            
            var method: UInt16 = 8 // Deflate
            var payloadData = Data()
            
            let isHighEntropy: Bool = ArchiveEntropyEvaluator.shouldBypassCompression(data: rawData)
            
            if level == .store || rawData.count == 0 || isHighEntropy {
                method = 0 // Store
                payloadData = rawData
            } else {
                let maxCap = rawData.count + 512
                let dstPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: maxCap)
                defer { dstPtr.deallocate() }
                
                let compSize = rawData.withUnsafeBytes { inPtr -> size_t in
                    guard let src = inPtr.baseAddress else { return 0 }
                    return ttzip_libdeflate_compress(src, rawData.count, dstPtr, maxCap, Int32(libdeflateLevel))
                }
                
                if compSize > 0 && compSize < rawData.count {
                    payloadData = Data(bytes: dstPtr, count: compSize)
                } else {
                    method = 0
                    payloadData = rawData
                }
            }
            
            var aesExtra: Data? = nil
            if let pwd = password, !pwd.isEmpty {
                if let enc = ZipCryptoEngine.shared.encryptAES256(payload: payloadData, password: pwd, actualCompressionMethod: method) {
                    payloadData = enc.payload
                    method = enc.compressionMethod
                    aesExtra = enc.extraField
                }
            }
            
            let res = CompressedResult(
                relPath: item.relPath,
                isDirectory: false,
                uncompressedSize: uncompSize,
                compressedSize: Int64(payloadData.count),
                crc32: crc,
                compressionMethod: method,
                payload: payloadData,
                aesExtraField: aesExtra
            )
            compressedResultsBox.set(idx: idx, res: res)
            
            lock.lock()
            processedBytesBox.value += uncompSize
            let currentProcessed = processedBytesBox.value
            let elapsed = max(0.01, Date().timeIntervalSince(startTime))
            let throughput = (Double(currentProcessed) / (1024 * 1024)) / elapsed
            progressHandler?(ArchiveProgress(
                state: .processing,
                bytesProcessed: currentProcessed,
                totalBytes: totalOriginalBytes,
                currentFileName: item.relPath,
                throughputMBs: throughput
            ))
            lock.unlock()
        }
        
        let validResults = compressedResultsBox.values.compactMap { $0 }
        if validResults.count != captureItems.count { return false }
        
        let fm = FileManager.default
        try? fm.removeItem(atPath: outputPath)
        fm.createFile(atPath: outputPath, contents: nil)
        guard let outHandle = FileHandle(forWritingAtPath: outputPath) else { return false }
        defer { try? outHandle.close() }
        
        struct CDFHEntry: Sendable {
            let relPath: String
            let isDirectory: Bool
            let uncompressedSize: Int64
            let compressedSize: Int64
            let crc32: UInt32
            let compressionMethod: UInt16
            let offset: Int64
            let aesExtraField: Data?
        }
        
        var cdfhEntries: [CDFHEntry] = []
        var currentOffset: Int64 = 0
        
        var writeBuffer = Data()
        writeBuffer.reserveCapacity(1024 * 1024)
        
        for res in validResults {
            let lfhRes = ZipHeaderBuilder.buildLocalFileHeader(
                relPath: res.relPath,
                uncompressedSize: res.uncompressedSize,
                compressedSize: res.compressedSize,
                crc32: res.crc32,
                compressionMethod: res.compressionMethod,
                currentOffset: currentOffset,
                aesExtraField: res.aesExtraField
            )
            
            writeBuffer.append(lfhRes.headerData)
            if !res.payload.isEmpty {
                writeBuffer.append(res.payload)
            }
            if writeBuffer.count >= 1024 * 1024 {
                outHandle.write(writeBuffer)
                writeBuffer.removeAll(keepingCapacity: true)
            }
            
            cdfhEntries.append(CDFHEntry(
                relPath: res.relPath,
                isDirectory: res.isDirectory,
                uncompressedSize: res.uncompressedSize,
                compressedSize: res.compressedSize,
                crc32: res.crc32,
                compressionMethod: res.compressionMethod,
                offset: currentOffset,
                aesExtraField: res.aesExtraField
            ))
            
            currentOffset += Int64(lfhRes.headerData.count + res.payload.count)
        }
        
        let cdStartOffset = currentOffset
        var cdSize: Int64 = 0
        
        for cdfh in cdfhEntries {
            let pathData = Data(cdfh.relPath.utf8)
            var fnLen = UInt16(pathData.count)
            let needsZip64 = cdfh.uncompressedSize >= 0xFFFFFFFF || cdfh.compressedSize >= 0xFFFFFFFF || cdfh.offset >= 0xFFFFFFFF
            
            var record = Data()
            var sig: UInt32 = 0x02014b50
            var verMade: UInt16 = 45
            var verNeed: UInt16 = 20
            var flag: UInt16 = 0x0800
            var method: UInt16 = cdfh.compressionMethod
            var time: UInt16 = 0
            var date: UInt16 = 0x5421
            var crc: UInt32 = cdfh.crc32
            var compSize32: UInt32 = needsZip64 ? 0xFFFFFFFF : UInt32(cdfh.compressedSize)
            var uncompSize32: UInt32 = needsZip64 ? 0xFFFFFFFF : UInt32(cdfh.uncompressedSize)
            var extraData = Data()
            
            if needsZip64 {
                var extraHeaderId: UInt16 = 0x0001
                var extraDataLen: UInt16 = 24
                var uSize64: Int64 = cdfh.uncompressedSize
                var cSize64: Int64 = cdfh.compressedSize
                var off64: Int64 = cdfh.offset
                
                extraData.append(Data(bytes: &extraHeaderId, count: 2))
                extraData.append(Data(bytes: &extraDataLen, count: 2))
                extraData.append(Data(bytes: &uSize64, count: 8))
                extraData.append(Data(bytes: &cSize64, count: 8))
                extraData.append(Data(bytes: &off64, count: 8))
            }
            if let aesExtra = cdfh.aesExtraField {
                extraData.append(aesExtra)
                flag |= 0x0001
            }
            
            var extraLen: UInt16 = UInt16(extraData.count)
            var commentLen: UInt16 = 0
            var diskStart: UInt16 = 0
            var internalAttr: UInt16 = 0
            var externalAttr: UInt32 = cdfh.isDirectory ? 0x10 : 0x20
            var localHeaderOff32: UInt32 = needsZip64 ? 0xFFFFFFFF : UInt32(cdfh.offset)
            
            record.append(Data(bytes: &sig, count: 4))
            record.append(Data(bytes: &verMade, count: 2))
            record.append(Data(bytes: &verNeed, count: 2))
            record.append(Data(bytes: &flag, count: 2))
            record.append(Data(bytes: &method, count: 2))
            record.append(Data(bytes: &time, count: 2))
            record.append(Data(bytes: &date, count: 2))
            record.append(Data(bytes: &crc, count: 4))
            record.append(Data(bytes: &compSize32, count: 4))
            record.append(Data(bytes: &uncompSize32, count: 4))
            record.append(Data(bytes: &fnLen, count: 2))
            record.append(Data(bytes: &extraLen, count: 2))
            record.append(Data(bytes: &commentLen, count: 2))
            record.append(Data(bytes: &diskStart, count: 2))
            record.append(Data(bytes: &internalAttr, count: 2))
            record.append(Data(bytes: &externalAttr, count: 4))
            record.append(Data(bytes: &localHeaderOff32, count: 4))
            record.append(pathData)
            if !extraData.isEmpty { record.append(extraData) }
            
            writeBuffer.append(record)
            if writeBuffer.count >= 1024 * 1024 {
                outHandle.write(writeBuffer)
                writeBuffer.removeAll(keepingCapacity: true)
            }
            cdSize += Int64(record.count)
        }
        
        let needsZip64Global = cdStartOffset >= 0xFFFFFFFF || cdSize >= 0xFFFFFFFF || cdfhEntries.count >= 0xFFFF
        
        if needsZip64Global {
            let z64EocdOff = cdStartOffset + cdSize
            var z64EocdSig: UInt32 = 0x06064b50
            var z64EocdSize: UInt64 = 44
            var verMade: UInt16 = 45
            var verNeed: UInt16 = 45
            var diskNum: UInt32 = 0
            var cdStartDisk: UInt32 = 0
            var entriesOnDisk: UInt64 = UInt64(cdfhEntries.count)
            var totalEntries: UInt64 = UInt64(cdfhEntries.count)
            var cdSize64: UInt64 = UInt64(cdSize)
            var cdOff64: UInt64 = UInt64(cdStartOffset)
            
            var z64Record = Data()
            z64Record.append(Data(bytes: &z64EocdSig, count: 4))
            z64Record.append(Data(bytes: &z64EocdSize, count: 8))
            z64Record.append(Data(bytes: &verMade, count: 2))
            z64Record.append(Data(bytes: &verNeed, count: 2))
            z64Record.append(Data(bytes: &diskNum, count: 4))
            z64Record.append(Data(bytes: &cdStartDisk, count: 4))
            z64Record.append(Data(bytes: &entriesOnDisk, count: 8))
            z64Record.append(Data(bytes: &totalEntries, count: 8))
            z64Record.append(Data(bytes: &cdSize64, count: 8))
            z64Record.append(Data(bytes: &cdOff64, count: 8))
            writeBuffer.append(z64Record)
            
            var locatorSig: UInt32 = 0x07064b50
            var locatorDisk: UInt32 = 0
            var locatorOff: UInt64 = UInt64(z64EocdOff)
            var totalDisks: UInt32 = 1
            
            var locatorData = Data()
            locatorData.append(Data(bytes: &locatorSig, count: 4))
            locatorData.append(Data(bytes: &locatorDisk, count: 4))
            locatorData.append(Data(bytes: &locatorOff, count: 8))
            locatorData.append(Data(bytes: &totalDisks, count: 4))
            writeBuffer.append(locatorData)
        }
        
        var eocdSig: UInt32 = 0x06054b50
        var diskNo: UInt16 = 0
        var cdDiskNo: UInt16 = 0
        var entriesDisk: UInt16 = needsZip64Global ? 0xFFFF : UInt16(min(0xFFFF, cdfhEntries.count))
        var entriesTotal: UInt16 = needsZip64Global ? 0xFFFF : UInt16(min(0xFFFF, cdfhEntries.count))
        var cdSize32: UInt32 = needsZip64Global ? 0xFFFFFFFF : UInt32(cdSize)
        var cdOff32: UInt32 = needsZip64Global ? 0xFFFFFFFF : UInt32(cdStartOffset)
        var commentLen: UInt16 = 0
        
        var eocd = Data()
        eocd.append(Data(bytes: &eocdSig, count: 4))
        eocd.append(Data(bytes: &diskNo, count: 2))
        eocd.append(Data(bytes: &cdDiskNo, count: 2))
        eocd.append(Data(bytes: &entriesDisk, count: 2))
        eocd.append(Data(bytes: &entriesTotal, count: 2))
        eocd.append(Data(bytes: &cdSize32, count: 4))
        eocd.append(Data(bytes: &cdOff32, count: 4))
        eocd.append(Data(bytes: &commentLen, count: 2))
        writeBuffer.append(eocd)
        
        if !writeBuffer.isEmpty {
            outHandle.write(writeBuffer)
            writeBuffer.removeAll(keepingCapacity: true)
        }
        
        let endTime = Date()
        let duration = max(0.001, endTime.timeIntervalSince(startTime))
        let throughput = (Double(totalOriginalBytes) / (1024 * 1024)) / duration
        
        progressHandler?(ArchiveProgress(
            state: .completed,
            bytesProcessed: totalOriginalBytes,
            totalBytes: totalOriginalBytes,
            currentFileName: "ZIP 打包完成",
            throughputMBs: throughput
        ))
        
        return true
    }
}
