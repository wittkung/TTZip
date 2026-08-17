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
    
    public static func sliceArchiveIfNeeded(archivePath: String, splitSizeBytes: Int64) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: archivePath) else { return }
        let attrs = try fm.attributesOfItem(atPath: archivePath)
        guard let fileSize = attrs[.size] as? Int64, fileSize > 0 else { return }
        
        let fileHandle = try FileHandle(forReadingFrom: URL(fileURLWithPath: archivePath))
        defer { try? fileHandle.close() }
        
        var chunkIndex = 1
        var remainingBytes = fileSize
        let bufferSize = 4 * 1024 * 1024
        
        while remainingBytes > 0 {
            let partExt = String(format: ".%03d", chunkIndex)
            let partPath = archivePath + partExt
            fm.createFile(atPath: partPath, contents: nil)
            let outHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: partPath))
            
            var bytesWrittenForThisPart: Int64 = 0
            while bytesWrittenForThisPart < splitSizeBytes && remainingBytes > 0 {
                let bytesToRead = min(Int64(bufferSize), min(splitSizeBytes - bytesWrittenForThisPart, remainingBytes))
                if let data = try fileHandle.read(upToCount: Int(bytesToRead)), !data.isEmpty {
                    try outHandle.write(contentsOf: data)
                    bytesWrittenForThisPart += Int64(data.count)
                    remainingBytes -= Int64(data.count)
                } else {
                    break
                }
            }
            try outHandle.close()
            chunkIndex += 1
        }
        
        try fm.removeItem(atPath: archivePath)
    }
}

