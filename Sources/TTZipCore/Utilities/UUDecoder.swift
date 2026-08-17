//
//  UUDecoder.swift
//  TTZipCore
//
//  Created for libarchive Golden Oracle Integration on 2026-08-16.
//

import Foundation

/// High-performance standalone UUEncode / UUDecode parser for Golden Oracle testing and corpus management.
/// Conforms to POSIX / BSD uudecode specifications matching `test_main.c:extract_reference_file()`.
public enum UUDecoder: Sendable {
    
    /// Decodes a UUEncoded text string into raw binary data alongside metadata (filename and octal mode).
    /// - Parameter uuText: The ASCII UUEncoded text content.
    /// - Returns: A tuple containing the extracted filename, file permission mode, and decoded binary payload, or nil if invalid.
    public static func decode(uuText: String) -> (filename: String, mode: Int, data: Data)? {
        guard let utf8Data = uuText.data(using: .utf8) else { return nil }
        return decode(data: utf8Data)
    }
    
    /// Decodes a UUEncoded UTF-8 Data buffer into raw binary data.
    /// - Parameter data: UTF-8 encoded UU text data.
    /// - Returns: A tuple containing the extracted filename, file permission mode, and decoded binary payload, or nil if invalid.
    public static func decode(data: Data) -> (filename: String, mode: Int, data: Data)? {
        guard !data.isEmpty else { return nil }
        
        var filename = "output.bin"
        var mode = 0o644
        var headerFound = false
        var outputData = Data()
        outputData.reserveCapacity(data.count * 3 / 4)
        
        let bytes = [UInt8](data)
        let totalLen = bytes.count
        var index = 0
        
        // Helper to read next line
        func nextLine() -> ArraySlice<UInt8>? {
            guard index < totalLen else { return nil }
            let start = index
            while index < totalLen && bytes[index] != 0x0A && bytes[index] != 0x0D {
                index += 1
            }
            let lineSlice = bytes[start..<index]
            // Skip CRLF
            if index < totalLen && bytes[index] == 0x0D { index += 1 }
            if index < totalLen && bytes[index] == 0x0A { index += 1 }
            return lineSlice
        }
        
        // Phase 1: Locate "begin <mode> <filename>"
        while let line = nextLine() {
            if line.count >= 6 && line.starts(with: [0x62, 0x65, 0x67, 0x69, 0x6E, 0x20]) { // "begin "
                if let lineStr = String(bytes: line, encoding: .utf8) {
                    let parts = lineStr.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
                    if parts.count >= 3 {
                        if let parsedMode = Int(parts[1], radix: 8) {
                            mode = parsedMode
                        }
                        filename = String(parts[2]).trimmingCharacters(in: .whitespacesAndNewlines)
                        headerFound = true
                        break
                    }
                }
            }
        }
        
        guard headerFound else { return nil }
        
        @inline(__always)
        func uudecodeChar(_ c: UInt8) -> UInt32 {
            guard c >= 32 && c <= 96 else { return 0 }
            return UInt32((c - 0x20) & 0x3F)
        }
        
        // Phase 2: Process body until "end"
        while let line = nextLine() {
            guard !line.isEmpty else { continue }
            if line.count >= 3 && line.starts(with: [0x65, 0x6E, 0x64]) { // "end"
                break
            }
            
            let lineBytes = Array(line)
            let lengthChar = lineBytes[0]
            var lineByteCount = Int((lengthChar - 0x20) & 0x3F)
            if lineByteCount <= 0 { continue }
            
            var p = 1
            let lineLen = lineBytes.count
            
            while lineByteCount > 0 && p + 1 < lineLen {
                let c0 = uudecodeChar(lineBytes[p])
                let c1 = uudecodeChar(lineBytes[p + 1])
                let c2 = (p + 2 < lineLen) ? uudecodeChar(lineBytes[p + 2]) : 0
                let c3 = (p + 3 < lineLen) ? uudecodeChar(lineBytes[p + 3]) : 0
                
                let n = (c0 << 18) | (c1 << 12) | (c2 << 6) | c3
                
                outputData.append(UInt8((n >> 16) & 0xFF))
                lineByteCount -= 1
                
                if lineByteCount > 0 && p + 2 < lineLen {
                    outputData.append(UInt8((n >> 8) & 0xFF))
                    lineByteCount -= 1
                }
                
                if lineByteCount > 0 && p + 3 < lineLen {
                    outputData.append(UInt8(n & 0xFF))
                    lineByteCount -= 1
                }
                
                p += 4
            }
        }
        
        return (filename, mode, outputData)
    }
}
