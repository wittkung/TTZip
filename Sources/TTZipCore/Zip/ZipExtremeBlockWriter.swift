// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-performance multi-core block-parallel ZIP archive creation engine.
///
/// Partitions large single files into 512KB ~ 1MB chunks and compresses them
/// concurrently across all available Apple Silicon CPU cores with RFC 1951
/// sync markers (0x00, 0x00, 0xFF, 0xFF) and standard PKWARE Method 8 headers.
public final class ZipExtremeBlockWriter: @unchecked Sendable {
    public static let shared = ZipExtremeBlockWriter()
    
    public static let defaultBlockSize: Int = 1024 * 1024 // 1 MB per chunk
    
    private init() {}
    
    /// Creates a ZIP archive using multi-core block parallelism for large files.
    public func createExtremeArchive(
        outputPath: String,
        inputPath: String,
        level: ArchiveCompressionLevel = .fastest,
        blockSize: Int = 0 // 0 = 基于香农熵与硬件缓存自适应推导
    ) throws -> Bool {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: inputPath) else { return false }
        
        let attrs = try fileManager.attributesOfItem(atPath: inputPath)
        guard let fileSize = attrs[.size] as? Int64, fileSize > 0 else {
            // Empty file or directory: fallback to standard zip writer
            return try ZipParallelWriter.shared.createArchive(outputPath: outputPath, inputPaths: [inputPath], level: level)
        }
        
        let rawData = try Data(contentsOf: URL(fileURLWithPath: inputPath), options: .alwaysMapped)
        let uncompressedBytes = Int64(rawData.count)
        
        // 0. 香农熵与试探可压缩性快速探测 (Microsecond SIMD Prober)
        var entropyVal: Double = 0.0
        var estimatedRatio: Double = 1.0
        let routingMethod: Int32 = rawData.withUnsafeBytes { rawIn -> Int32 in
            guard let baseAddr = rawIn.baseAddress else { return 8 }
            return Int32(ttzip_probe_entropy_and_compressibility(baseAddr, rawData.count, 4096, &entropyVal, &estimatedRatio))
        }
        
        let isDirectStore = (routingMethod == 0)
        let compressionMethod: UInt16 = isDirectStore ? 0 : 8
        
        // 1. 计算全局 CRC-32 (使用 Apple NEON SIMD 硬件指令)
        let totalCrc32: UInt32 = rawData.withUnsafeBytes { ptr -> UInt32 in
            guard let base = ptr.baseAddress else { return 0 }
            return ttzip_compute_buffer_crc32(base, rawData.count)
        }
        
        let compressedPayload: Data
        let totalCompressedBytes: Int64
        
