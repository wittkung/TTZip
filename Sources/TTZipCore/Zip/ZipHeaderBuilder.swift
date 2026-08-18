// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Builder constructing binary Local File Header (LFH) records for ZIP files.
public enum ZipHeaderBuilder {
    public struct LocalHeaderResult {
        public let headerData: Data
        public let needsZip64: Bool
    }
    
    /// Constructs binary Local File Header record.
    public static func buildLocalFileHeader(
        relPath: String,
        uncompressedSize: Int64,
        compressedSize: Int64,
        crc32: UInt32,
        compressionMethod: UInt16,
        currentOffset: Int64,
        aesExtraField: Data?
    ) -> LocalHeaderResult {
        let pathData = Data(relPath.utf8)
        var fnLen = UInt16(pathData.count)
        let needsZip64 = uncompressedSize >= 0xFFFFFFFF || compressedSize >= 0xFFFFFFFF || currentOffset >= 0xFFFFFFFF
        
        var lfh = Data()
        var sig: UInt32 = 0x04034b50
        var ver: UInt16 = needsZip64 ? 45 : 20
        var flag: UInt16 = 0x0800 // UTF-8
        var method: UInt16 = compressionMethod
        var time: UInt16 = 0
        var date: UInt16 = 0x5421
        var crc: UInt32 = crc32
        var compSize32: UInt32 = needsZip64 ? 0xFFFFFFFF : UInt32(compressedSize)
        var uncompSize32: UInt32 = needsZip64 ? 0xFFFFFFFF : UInt32(uncompressedSize)
        
        var extraData = Data()
        if needsZip64 {
            var extraHeaderId: UInt16 = 0x0001
            var extraDataLen: UInt16 = 16
            var uSize64: Int64 = uncompressedSize
            var cSize64: Int64 = compressedSize
            
            extraData.append(Data(bytes: &extraHeaderId, count: 2))
            extraData.append(Data(bytes: &extraDataLen, count: 2))
            extraData.append(Data(bytes: &uSize64, count: 8))
            extraData.append(Data(bytes: &cSize64, count: 8))
        }
        if let aesExtra = aesExtraField {
            extraData.append(aesExtra)
            flag |= 0x0001
        }
        
        var extraLen: UInt16 = UInt16(extraData.count)
        
        lfh.append(Data(bytes: &sig, count: 4))
        lfh.append(Data(bytes: &ver, count: 2))
        lfh.append(Data(bytes: &flag, count: 2))
        lfh.append(Data(bytes: &method, count: 2))
        lfh.append(Data(bytes: &time, count: 2))
        lfh.append(Data(bytes: &date, count: 2))
        lfh.append(Data(bytes: &crc, count: 4))
        lfh.append(Data(bytes: &compSize32, count: 4))
        lfh.append(Data(bytes: &uncompSize32, count: 4))
        lfh.append(Data(bytes: &fnLen, count: 2))
        lfh.append(Data(bytes: &extraLen, count: 2))
        lfh.append(pathData)
        if !extraData.isEmpty { lfh.append(extraData) }
        
        return LocalHeaderResult(headerData: lfh, needsZip64: needsZip64)
    }
}
