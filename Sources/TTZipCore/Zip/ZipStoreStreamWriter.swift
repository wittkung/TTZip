import Foundation
import CTTZipBridge
import zlib

/// 专为 Level 0 (Store 模式) 打造的多核并发页对齐物理落盘引擎
/// 充分利用 Apple Silicon 多核算力并发计算 CRC32，并结合系统 Page Cache 打满 RAM/NVMe 总线带宽
public final class ZipStoreStreamWriter: @unchecked Sendable {
    public static let shared = ZipStoreStreamWriter()
    
    private init() {}
    
    public func createStoreArchive(
        outputPath: String,
        inputPaths: [String],
        skipMacJunk: Bool = false,
        enableZeroCopy: Bool = true,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        let outFd = CUnsafeBufferAdapter.withCString(outputPath) { cPath -> Int32 in
            guard let cPath = cPath else { return -1 }
            unlink(cPath)
            return open(cPath, O_RDWR | O_CREAT | O_TRUNC, 0o644)
        }
        if outFd < 0 { return false }
        defer { close(outFd) }

        struct FastStoreEntry {
            let srcPath: String
            let relPath: String
            let isDir: Bool
            let fileSize: Int64
            var crc32: UInt32
            var localHeaderOffset: UInt64
            var dataOffset: UInt64
        }

        let scanned = ZipDirectoryScanner.scan(inputPaths: inputPaths, skipMacJunk: skipMacJunk)
        var items: [FastStoreEntry] = scanned.map { item in
            let formattedRel = item.isDirectory ? (item.relPath.hasSuffix("/") ? item.relPath : item.relPath + "/") : item.relPath
            return FastStoreEntry(
                srcPath: item.srcPath,
                relPath: formattedRel,
                isDir: item.isDirectory,
                fileSize: item.fileSize,
                crc32: 0,
                localHeaderOffset: 0,
                dataOffset: 0
            )
        }

        let totalOriginalBytes = items.reduce(0) { $0 + $1.fileSize }
        
        var currentOffset: UInt64 = 0
        for i in 0..<items.count {
            let nameBytes = Array(items[i].relPath.utf8)
            let nameLen = UInt16(nameBytes.count)
            items[i].localHeaderOffset = currentOffset
            if items[i].isDir {
                currentOffset += UInt64(30 + Int(nameLen))
                items[i].dataOffset = currentOffset
            } else {
                let extraLen = 20
                items[i].dataOffset = currentOffset + UInt64(30 + Int(nameLen) + extraLen)
                currentOffset = items[i].dataOffset + UInt64(items[i].fileSize)
            }
        }

        ZipAPFSPreallocator.shared.preallocateFileExtent(fd: outFd, targetSize: Int64(currentOffset) + Int64(items.count * 256))

        let startTime = Date()
        
        final class ProgressTracker: @unchecked Sendable {
            private let lock = NSLock()
            var bytes: Int64 = 0
            func add(_ val: Int64) -> Int64 {
                lock.lock()
                defer { lock.unlock() }
                bytes += val
                return bytes
            }
        }
        let tracker = ProgressTracker()

        struct UnsafeItemBuffer: @unchecked Sendable {
            let base: UnsafeMutablePointer<FastStoreEntry>
        }

        items.withUnsafeMutableBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            let safeBuffer = UnsafeItemBuffer(base: baseAddress)
            
            DispatchQueue.concurrentPerform(iterations: buffer.count) { i in
                let item = safeBuffer.base[i]
                let nameBytes = Array(item.relPath.utf8)
                let nameLen = UInt16(nameBytes.count)

                if item.isDir {
                    var header = Data()
                    header.append(contentsOf: [0x50, 0x4b, 0x03, 0x04])
                    header.append(contentsOf: [0x14, 0x00])
                    header.append(contentsOf: [0x00, 0x00])
                    header.append(contentsOf: [0x00, 0x00])
                    header.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
                    header.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
                    header.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
                    header.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
                    header.append(contentsOf: [UInt8(nameLen & 0xff), UInt8(nameLen >> 8)])
                    header.append(contentsOf: [0x00, 0x00])
                    header.append(contentsOf: nameBytes)
                    
                    CUnsafeBufferAdapter.withBufferPointer(header) { hPtr, hCount in
                        _ = pwrite(outFd, hPtr, hCount, off_t(item.localHeaderOffset))
                    }
                    return
                }

                let inFd = CUnsafeBufferAdapter.withCString(item.srcPath) { cSrc -> Int32 in
                    guard let cSrc = cSrc else { return -1 }
                    return open(cSrc, O_RDONLY)
                }
                if inFd < 0 { return }
                defer { close(inFd) }

                var fileCRC: UInt32 = 0
                let totalFileSize = Int(item.fileSize)
                
                if item.fileSize > 0 {
                    if item.fileSize >= 4 * 1024 * 1024,
                       let mappedIn = mmap(nil, totalFileSize, PROT_READ, MAP_SHARED, inFd, 0),
                       mappedIn != MAP_FAILED {
                        let inBytePtr = mappedIn.assumingMemoryBound(to: UInt8.self)
                        posix_madvise(mappedIn, totalFileSize, POSIX_MADV_WILLNEED | POSIX_MADV_SEQUENTIAL)

                        let cloneRet = enableZeroCopy ? ttzip_apfs_clone_range(inFd, 0, outFd, Int64(item.dataOffset), UInt64(item.fileSize)) : -1
                        if cloneRet == 0 {
                            let crcChunkSize = 64 * 1024 * 1024
                            let numChunks = (totalFileSize + crcChunkSize - 1) / crcChunkSize
                            var chunkCRCs = [UInt32](repeating: 0, count: numChunks)

                            chunkCRCs.withUnsafeMutableBufferPointer { crcBuf in
                                let rawCrcPtr = UInt(bitPattern: crcBuf.baseAddress)
                                let rawInPtr = UInt(bitPattern: inBytePtr)
                                DispatchQueue.concurrentPerform(iterations: numChunks) { idx in
                                    guard let basePtr = UnsafePointer<UInt8>(bitPattern: rawInPtr),
                                          let outBufPtr = UnsafeMutablePointer<UInt32>(bitPattern: rawCrcPtr) else { return }
                                    let offset = idx * crcChunkSize
                                    let len = min(crcChunkSize, totalFileSize - offset)
                                    let chunkPtr = basePtr.advanced(by: offset)
                                    outBufPtr[idx] = ttzip_compute_buffer_crc32_neon(0, chunkPtr, len)
                                }
                            }
                            
                            var finalCRC: UInt32 = 0
                            for idx in 0..<numChunks {
                                let len = min(crcChunkSize, totalFileSize - (idx * crcChunkSize))
                                finalCRC = UInt32(crc32_combine(uLong(finalCRC), uLong(chunkCRCs[idx]), len))
                            }
                            fileCRC = finalCRC
                            
                            let pb = tracker.add(Int64(totalFileSize))
                            
                            let elapsed = max(0.001, Date().timeIntervalSince(startTime))
                            let throughput = (Double(pb) / (1024 * 1024)) / elapsed
                            progressHandler?(ArchiveProgress(
                                state: .processing, bytesProcessed: pb, totalBytes: totalOriginalBytes,
                                currentFileName: item.relPath, throughputMBs: throughput
                            ))
                        } else {
                            let crcChunkSize = 16 * 1024 * 1024
                            let numChunks = (totalFileSize + crcChunkSize - 1) / crcChunkSize
                            var chunkCRCs = [UInt32](repeating: 0, count: numChunks)

                            chunkCRCs.withUnsafeMutableBufferPointer { crcBuf in
                                let rawCrcPtr = UInt(bitPattern: crcBuf.baseAddress)
                                let rawInPtr = UInt(bitPattern: inBytePtr)
                                DispatchQueue.concurrentPerform(iterations: numChunks) { idx in
                                    guard let basePtr = UnsafePointer<UInt8>(bitPattern: rawInPtr),
                                          let outBufPtr = UnsafeMutablePointer<UInt32>(bitPattern: rawCrcPtr) else { return }
                                    let offset = idx * crcChunkSize
                                    let len = min(crcChunkSize, totalFileSize - offset)
                                    let chunkPtr = basePtr.advanced(by: offset)
                                    outBufPtr[idx] = ttzip_compute_buffer_crc32_neon(0, chunkPtr, len)
                                    _ = pwrite(outFd, chunkPtr, len, off_t(item.dataOffset + UInt64(offset)))
                                }
                            }
                            
                            var finalCRC: UInt32 = 0
                            for idx in 0..<numChunks {
                                let len = min(crcChunkSize, totalFileSize - (idx * crcChunkSize))
                                finalCRC = UInt32(crc32_combine(uLong(finalCRC), uLong(chunkCRCs[idx]), len))
                            }
                            fileCRC = finalCRC
                            
                            let pb = tracker.add(Int64(totalFileSize))
                            let elapsed = max(0.001, Date().timeIntervalSince(startTime))
                            let throughput = (Double(pb) / (1024 * 1024)) / elapsed
                            progressHandler?(ArchiveProgress(
                                state: .processing, bytesProcessed: pb, totalBytes: totalOriginalBytes,
                                currentFileName: item.relPath, throughputMBs: throughput
                            ))
                        }
                        munmap(mappedIn, totalFileSize)
                    } else {
                        let chunkSize = 16 * 1024 * 1024
                        if let alignBuf = CUnsafeBufferAdapter.allocateAlignedBuffer(capacity: chunkSize) {
                            defer { CUnsafeBufferAdapter.deallocateAlignedBuffer(alignBuf) }
                            let chunkPtr = alignBuf.assumingMemoryBound(to: UInt8.self)
                            var bytesReadTotal: Int64 = 0
                            while bytesReadTotal < item.fileSize {
                                let bytesToRead = min(chunkSize, Int(item.fileSize - bytesReadTotal))
                                let n = pread(inFd, chunkPtr, bytesToRead, off_t(bytesReadTotal))
                                if n <= 0 { break }

                                fileCRC = ttzip_compute_buffer_crc32_neon(fileCRC, chunkPtr, n)
                                pwrite(outFd, chunkPtr, n, off_t(item.dataOffset + UInt64(bytesReadTotal)))

                                bytesReadTotal += Int64(n)

                                let pb = tracker.add(Int64(n))

                                let elapsed = max(0.001, Date().timeIntervalSince(startTime))
                                let throughput = (Double(pb) / (1024 * 1024)) / elapsed
                                progressHandler?(ArchiveProgress(
                                    state: .processing, bytesProcessed: pb, totalBytes: totalOriginalBytes,
                                    currentFileName: item.relPath, throughputMBs: throughput
                                ))
                            }
                        }
                    }
                }

                safeBuffer.base[i].crc32 = fileCRC

                var header = Data()
                header.append(contentsOf: [0x50, 0x4b, 0x03, 0x04])
                header.append(contentsOf: [0x2d, 0x00]) // Version 4.5 Zip64
                header.append(contentsOf: [0x00, 0x00]) // Flags
                header.append(contentsOf: [0x00, 0x00]) // Store
                header.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // Time/Date
                withUnsafeBytes(of: fileCRC.littleEndian) { header.append(contentsOf: $0) }
                header.append(contentsOf: [0xff, 0xff, 0xff, 0xff]) // Comp size Zip64
                header.append(contentsOf: [0xff, 0xff, 0xff, 0xff]) // Uncomp size Zip64
                header.append(contentsOf: [UInt8(nameLen & 0xff), UInt8(nameLen >> 8)])

                var extra = Data()
                extra.append(contentsOf: [0x01, 0x00]) // Tag 0x0001 Zip64
                extra.append(contentsOf: [0x10, 0x00]) // 16 bytes
                let uSize = UInt64(item.fileSize)
                withUnsafeBytes(of: uSize.littleEndian) { extra.append(contentsOf: $0) }
                withUnsafeBytes(of: uSize.littleEndian) { extra.append(contentsOf: $0) }

                let extraLen = UInt16(extra.count)
                header.append(contentsOf: [UInt8(extraLen & 0xff), UInt8(extraLen >> 8)])
                header.append(contentsOf: nameBytes)
                header.append(extra)

                CUnsafeBufferAdapter.withBufferPointer(header) { hPtr, hCount in
                    _ = pwrite(outFd, hPtr, hCount, off_t(item.localHeaderOffset))
                }
            }
        }

