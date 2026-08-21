// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

final class SafeAtomicInt64: @unchecked Sendable {
    private var _val: Int64
    private let lock = NSLock()
    
    init(_ val: Int64) {
        self._val = val
    }
    
    var val: Int64 {
        get { lock.withLock { _val } }
        set { lock.withLock { _val = newValue } }
    }
}

extension ArchiveWriter {
    /// Recursively calculates physical directory byte size using POSIX `lstat` and `opendir`.
    static func recursivePathSize(at path: String) -> Int64 {
        var st = stat()
        if lstat(path, &st) != 0 { return 0 }
        if (st.st_mode & S_IFMT) == S_IFDIR {
            var total: Int64 = 0
            if let dir = opendir(path) {
                defer { closedir(dir) }
                while let entry = readdir(dir) {
                    let name = withUnsafeBytes(of: entry.pointee.d_name) { rawPtr -> String in
                        guard let base = rawPtr.baseAddress else { return "" }
                        return String(cString: base.assumingMemoryBound(to: CChar.self))
                    }
                    if name == "." || name == ".." { continue }
                    let childPath = (path as NSString).appendingPathComponent(name)
                    total += recursivePathSize(at: childPath)
                }
            }
            return total
        } else {
            return Int64(st.st_size)
        }
    }
    
    /// Splits an archive file into numbered or spanned volumes when split volume size is specified.
    public static func sliceArchiveIfNeeded(
        archivePath: String,
        splitSizeBytes: Int64,
        namingPattern: VolumeNamingPattern = .numberedExtension
    ) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: archivePath) else { return }
        let attrs = try fm.attributesOfItem(atPath: archivePath)
        guard let fileSize = attrs[.size] as? Int64, fileSize > 0 else { return }
        guard splitSizeBytes >= 65536 && splitSizeBytes < fileSize else { return }
        
        let schemeVal: Int32
        switch namingPattern {
        case .numberedExtension:
            schemeVal = Int32(TTZIP_VOLUME_NAMING_NUMBERED.rawValue)
        case .pkzipSpanned:
            schemeVal = Int32(TTZIP_VOLUME_NAMING_PKZIP.rawValue)
        case .rawSplit:
            schemeVal = Int32(TTZIP_VOLUME_NAMING_RAW.rawValue)
        }
        
        let res = archivePath.withCString { cSrc in
            archivePath.withCString { cDst in
                ttzip_rust_split_file(cSrc, cDst, UInt64(splitSizeBytes), schemeVal, true)
            }
        }
        
        guard res == TTZIP_STATUS_OK else {
            throw ArchiveError.readFailed(code: res.rawValue)
        }
        
        if namingPattern != .pkzipSpanned {
            try? fm.removeItem(atPath: archivePath)
        }
    }
}

