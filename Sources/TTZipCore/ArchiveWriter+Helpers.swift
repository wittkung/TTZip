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
    
    /// Splits an archive file into numbered or spanned volumes via Rust C-ABI when split volume size is specified.
    public static func sliceArchiveIfNeeded(
        archivePath: String,
        splitSizeBytes: Int64,
        namingPattern: VolumeNamingPattern = .numberedExtension
    ) throws {
        let scheme: TTZipVolumeNamingScheme
        switch namingPattern {
        case .numberedExtension:
            scheme = TTZIP_VOLUME_NAMING_NUMBERED
        case .pkzipSpanned:
            scheme = TTZIP_VOLUME_NAMING_PKZIP
        case .rawSplit:
            scheme = TTZIP_VOLUME_NAMING_RAW
        }
        let status = CUnsafeBufferAdapter.withCString(archivePath) { cPath in
            guard let cPath = cPath else { return TTZIP_STATUS_ERR_INVALID_PARAM }
            return ttzip_rust_split_file(cPath, cPath, UInt64(splitSizeBytes), Int32(scheme.rawValue), true)
        }
        if status != TTZIP_STATUS_OK {
            throw ArchiveError.readFailed(code: status.rawValue)
        }
    }
}