        if isDirectStore {
            // Direct Store (Method 0): 高熵数据零拷贝直通！
            compressedPayload = rawData
            totalCompressedBytes = uncompressedBytes
        } else {
            // 2. 基于熵与缓存拓扑的自适应分块多核并发压缩 (18 核心饱和调度)
            let adaptiveSize = ttzip_calculate_adaptive_block_size(entropyVal, rawData.count)
            let levelChunkMultiplier: Int = level.rawValue >= 9 ? 4 : (level.rawValue >= 6 ? 2 : 1)
            let baseBlockSize = blockSize > 0 ? max(65536, blockSize) : (adaptiveSize > 0 ? adaptiveSize : 524288)
            let actualBlockSize = min(rawData.count, max(65536, baseBlockSize * levelChunkMultiplier))
            let totalBlocks = (rawData.count + actualBlockSize - 1) / actualBlockSize
            let libdeflateLevel = Int32(min(12, max(1, level.rawValue)))
            
            struct RawBlockBuffer: @unchecked Sendable {
                let ptr: UnsafeMutablePointer<UInt8>
                let size: Int
                let isAllocated: Bool
            }
            
            let resultsBox = StateBoxResults([RawBlockBuffer?](repeating: nil, count: totalBlocks))
            
            rawData.withUnsafeBytes { rawIn in
                guard let baseAddr = rawIn.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
                let ptrBox = SendablePointerBox(pointer: baseAddr, size: rawData.count)
                
                DispatchQueue.concurrentPerform(iterations: totalBlocks) { blockIdx in
                    let offset = blockIdx * actualBlockSize
                    let currentChunkSize = min(actualBlockSize, ptrBox.size - offset)
                    let chunkPtr = ptrBox.pointer.advanced(by: offset)
                    let isFinal = (blockIdx == totalBlocks - 1)
                    
                    let dictPtr: UnsafePointer<UInt8>?
                    let dictSize: Int
                    if offset > 0 {
                        let overlap = min(32768, offset)
                        dictPtr = ptrBox.pointer.advanced(by: offset - overlap)
                        dictSize = overlap
                    } else {
                        dictPtr = nil
                        dictSize = 0
                    }
                    
                    let maxOut = currentChunkSize + 512
                    let outBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: maxOut)
                    
                    let compSize = ttzip_raw_deflate_block_compress_with_dict(
                        chunkPtr,
                        currentChunkSize,
                        dictPtr,
                        dictSize,
                        outBuf,
                        maxOut,
                        libdeflateLevel,
                        isFinal
                    )
                    
                    if compSize > 0 && compSize < currentChunkSize {
                        resultsBox.set(idx: blockIdx, res: RawBlockBuffer(ptr: outBuf, size: compSize, isAllocated: true))
                    } else {
                        // Incompressible fallback
                        outBuf.deallocate()
                        let fallbackBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: currentChunkSize)
                        memcpy(fallbackBuf, chunkPtr, currentChunkSize)
                        resultsBox.set(idx: blockIdx, res: RawBlockBuffer(ptr: fallbackBuf, size: currentChunkSize, isAllocated: true))
                    }
                }
            }
            
            // 3. 顺序组装压缩载荷 (单次预分配零重分配)
            var totalComp: Int = 0
            for idx in 0..<totalBlocks {
                if let buf = resultsBox.values[idx] {
                    totalComp += buf.size
                }
            }
            
            var payload = Data()
            payload.reserveCapacity(totalComp)
            for idx in 0..<totalBlocks {
                guard let buf = resultsBox.values[idx] else { return false }
                payload.append(buf.ptr, count: buf.size)
                if buf.isAllocated {
                    buf.ptr.deallocate()
                }
            }
            compressedPayload = payload
            totalCompressedBytes = Int64(totalComp)
        }
        
        // 4. 构建标准 PKWARE ZIP 容器 (Local File Header + Central Directory + EOCD)
        let fileName = URL(fileURLWithPath: inputPath).lastPathComponent
        guard let nameData = fileName.data(using: .utf8) else { return false }
        let nameLen = UInt16(nameData.count)
        
        let outUrl = URL(fileURLWithPath: outputPath)
        try? fileManager.removeItem(at: outUrl)
        fileManager.createFile(atPath: outputPath, contents: nil)
        guard let fileHandle = try? FileHandle(forWritingTo: outUrl) else { return false }
        defer { try? fileHandle.close() }
        
        // --- A. Local File Header ---
        var lfh = Data()
        lfh.append(contentsOf: [0x50, 0x4B, 0x03, 0x04]) // Signature: 0x04034B50
        lfh.append(contentsOf: [0x2D, 0x00])             // Version needed: 4.5 (ZIP64 capable)
        lfh.append(contentsOf: [0x00, 0x08])             // General purpose: UTF-8 bit 11 set (0x0800)
        var compMethodVal = compressionMethod
        lfh.append(Data(bytes: &compMethodVal, count: 2)) // Compression method: 0 (Store) or 8 (Deflate)
        lfh.append(contentsOf: [0x00, 0x00, 0x21, 0x54]) // Modification time/date
        
        var crcVal = totalCrc32
        lfh.append(Data(bytes: &crcVal, count: 4))
        
        let isZip64 = uncompressedBytes >= 0xFFFFFFFF || totalCompressedBytes >= 0xFFFFFFFF
        var compSize32: UInt32 = isZip64 ? 0xFFFFFFFF : UInt32(totalCompressedBytes)
        var uncompSize32: UInt32 = isZip64 ? 0xFFFFFFFF : UInt32(uncompressedBytes)
        lfh.append(Data(bytes: &compSize32, count: 4))
        lfh.append(Data(bytes: &uncompSize32, count: 4))
        
        var nameLenVal = nameLen
        lfh.append(Data(bytes: &nameLenVal, count: 2))
        
        var extraLenVal: UInt16 = isZip64 ? 20 : 0
        lfh.append(Data(bytes: &extraLenVal, count: 2))
        lfh.append(nameData)
        
        if isZip64 {
            var tag: UInt16 = 0x0001
            var tagSize: UInt16 = 16
            var uSize = UInt64(uncompressedBytes)
            var cSize = UInt64(totalCompressedBytes)
            lfh.append(Data(bytes: &tag, count: 2))
            lfh.append(Data(bytes: &tagSize, count: 2))
            lfh.append(Data(bytes: &uSize, count: 8))
            lfh.append(Data(bytes: &cSize, count: 8))
        }
        
        try fileHandle.write(contentsOf: lfh)
        
        // --- B. Payload ---
        try fileHandle.write(contentsOf: compressedPayload)
        
        let cdOffset = UInt64(lfh.count + compressedPayload.count)
        
        // --- C. Central Directory Header ---
        var cd = Data()
        cd.append(contentsOf: [0x50, 0x4B, 0x01, 0x02]) // Central Directory Signature: 0x02014B50
        cd.append(contentsOf: [0x2D, 0x03])             // Version made by: UNIX (0x03) + v4.5 (0x2D)
        cd.append(contentsOf: [0x2D, 0x00])             // Version needed: 4.5
        cd.append(contentsOf: [0x00, 0x08])             // General purpose: UTF-8
        cd.append(Data(bytes: &compMethodVal, count: 2)) // Compression method: 0 (Store) or 8 (Deflate)
        cd.append(contentsOf: [0x00, 0x00, 0x21, 0x54]) // Mod time/date
        cd.append(Data(bytes: &crcVal, count: 4))
        cd.append(Data(bytes: &compSize32, count: 4))
        cd.append(Data(bytes: &uncompSize32, count: 4))
        cd.append(Data(bytes: &nameLenVal, count: 2))
        
        var cdExtraLenVal: UInt16 = isZip64 ? 28 : 0
        cd.append(Data(bytes: &cdExtraLenVal, count: 2)) // Extra field len
        cd.append(contentsOf: [0x00, 0x00])             // Comment len
        cd.append(contentsOf: [0x00, 0x00])             // Disk number start
        cd.append(contentsOf: [0x00, 0x00])             // Internal file attrs
        cd.append(contentsOf: [0x00, 0x00, 0xA4, 0x81]) // External file attrs (0644 regular file)
        
        var lfhOffset32: UInt32 = isZip64 ? 0xFFFFFFFF : 0
        cd.append(Data(bytes: &lfhOffset32, count: 4))
        cd.append(nameData)
        
        if isZip64 {
            var tag: UInt16 = 0x0001
            var tagSize: UInt16 = 24
            var uSize = UInt64(uncompressedBytes)
            var cSize = UInt64(totalCompressedBytes)
            var lfhOff = UInt64(0)
            cd.append(Data(bytes: &tag, count: 2))
            cd.append(Data(bytes: &tagSize, count: 2))
            cd.append(Data(bytes: &uSize, count: 8))
            cd.append(Data(bytes: &cSize, count: 8))
            cd.append(Data(bytes: &lfhOff, count: 8))
        }
        
        try fileHandle.write(contentsOf: cd)
        let cdSize = UInt64(cd.count)
        
        // --- D. End of Central Directory Record ---
        if isZip64 {
            let zip64EocdOffset = cdOffset + cdSize
            
            var zip64Eocd = Data()
            zip64Eocd.append(contentsOf: [0x50, 0x4B, 0x06, 0x06]) // ZIP64 EOCD Signature: 0x06064B50
            var eocdSize: UInt64 = 44
            var vMadeBy: UInt16 = 0x032D
            var vNeeded: UInt16 = 0x002D
            var diskNo: UInt32 = 0
            var cdDiskNo: UInt32 = 0
            var entriesOnDisk: UInt64 = 1
            var totalEntries: UInt64 = 1
            var cdSizeBytes = cdSize
            var cdOffBytes = cdOffset
            
            zip64Eocd.append(Data(bytes: &eocdSize, count: 8))
            zip64Eocd.append(Data(bytes: &vMadeBy, count: 2))
            zip64Eocd.append(Data(bytes: &vNeeded, count: 2))
            zip64Eocd.append(Data(bytes: &diskNo, count: 4))
            zip64Eocd.append(Data(bytes: &cdDiskNo, count: 4))
            zip64Eocd.append(Data(bytes: &entriesOnDisk, count: 8))
            zip64Eocd.append(Data(bytes: &totalEntries, count: 8))
            zip64Eocd.append(Data(bytes: &cdSizeBytes, count: 8))
            zip64Eocd.append(Data(bytes: &cdOffBytes, count: 8))
            
            try fileHandle.write(contentsOf: zip64Eocd)
            
            var zip64Locator = Data()
            zip64Locator.append(contentsOf: [0x50, 0x4B, 0x06, 0x07]) // Locator Signature: 0x07064B50
            var locatorDiskNo: UInt32 = 0
            var eocdOff = zip64EocdOffset
            var totalDisks: UInt32 = 1
            zip64Locator.append(Data(bytes: &locatorDiskNo, count: 4))
            zip64Locator.append(Data(bytes: &eocdOff, count: 8))
            zip64Locator.append(Data(bytes: &totalDisks, count: 4))
            
            try fileHandle.write(contentsOf: zip64Locator)
        }
        
        var eocd = Data()
        eocd.append(contentsOf: [0x50, 0x4B, 0x05, 0x06]) // EOCD Signature: 0x06054B50
        eocd.append(contentsOf: [0x00, 0x00])             // Disk number
        eocd.append(contentsOf: [0x00, 0x00])             // CD disk number
        
        var entryCount16: UInt16 = isZip64 ? 0xFFFF : 1
        var totalEntryCount16: UInt16 = isZip64 ? 0xFFFF : 1
        eocd.append(Data(bytes: &entryCount16, count: 2))
        eocd.append(Data(bytes: &totalEntryCount16, count: 2))
        
        var cdSize32: UInt32 = isZip64 ? 0xFFFFFFFF : UInt32(cdSize)
        var cdOffset32: UInt32 = isZip64 ? 0xFFFFFFFF : UInt32(cdOffset)
        eocd.append(Data(bytes: &cdSize32, count: 4))
        eocd.append(Data(bytes: &cdOffset32, count: 4))
        eocd.append(contentsOf: [0x00, 0x00])             // Comment length: 0
        
        try fileHandle.write(contentsOf: eocd)
        
        return true
    }
}
