// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// In-memory POSIX UStar streaming converter for zero-copy tar/brotli piping.
enum BrotliTarStreamPipe {
    
    static func buildTarData(inputPaths: [String], skipMacJunk: Bool) throws -> Data {
        var tarData = Data()
        for inputPath in inputPaths {
            let inputURL = URL(fileURLWithPath: inputPath).standardizedFileURL
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: inputURL.path, isDirectory: &isDir) else { continue }
            
            let baseName = inputURL.lastPathComponent
            if isDir.boolValue {
                try appendDirectoryToTar(&tarData, dirURL: inputURL, relativePrefix: baseName, skipMacJunk: skipMacJunk)
            } else {
                if !skipMacJunk || !isMacJunk(name: baseName) {
                    try appendFileToTar(&tarData, fileURL: inputURL, entryPath: baseName)
                }
            }
        }
        tarData.append(Data(count: 1024))
        return tarData
    }

    private static func appendDirectoryToTar(_ tarData: inout Data, dirURL: URL, relativePrefix: String, skipMacJunk: Bool) throws {
        let baseDirPath = dirURL.standardizedFileURL.path
        if !skipMacJunk || !isMacJunk(name: relativePrefix) {
            let mtime = Int64((try? dirURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate?.timeIntervalSince1970 ?? Date().timeIntervalSince1970)
            let dirHeader = makeTarHeader(
                path: relativePrefix.hasSuffix("/") ? relativePrefix : "\(relativePrefix)/",
                size: 0,
                typeFlag: UInt8(ascii: "5"),
                mode: 0o755,
                mtime: mtime
            )
            tarData.append(dirHeader)
        }

        let enumerator = FileManager.default.enumerator(
            at: dirURL,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey],
            options: []
        )
        
        while let itemURL = enumerator?.nextObject() as? URL {
            let itemStandardURL = itemURL.standardizedFileURL
            let itemPath = itemStandardURL.path
            
            let subPath: String
            if itemPath.hasPrefix(baseDirPath + "/") {
                subPath = String(itemPath.dropFirst(baseDirPath.count + 1))
            } else if itemPath.hasPrefix(baseDirPath) {
                subPath = String(itemPath.dropFirst(baseDirPath.count))
            } else {
                subPath = itemURL.lastPathComponent
            }
            
            let entryPath = "\(relativePrefix)/\(subPath)"
            if skipMacJunk && isMacJunk(name: entryPath) { continue }
            
            let isItemDir = (try? itemStandardURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            let mtime = Int64((try? itemStandardURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate?.timeIntervalSince1970 ?? Date().timeIntervalSince1970)
            
            if isItemDir {
                let dirHeader = makeTarHeader(
                    path: entryPath.hasSuffix("/") ? entryPath : "\(entryPath)/",
                    size: 0,
                    typeFlag: UInt8(ascii: "5"),
                    mode: 0o755,
                    mtime: mtime
                )
                tarData.append(dirHeader)
            } else {
                let fileData = try Data(contentsOf: itemStandardURL)
                let header = makeTarHeader(
                    path: entryPath,
                    size: Int64(fileData.count),
                    typeFlag: UInt8(ascii: "0"),
                    mode: 0o644,
                    mtime: mtime
                )
                tarData.append(header)
                tarData.append(fileData)
                let pad = (512 - (fileData.count % 512)) % 512
                if pad > 0 {
                    tarData.append(Data(count: pad))
                }
            }
        }
    }

    private static func appendFileToTar(_ tarData: inout Data, fileURL: URL, entryPath: String) throws {
        let standardURL = fileURL.standardizedFileURL
        let fileData = try Data(contentsOf: standardURL)
        let mtime = Int64((try? standardURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate?.timeIntervalSince1970 ?? Date().timeIntervalSince1970)
        let header = makeTarHeader(
            path: entryPath,
            size: Int64(fileData.count),
            typeFlag: UInt8(ascii: "0"),
            mode: 0o644,
            mtime: mtime
        )
        tarData.append(header)
        tarData.append(fileData)
        let pad = (512 - (fileData.count % 512)) % 512
        if pad > 0 {
            tarData.append(Data(count: pad))
        }
    }

    private static func makeTarHeader(path: String, size: Int64, typeFlag: UInt8, mode: UInt32, mtime: Int64) -> Data {
        var header = Data(count: 512)
        let pathBytes = Array(path.utf8)
        let nameBytes: [UInt8]
        let prefixBytes: [UInt8]
        if pathBytes.count > 100 {
            if let splitIdx = pathBytes.lastIndex(of: UInt8(ascii: "/")), splitIdx <= 155, (pathBytes.count - splitIdx - 1) <= 100 {
                prefixBytes = Array(pathBytes[0..<splitIdx])
                nameBytes = Array(pathBytes[(splitIdx + 1)...])
            } else {
                nameBytes = Array(pathBytes.prefix(100))
                prefixBytes = []
            }
        } else {
            nameBytes = pathBytes
            prefixBytes = []
        }
        
        header.replaceSubrange(0..<min(100, nameBytes.count), with: nameBytes.prefix(100))
        writeOctal(UInt64(mode), to: &header, range: 100..<108)
        writeOctal(0, to: &header, range: 108..<116)
        writeOctal(0, to: &header, range: 116..<124)
        writeOctal(UInt64(max(0, size)), to: &header, range: 124..<136)
        writeOctal(UInt64(max(0, mtime)), to: &header, range: 136..<148)
        
        let spaces = [UInt8](repeating: UInt8(ascii: " "), count: 8)
        header.replaceSubrange(148..<156, with: spaces)
        header[156] = typeFlag
        
        let magic = Array("ustar\0".utf8)
        header.replaceSubrange(257..<263, with: magic)
        header[263] = UInt8(ascii: "0")
        header[264] = UInt8(ascii: "0")
        
        let uname = Array("ttzip\0".utf8)
        header.replaceSubrange(265..<265 + uname.count, with: uname)
        let gname = Array("staff\0".utf8)
        header.replaceSubrange(297..<297 + gname.count, with: gname)
        
        if !prefixBytes.isEmpty {
            header.replaceSubrange(345..<345 + min(155, prefixBytes.count), with: prefixBytes.prefix(155))
        }
        
        var chksum: UInt32 = 0
        for b in header {
            chksum += UInt32(b)
        }
        
        let chkStr = String(format: "%06o", chksum)
        let chkBytes = Array(chkStr.utf8)
        header.replaceSubrange(148..<154, with: chkBytes)
        header[154] = 0
        header[155] = UInt8(ascii: " ")
        return header
    }

    private static func writeOctal(_ value: UInt64, to data: inout Data, range: Range<Int>) {
        let count = range.count
        let octStr = String(value, radix: 8)
        let padded = String(repeating: "0", count: max(0, count - 1 - octStr.count)) + octStr
        let bytes = Array(padded.utf8.suffix(count - 1)) + [0]
        data.replaceSubrange(range.lowerBound..<range.lowerBound + bytes.count, with: bytes)
    }

    static func extractTarData(_ tarData: Data, destinationDir: String, skipMacJunk: Bool, fallbackBaseName: String) throws -> Bool {
        let destURL = URL(fileURLWithPath: destinationDir).standardizedFileURL
        try FileManager.default.createDirectory(at: destURL, withIntermediateDirectories: true)
        
        guard tarData.count >= 512 else {
            let fallbackURL = destURL.appendingPathComponent(fallbackBaseName)
            try tarData.write(to: fallbackURL)
            return true
        }
        
        let magicSub = tarData.subdata(in: 257..<min(262, tarData.count))
        let isTar = magicSub == Data("ustar".utf8) || magicSub == Data("GNUt".utf8)
        
        if !isTar {
            let fallbackURL = destURL.appendingPathComponent(fallbackBaseName)
            try tarData.write(to: fallbackURL)
            return true
        }
        
        var offset = 0
        while offset + 512 <= tarData.count {
            let headerSlice = tarData.subdata(in: offset..<offset + 512)
            if headerSlice.allSatisfy({ $0 == 0 }) {
                break
            }
            
            let name = readString(from: headerSlice, range: 0..<100)
            let prefix = readString(from: headerSlice, range: 345..<500)
            let fullEntryPath = prefix.isEmpty ? name : "\(prefix)/\(name)"
            
            guard !fullEntryPath.isEmpty else {
                offset += 512
                continue
            }
            
            let size = readOctal(from: headerSlice, range: 124..<136)
            let typeFlag = headerSlice[156]
            let mode = UInt32(readOctal(from: headerSlice, range: 100..<108))
            let paddedSize = ((size + 511) / 512) * 512
            
            if skipMacJunk && isMacJunk(name: fullEntryPath) {
                offset += 512 + paddedSize
                continue
            }
            
            let entryTargetURL = destURL.appendingPathComponent(fullEntryPath).standardizedFileURL
            guard entryTargetURL.path.hasPrefix(destURL.path) else {
                offset += 512 + paddedSize
                continue
            }
            
            if typeFlag == UInt8(ascii: "5") || fullEntryPath.hasSuffix("/") {
                try FileManager.default.createDirectory(at: entryTargetURL, withIntermediateDirectories: true)
            } else if typeFlag == UInt8(ascii: "0") || typeFlag == 0 {
                try FileManager.default.createDirectory(at: entryTargetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                let payloadEnd = min(offset + 512 + size, tarData.count)
                if payloadEnd >= offset + 512 {
                    let payload = tarData.subdata(in: (offset + 512)..<payloadEnd)
                    try payload.write(to: entryTargetURL)
                    if mode > 0 {
                        try? FileManager.default.setAttributes([.posixPermissions: NSNumber(value: mode & 0o777)], ofItemAtPath: entryTargetURL.path)
                    }
                }
            }
            
            offset += 512 + paddedSize
        }
        return true
    }

    private static func readString(from data: Data, range: Range<Int>) -> String {
        let slice = data.subdata(in: range)
        let nullTerm = slice.prefix(while: { $0 != 0 })
        return String(decoding: nullTerm, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func readOctal(from data: Data, range: Range<Int>) -> Int {
        let str = readString(from: data, range: range)
        return Int(str, radix: 8) ?? 0
    }

    private static func isMacJunk(name: String) -> Bool {
        return name.contains("__MACOSX") || name.hasSuffix(".DS_Store") || URL(fileURLWithPath: name).lastPathComponent.hasPrefix("._")
    }
}