        let cdOffset = currentOffset
        var cdData = Data()
        for item in items {
            let nameBytes = Array(item.relPath.utf8)
            let nameLen = UInt16(nameBytes.count)

            cdData.append(contentsOf: [0x50, 0x4b, 0x01, 0x02])
            cdData.append(contentsOf: [0x2d, 0x00])
            cdData.append(contentsOf: [0x2d, 0x00])
            cdData.append(contentsOf: [0x00, 0x00])
            cdData.append(contentsOf: [0x00, 0x00])
            cdData.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
            withUnsafeBytes(of: item.crc32.littleEndian) { cdData.append(contentsOf: $0) }
            cdData.append(contentsOf: [0xff, 0xff, 0xff, 0xff])
            cdData.append(contentsOf: [0xff, 0xff, 0xff, 0xff])
            cdData.append(contentsOf: [UInt8(nameLen & 0xff), UInt8(nameLen >> 8)])

            var extra = Data()
            extra.append(contentsOf: [0x01, 0x00])
            extra.append(contentsOf: [0x18, 0x00])
            let uSz = UInt64(item.fileSize)
            let uOff = UInt64(item.localHeaderOffset)
            withUnsafeBytes(of: uSz.littleEndian) { extra.append(contentsOf: $0) }
            withUnsafeBytes(of: uSz.littleEndian) { extra.append(contentsOf: $0) }
            withUnsafeBytes(of: uOff.littleEndian) { extra.append(contentsOf: $0) }

            let extraLen = UInt16(extra.count)
            cdData.append(contentsOf: [UInt8(extraLen & 0xff), UInt8(extraLen >> 8)])
            cdData.append(contentsOf: [0x00, 0x00])
            cdData.append(contentsOf: [0x00, 0x00])
            cdData.append(contentsOf: [0x00, 0x00])
            cdData.append(contentsOf: item.isDir ? [0x00, 0x00, 0x00, 0x10] : [0x00, 0x00, 0x00, 0x20])
            cdData.append(contentsOf: [0xff, 0xff, 0xff, 0xff])
            cdData.append(contentsOf: nameBytes)
            cdData.append(extra)
        }

