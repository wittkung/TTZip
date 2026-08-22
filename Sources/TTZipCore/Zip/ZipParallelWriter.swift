// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Multi-threaded parallel ZIP archive creation engine powered by libdeflate,
/// dynamic entropy bypass, ZIP64 support, and optional WinZip AES-256 encryption.
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
        
        ConcurrencyBridge.parallelFor(iterations: captureItems.count) { idx in
            let item = captureItems[idx]
            if item.isDirectory {
                let dirPath = item.relPath.hasSuffix("/") ? item.relPath : item.relPath + "/"
                compressedResultsBox.set(idx: idx, res: CompressedResult(
                    relPath: dirPath, isDirectory: true, uncompressedSize: 0,
                    compressedSize: 0, crc32: 0, compressionMethod: 0,
                    payload: Data(), aesExtraField: nil
                ))
                return
            }
            
            guard let rawData = try? Data(contentsOf: URL(fileURLWithPath: item.srcPath), options: .alwaysMapped) else { return }
            let uncompSize = Int64(rawData.count)
            
            let crc: UInt32
            if password != nil && !password!.isEmpty {
                crc = 0 // WinZip AES-256 specification requires CRC32 to be set to 0 in local header
            } else {
                crc = rawData.withUnsafeBytes { ptr -> UInt32 in
                    guard let base = ptr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                    return ttzip_rust_crc32(0, base, rawData.count)
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
                
                var outLen: Int = 0
                let status = rawData.withUnsafeBytes { inPtr -> CTTZipBridge.TTZipStatus in
                    guard let src = inPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return TTZIP_STATUS_ERR_INVALID_PARAM }
                    return ttzip_rust_deflate_compress(src, rawData.count, dstPtr, maxCap, Int32(libdeflateLevel), &outLen)
                }
                let compSize = (status == TTZIP_STATUS_OK) ? outLen : 0
                
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
            let fnLen = UInt16(pathData.count)
            let needsZip64 = cdfh.uncompressedSize >= 0xFFFFFFFF || cdfh.compressedSize >= 0xFFFFFFFF || cdfh.offset >= 0xFFFFFFFF
            
            var record = Data()
            var extraData = Data()
            
            if needsZip64 {
                let extraHeaderId: UInt16 = 0x0001
                let extraDataLen: UInt16 = 24
                let uSize64: Int64 = cdfh.uncompressedSize
                let cSize64: Int64 = cdfh.compressedSize
                let off64: Int64 = cdfh.offset
                
                withUnsafeBytes(of: extraHeaderId) { extraData.append(contentsOf: $0) }
                withUnsafeBytes(of: extraDataLen) { extraData.append(contentsOf: $0) }
                withUnsafeBytes(of: uSize64) { extraData.append(contentsOf: $0) }
                withUnsafeBytes(of: cSize64) { extraData.append(contentsOf: $0) }
                withUnsafeBytes(of: off64) { extraData.append(contentsOf: $0) }
            }
            if let aesExtra = cdfh.aesExtraField {
                extraData.append(aesExtra)
            }
            
            let sig: UInt32 = 0x02014b50
            let verMade: UInt16 = 45
            let verNeed: UInt16 = 20
            let flag: UInt16 = cdfh.aesExtraField != nil ? 0x0801 : 0x0800
            let method: UInt16 = cdfh.compressionMethod
            let time: UInt16 = 0
            let date: UInt16 = 0x5421
            let crc: UInt32 = cdfh.crc32
            let compSize32: UInt32 = needsZip64 ? 0xFFFFFFFF : UInt32(cdfh.compressedSize)
            let uncompSize32: UInt32 = needsZip64 ? 0xFFFFFFFF : UInt32(cdfh.uncompressedSize)
            let extraLen: UInt16 = UInt16(extraData.count)
            let commentLen: UInt16 = 0
            let diskStart: UInt16 = 0
            let internalAttr: UInt16 = 0
            let externalAttr: UInt32 = cdfh.isDirectory ? 0x10 : 0x20
            let localHeaderOff32: UInt32 = needsZip64 ? 0xFFFFFFFF : UInt32(cdfh.offset)
            
            withUnsafeBytes(of: sig) { record.append(contentsOf: $0) }
            withUnsafeBytes(of: verMade) { record.append(contentsOf: $0) }
            withUnsafeBytes(of: verNeed) { record.append(contentsOf: $0) }
            withUnsafeBytes(of: flag) { record.append(contentsOf: $0) }
            withUnsafeBytes(of: method) { record.append(contentsOf: $0) }
            withUnsafeBytes(of: time) { record.append(contentsOf: $0) }
            withUnsafeBytes(of: date) { record.append(contentsOf: $0) }
            withUnsafeBytes(of: crc) { record.append(contentsOf: $0) }
            withUnsafeBytes(of: compSize32) { record.append(contentsOf: $0) }
            withUnsafeBytes(of: uncompSize32) { record.append(contentsOf: $0) }
            withUnsafeBytes(of: fnLen) { record.append(contentsOf: $0) }
            withUnsafeBytes(of: extraLen) { record.append(contentsOf: $0) }
            withUnsafeBytes(of: commentLen) { record.append(contentsOf: $0) }
            withUnsafeBytes(of: diskStart) { record.append(contentsOf: $0) }
            withUnsafeBytes(of: internalAttr) { record.append(contentsOf: $0) }
            withUnsafeBytes(of: externalAttr) { record.append(contentsOf: $0) }
            withUnsafeBytes(of: localHeaderOff32) { record.append(contentsOf: $0) }
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
            var z64Record = Data()
            let z64EocdSig: UInt32 = 0x06064b50
            let z64EocdSize: UInt64 = 44
            let verMade: UInt16 = 45
            let verNeed: UInt16 = 45
            let diskNum: UInt32 = 0
            let cdStartDisk: UInt32 = 0
            let entriesOnDisk: UInt64 = UInt64(cdfhEntries.count)
            let totalEntries: UInt64 = UInt64(cdfhEntries.count)
            let cdSize64: UInt64 = UInt64(cdSize)
            let cdOff64: UInt64 = UInt64(cdStartOffset)
            
            withUnsafeBytes(of: z64EocdSig) { z64Record.append(contentsOf: $0) }
            withUnsafeBytes(of: z64EocdSize) { z64Record.append(contentsOf: $0) }
            withUnsafeBytes(of: verMade) { z64Record.append(contentsOf: $0) }
            withUnsafeBytes(of: verNeed) { z64Record.append(contentsOf: $0) }
            withUnsafeBytes(of: diskNum) { z64Record.append(contentsOf: $0) }
            withUnsafeBytes(of: cdStartDisk) { z64Record.append(contentsOf: $0) }
            withUnsafeBytes(of: entriesOnDisk) { z64Record.append(contentsOf: $0) }
            withUnsafeBytes(of: totalEntries) { z64Record.append(contentsOf: $0) }
            withUnsafeBytes(of: cdSize64) { z64Record.append(contentsOf: $0) }
            withUnsafeBytes(of: cdOff64) { z64Record.append(contentsOf: $0) }
            writeBuffer.append(z64Record)
            
            var locatorData = Data()
            let locatorSig: UInt32 = 0x07064b50
            let locatorDisk: UInt32 = 0
            let locatorOff: UInt64 = UInt64(z64EocdOff)
            let totalDisks: UInt32 = 1
            
            withUnsafeBytes(of: locatorSig) { locatorData.append(contentsOf: $0) }
            withUnsafeBytes(of: locatorDisk) { locatorData.append(contentsOf: $0) }
            withUnsafeBytes(of: locatorOff) { locatorData.append(contentsOf: $0) }
            withUnsafeBytes(of: totalDisks) { locatorData.append(contentsOf: $0) }
            writeBuffer.append(locatorData)
        }
        var eocd = Data()
        let eocdSig: UInt32 = 0x06054b50
        let diskNo: UInt16 = 0
        let cdDiskNo: UInt16 = 0
        let entriesDisk: UInt16 = needsZip64Global ? 0xFFFF : UInt16(min(0xFFFF, cdfhEntries.count))
        let entriesTotal: UInt16 = needsZip64Global ? 0xFFFF : UInt16(min(0xFFFF, cdfhEntries.count))
        let cdSize32: UInt32 = needsZip64Global ? 0xFFFFFFFF : UInt32(cdSize)
        let cdOff32: UInt32 = needsZip64Global ? 0xFFFFFFFF : UInt32(cdStartOffset)
        let commentLen: UInt16 = 0
        withUnsafeBytes(of: eocdSig) { eocd.append(contentsOf: $0) }
        withUnsafeBytes(of: diskNo) { eocd.append(contentsOf: $0) }
        withUnsafeBytes(of: cdDiskNo) { eocd.append(contentsOf: $0) }
        withUnsafeBytes(of: entriesDisk) { eocd.append(contentsOf: $0) }
        withUnsafeBytes(of: entriesTotal) { eocd.append(contentsOf: $0) }
        withUnsafeBytes(of: cdSize32) { eocd.append(contentsOf: $0) }
        withUnsafeBytes(of: cdOff32) { eocd.append(contentsOf: $0) }
        withUnsafeBytes(of: commentLen) { eocd.append(contentsOf: $0) }
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
            currentFileName: "ZIP archive creation completed",
            throughputMBs: throughput
        ))
        return true
    }
}
