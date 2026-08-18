// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Libarchive UUDecode error types.
public enum LibarchiveUUDecodeError: LocalizedError, Sendable, Equatable {
    case missingBeginHeader
    case missingEndFooter
    case corruptedLineLength(Int)
    case invalidCharacter(Character, line: Int)
    case emptyData
    case invalidFile(String)
    
    public var errorDescription: String? {
        switch self {
        case .missingBeginHeader:
            return "Invalid uuencoded stream: missing 'begin <mode> <filename>' header."
        case .missingEndFooter:
            return "Invalid uuencoded stream: missing 'end' footer."
        case .corruptedLineLength(let line):
            return "Corrupted uuencoded line length at line \(line)."
        case .invalidCharacter(let char, let line):
            return "Invalid character '\(char)' in uuencoded stream at line \(line)."
        case .emptyData:
            return "Decoded data payload is empty."
        case .invalidFile(let path):
            return "Failed to read uuencoded file at path: \(path)"
        }
    }
}

/// In-memory libarchive ASCII `.uu` golden corpus decoder (100% native in-process Swift, zero CLI dependencies).
public enum LibarchiveUUDecoder: Sendable {
    
    /// UU header metadata.
    public struct UUHeader: Sendable, Equatable {
        public let mode: Int
        public let filename: String
        public let isBase64: Bool
        
        public init(mode: Int, filename: String, isBase64: Bool = false) {
            self.mode = mode
            self.filename = filename
            self.isBase64 = isBase64
        }
    }
    
    /// Parses UU header line (`begin 644 filename` or `begin-base64 644 filename`).
    public static func parseHeader(from line: String) -> UUHeader? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("begin ") {
            let parts = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            if parts.count >= 3, let mode = Int(parts[1], radix: 8) {
                return UUHeader(mode: mode, filename: String(parts[2]), isBase64: false)
            } else if parts.count == 2, let mode = Int(parts[1], radix: 8) {
                return UUHeader(mode: mode, filename: "", isBase64: false)
            }
        } else if trimmed.hasPrefix("begin-base64 ") {
            let parts = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            if parts.count >= 3, let mode = Int(parts[1], radix: 8) {
                return UUHeader(mode: mode, filename: String(parts[2]), isBase64: true)
            } else if parts.count == 2, let mode = Int(parts[1], radix: 8) {
                return UUHeader(mode: mode, filename: "", isBase64: true)
            }
        }
        return nil
    }

    /// Reconstructs binary archive payload directly from `.uu` text content (100% in-memory direct streaming).
    public static func decode(uuString: String) throws -> Data {
        guard let data = uuString.data(using: .utf8) ?? uuString.data(using: .ascii) else {
            throw LibarchiveUUDecodeError.emptyData
        }
        return try decode(data: data)
    }

    /// Decodes raw byte stream containing uuencoded data.
    public static func decode(data: Data) throws -> Data {
        var result = Data()
        result.reserveCapacity(data.count * 3 / 4)
        
        var started = false
        var header: UUHeader?
        
        let lines = data.split(separator: UInt8(ascii: "\n"))
        var lineIndex = 0
        
        for rawLine in lines {
            lineIndex += 1
            var lineBytes = Array(rawLine)
            if lineBytes.last == UInt8(ascii: "\r") {
                lineBytes.removeLast()
            }
            if lineBytes.isEmpty {
                continue
            }
            
            if !started {
                if let lineStr = String(bytes: lineBytes, encoding: .ascii) {
                    if let parsedHeader = parseHeader(from: lineStr) {
                        started = true
                        header = parsedHeader
                        continue
                    }
                }
                continue
            }
            
            if let lineStr = String(bytes: lineBytes, encoding: .ascii) {
                let trimmed = lineStr.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed == "end" || trimmed.hasPrefix("end ") || trimmed == "====" {
                    break
                }
            }
            
            if header?.isBase64 == true {
                if let lineStr = String(bytes: lineBytes, encoding: .ascii)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !lineStr.isEmpty {
                    if let chunk = Data(base64Encoded: lineStr, options: .ignoreUnknownCharacters) {
                        result.append(chunk)
                    }
                }
                continue
            }
            
            // Standard POSIX / libarchive UUDecode mode
            guard let firstByte = lineBytes.first else {
                continue
            }
            
            let lineLength = decodeByte(firstByte)
            if lineLength == 0 {
                continue
            }
            
            var byteCount = Int(lineLength)
            var idx = 1
            
            while byteCount > 0 && idx < lineBytes.count {
                let c0 = decodeByte(lineBytes[idx])
                let c1 = (idx + 1 < lineBytes.count) ? decodeByte(lineBytes[idx + 1]) : 0
                let c2 = (idx + 2 < lineBytes.count) ? decodeByte(lineBytes[idx + 2]) : 0
                let c3 = (idx + 3 < lineBytes.count) ? decodeByte(lineBytes[idx + 3]) : 0
                
                let b0 = UInt8((c0 << 2) | (c1 >> 4))
                result.append(b0)
                byteCount -= 1
                
                if byteCount > 0 {
                    let b1 = UInt8(((c1 & 0x0F) << 4) | (c2 >> 2))
                    result.append(b1)
                    byteCount -= 1
                }
                if byteCount > 0 {
                    let b2 = UInt8(((c2 & 0x03) << 6) | (c3 & 0x3F))
                    result.append(b2)
                    byteCount -= 1
                }
                idx += 4
            }
        }
        
        guard started else {
            throw LibarchiveUUDecodeError.missingBeginHeader
        }
        guard !result.isEmpty else {
            throw LibarchiveUUDecodeError.emptyData
        }
        return result
    }

    /// Decodes from file URL.
    public static func decode(fileURL: URL) throws -> Data {
        do {
            let data = try Data(contentsOf: fileURL)
            return try decode(data: data)
        } catch let err as LibarchiveUUDecodeError {
            throw err
        } catch {
            throw LibarchiveUUDecodeError.invalidFile(fileURL.path)
        }
    }

    /// Decodes from file path.
    public static func decode(filePath: String) throws -> Data {
        return try decode(fileURL: URL(fileURLWithPath: filePath))
    }

    @inline(__always)
    private static func decodeByte(_ byte: UInt8) -> UInt8 {
        if byte >= 32 && byte <= 96 {
            return (byte - 32) & 0x3F
        }
        return 0
    }
}