        let cdSize = UInt64(cdData.count)
        CUnsafeBufferAdapter.withBufferPointer(cdData) { ptr, count in
            _ = pwrite(outFd, ptr, count, off_t(currentOffset))
        }
        currentOffset += cdSize

        var eocd64 = Data()
        eocd64.append(contentsOf: [0x50, 0x4b, 0x06, 0x06])
        let recordSize: UInt64 = 44
        withUnsafeBytes(of: recordSize.littleEndian) { eocd64.append(contentsOf: $0) }
        eocd64.append(contentsOf: [0x2d, 0x00])
        eocd64.append(contentsOf: [0x2d, 0x00])
        eocd64.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
        eocd64.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
        let entryCount = UInt64(items.count)
        withUnsafeBytes(of: entryCount.littleEndian) { eocd64.append(contentsOf: $0) }
        withUnsafeBytes(of: entryCount.littleEndian) { eocd64.append(contentsOf: $0) }
        withUnsafeBytes(of: cdSize.littleEndian) { eocd64.append(contentsOf: $0) }
        withUnsafeBytes(of: cdOffset.littleEndian) { eocd64.append(contentsOf: $0) }
        CUnsafeBufferAdapter.withBufferPointer(eocd64) { ptr, count in
            _ = pwrite(outFd, ptr, count, off_t(currentOffset))
        }
        currentOffset += UInt64(eocd64.count)

