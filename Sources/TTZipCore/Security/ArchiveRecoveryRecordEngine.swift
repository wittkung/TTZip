// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge
import zlib

/// High-level engine for embedding, detecting, and restoring archives using Reed-Solomon Recovery Records.
public final class ArchiveRecoveryRecordEngine: @unchecked Sendable {
    public static let shared = ArchiveRecoveryRecordEngine()
    
    public static let magicHeader: [UInt8] = [0x54, 0x54, 0x5A, 0x52] // "TTZR"
    public static let magicFooter: [UInt8] = [0x54, 0x54, 0x52, 0x43] // "TTRC"
    
    private init() {}
    
    @inline(__always)
    private static func computeCRC32(data: Data) -> UInt32 {
        data.withUnsafeBytes { raw in
            guard let ptr = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
            return UInt32(crc32(0, ptr, uInt(raw.count)))
        }
    }
    
    /// Appends a transparent Reed-Solomon recovery record trailer to an archive.
    @discardableResult
    public func appendRecoveryRecord(
        to archivePath: String,
        redundancyPercent: Double = 5.0,
        sliceSize: Int = 65536
    ) throws -> RecoveryRecordPayload {
        let fm = FileManager.default
        guard fm.fileExists(atPath: archivePath) else {
            throw ArchiveError.fileNotFound
        }
        
        let payloadData = try Data(contentsOf: URL(fileURLWithPath: archivePath))
        let payloadLength = Int64(payloadData.count)
        guard payloadLength > 0 else {
            throw ArchiveError.invalidFormat
        }
        
        // 1. Slice original payload into K chunks and compute per-slice CRC32
        let totalK = (payloadData.count + sliceSize - 1) / sliceSize
        var dataSlices = [Data]()
        var dataCRCs = [UInt32]()
        dataSlices.reserveCapacity(totalK)
        dataCRCs.reserveCapacity(totalK)
        
        for i in 0..<totalK {
            let start = i * sliceSize
            let end = min(start + sliceSize, payloadData.count)
            var slice = Data(payloadData[start..<end])
            if slice.count < sliceSize {
                slice.append(contentsOf: [UInt8](repeating: 0, count: sliceSize - slice.count))
            }
            dataSlices.append(slice)
            dataCRCs.append(Self.computeCRC32(data: slice))
        }
        
        // 2. Compute M parity slices
        let rawM = Int(ceil(Double(totalK) * (redundancyPercent / 100.0)))
        let totalM = max(1, min(rawM, totalK))
        
        let paritySlices = ReedSolomonFEC.encode(dataSlices: dataSlices, parityCount: totalM)
        
        // 3. Compute root SHA-256
        let rootHash = HashCalculator.calculateSHA256(data: payloadData) ?? ""
        
        // 4. Construct Recovery Header & Trailer
        var recoveryBlock = Data()
        recoveryBlock.append(contentsOf: Self.magicHeader)
        
        // Version 0x0100 (2B)
        var version: UInt16 = 0x0100
        recoveryBlock.append(Data(bytes: &version, count: 2))
        
        // SliceSize (4B)
        var sSize = UInt32(sliceSize)
        recoveryBlock.append(Data(bytes: &sSize, count: 4))
        
        // TotalK (2B)
        var kVal = UInt16(totalK)
        recoveryBlock.append(Data(bytes: &kVal, count: 2))
        
        // TotalM (2B)
        var mVal = UInt16(totalM)
        recoveryBlock.append(Data(bytes: &mVal, count: 2))
        
        // ProtectedPayloadLength (8B)
        var pLen = UInt64(payloadLength)
        recoveryBlock.append(Data(bytes: &pLen, count: 8))
        
        // RootHash (32B)
        let rootBytes = Array(rootHash.utf8)
        var hashBuffer = [UInt8](repeating: 0, count: 32)
        for i in 0..<min(32, rootBytes.count) {
            hashBuffer[i] = rootBytes[i]
        }
        recoveryBlock.append(contentsOf: hashBuffer)
        
        // 5. Append Data Slices CRCs table (totalK * 4 bytes)
        for crc in dataCRCs {
            var c = crc
            recoveryBlock.append(Data(bytes: &c, count: 4))
        }
        
        // 6. Append Parity Slices
        for (idx, pSlice) in paritySlices.enumerated() {
            var sliceIdx = UInt16(idx)
            recoveryBlock.append(Data(bytes: &sliceIdx, count: 2))
            var pCRC = Self.computeCRC32(data: pSlice)
            recoveryBlock.append(Data(bytes: &pCRC, count: 4))
            recoveryBlock.append(pSlice)
        }
        
        // 7. Append Footer Anchor
        recoveryBlock.append(contentsOf: Self.magicFooter)
        var totalBlockSize = UInt64(recoveryBlock.count + 8)
        recoveryBlock.append(Data(bytes: &totalBlockSize, count: 8))
        
        // Append directly to archive file
        let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: archivePath))
        defer { try? handle.close() }
        handle.seekToEndOfFile()
        try handle.write(contentsOf: recoveryBlock)
        
        return RecoveryRecordPayload(
            recoveryPercent: redundancyPercent,
            sliceSizeBytes: sliceSize,
            dataSlicesCount: totalK,
            paritySlicesCount: totalM,
            protectedPayloadLength: payloadLength,
            rootChecksum: rootHash,
            eccAlgorithm: "cauchy_rs_gf16"
        )
    }
    
    /// Inspects and parses recovery record metadata if present at the end of the archive.
    public func inspectRecoveryRecord(archivePath: String) -> RecoveryRecordPayload? {
        guard let handle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: archivePath)) else { return nil }
        defer { try? handle.close() }
        
        let fileSize = handle.seekToEndOfFile()
        guard fileSize >= 64 else { return nil }
        
        let footerScanSize = min(128, fileSize)
        handle.seek(toFileOffset: fileSize - footerScanSize)
        guard let footerData = try? handle.read(upToCount: Int(footerScanSize)) else { return nil }
        
        guard let footerRange = footerData.range(of: Data(Self.magicFooter)) else { return nil }
        let footerOffset = (fileSize - footerScanSize) + UInt64(footerRange.lowerBound)
        
        handle.seek(toFileOffset: footerOffset + 4)
        guard let sizeData = try? handle.read(upToCount: 8), sizeData.count == 8 else { return nil }
        let totalBlockSize = sizeData.withUnsafeBytes { $0.load(as: UInt64.self) }
        
        guard totalBlockSize < fileSize else { return nil }
        let headerOffset = fileSize - totalBlockSize
        
        handle.seek(toFileOffset: headerOffset)
        guard let headerData = try? handle.read(upToCount: 64), headerData.count >= 54 else { return nil }
        guard headerData.prefix(4) == Data(Self.magicHeader) else { return nil }
        
        let sliceSize = Int(headerData.subdata(in: 6..<10).withUnsafeBytes { $0.load(as: UInt32.self) })
        let totalK = Int(headerData.subdata(in: 10..<12).withUnsafeBytes { $0.load(as: UInt16.self) })
        let totalM = Int(headerData.subdata(in: 12..<14).withUnsafeBytes { $0.load(as: UInt16.self) })
        let payloadLen = Int64(headerData.subdata(in: 14..<22).withUnsafeBytes { $0.load(as: UInt64.self) })
        
        let hashData = headerData.subdata(in: 22..<54)
        let rootHash = String(decoding: hashData, as: UTF8.self).trimmingCharacters(in: .controlCharacters)
        let percent = totalK > 0 ? (Double(totalM) / Double(totalK)) * 100.0 : 5.0
        
        return RecoveryRecordPayload(
            recoveryPercent: percent,
            sliceSizeBytes: sliceSize,
            dataSlicesCount: totalK,
            paritySlicesCount: totalM,
            protectedPayloadLength: payloadLen,
            rootChecksum: rootHash,
            eccAlgorithm: "cauchy_rs_gf16"
        )
    }
    
    /// Verifies and performs self-healing restoration on a corrupted archive file.
    public func repairArchive(archivePath: String) throws -> Bool {
        guard let payload = inspectRecoveryRecord(archivePath: archivePath) else {
            return false
        }
        
        let fileData = try Data(contentsOf: URL(fileURLWithPath: archivePath))
        let payloadLen = Int(payload.protectedPayloadLength)
        let originalPayload = Data(fileData.prefix(payloadLen))
        let currentHash = HashCalculator.calculateSHA256(data: originalPayload) ?? ""
        
        if currentHash == payload.rootChecksum {
            return true // Already 100% intact
        }
        
        let K = payload.dataSlicesCount
        let M = payload.paritySlicesCount
        let sliceSize = payload.sliceSizeBytes
        
        let totalBlockSize = Int(fileData.count) - payloadLen
        let recoveryBlock = Data(fileData.suffix(totalBlockSize))
        guard recoveryBlock.count >= 54 + (K * 4) else { return false }
        
        // 1. Read Expected Data Slice CRCs
        var expectedDataCRCs = [UInt32]()
        expectedDataCRCs.reserveCapacity(K)
        for i in 0..<K {
            let offset = 54 + (i * 4)
            let crcVal = recoveryBlock.subdata(in: offset..<(offset + 4)).withUnsafeBytes { $0.load(as: UInt32.self) }
            expectedDataCRCs.append(crcVal)
        }
        
        // 2. Classify intact vs corrupted data slices
        var intactSlices = [Int: Data]()
        for i in 0..<K {
            let start = i * sliceSize
            let end = min(start + sliceSize, payloadLen)
            var slice = Data(originalPayload[start..<end])
            if slice.count < sliceSize {
                slice.append(contentsOf: [UInt8](repeating: 0, count: sliceSize - slice.count))
            }
            let actualCRC = Self.computeCRC32(data: slice)
            if actualCRC == expectedDataCRCs[i] {
                intactSlices[i] = slice
            }
        }
        
        // 3. Read and verify Parity Slices
        var pOffset = 54 + (K * 4)
        for pIdx in 0..<M {
            if pOffset + 6 + sliceSize <= recoveryBlock.count {
                let pExpectedCRC = recoveryBlock.subdata(in: (pOffset + 2)..<(pOffset + 6)).withUnsafeBytes { $0.load(as: UInt32.self) }
                let pSlice = Data(recoveryBlock[(pOffset + 6)..<(pOffset + 6 + sliceSize)])
                let pActualCRC = Self.computeCRC32(data: pSlice)
                if pActualCRC == pExpectedCRC {
                    intactSlices[K + pIdx] = pSlice
                }
                pOffset += 6 + sliceSize
            }
        }
        
        // 4. Execute Cauchy RS decode
        if let reconstructed = ReedSolomonFEC.decode(
            intactSlices: intactSlices,
            totalK: K,
            totalM: M,
            sliceSize: sliceSize
        ) {
            var repairedPayload = Data()
            repairedPayload.reserveCapacity(K * sliceSize)
            for i in 0..<K {
                if let s = reconstructed[i] {
                    repairedPayload.append(s)
                }
            }
            let truncatedRepaired = Data(repairedPayload.prefix(payloadLen))
            
            // Re-append recovery record trailer
            var fullRepairedFile = truncatedRepaired
            fullRepairedFile.append(recoveryBlock)
            try fullRepairedFile.write(to: URL(fileURLWithPath: archivePath))
            return true
        }
        
        return false
    }
}