        var locator = Data()
        locator.append(contentsOf: [0x50, 0x4b, 0x06, 0x07])
        locator.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
        let eocd64Offset = cdOffset + cdSize
        withUnsafeBytes(of: eocd64Offset.littleEndian) { locator.append(contentsOf: $0) }
        locator.append(contentsOf: [0x01, 0x00, 0x00, 0x00])
        CUnsafeBufferAdapter.withBufferPointer(locator) { ptr, count in
            _ = pwrite(outFd, ptr, count, off_t(currentOffset))
        }
        currentOffset += UInt64(locator.count)

        var eocd = Data()
        eocd.append(contentsOf: [0x50, 0x4b, 0x05, 0x06])
        eocd.append(contentsOf: [0xff, 0xff])
        eocd.append(contentsOf: [0xff, 0xff])
        eocd.append(contentsOf: [0xff, 0xff])
        eocd.append(contentsOf: [0xff, 0xff])
        eocd.append(contentsOf: [0xff, 0xff, 0xff, 0xff])
        eocd.append(contentsOf: [0xff, 0xff, 0xff, 0xff])
        eocd.append(contentsOf: [0x00, 0x00])
        CUnsafeBufferAdapter.withBufferPointer(eocd) { ptr, count in
            _ = pwrite(outFd, ptr, count, off_t(currentOffset))
        }
        currentOffset += UInt64(eocd.count)

        ftruncate(outFd, off_t(currentOffset))

        return true
    }

    private func isMacJunk(_ name: String) -> Bool {
        return name == "__MACOSX" || name == ".DS_Store" || name.hasPrefix("._")
    }
}
