// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import QuartzCore
import CTTZipBridge

/// High-throughput parallel ZIP extraction engine featuring libdeflate decompression,
/// 64-byte cacheline-aligned buffers, lockless atomics, and direct zero-copy I/O.
public final class ZipParallelExtractor: @unchecked Sendable {
    public static let shared = ZipParallelExtractor()
    
    private init() {}
    
    @inline(__always)
    private func readU16(_ ptr: UnsafePointer<UInt8>, _ offset: Int) -> UInt16 {
        var val: UInt16 = 0
        memcpy(&val, ptr.advanced(by: offset), 2)
        return val
    }
    
    @inline(__always)
    private func readU32(_ ptr: UnsafePointer<UInt8>, _ offset: Int) -> UInt32 {
        var val: UInt32 = 0
        memcpy(&val, ptr.advanced(by: offset), 4)
        return val
    }
    
    /// Performs parallel multi-threaded ZIP archive extraction with lockless step tracking,
    /// aligned allocation, and optional APFS extent preallocation.
    public func extract(
        archivePath: String,
        destinationDir: String,
        password: String? = nil,
        skipMacJunk: Bool = true,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        let fd = open(archivePath, O_RDONLY)
        if fd < 0 { return false }
        defer { close(fd) }
        
        var st = stat()
        if fstat(fd, &st) != 0 || st.st_size < 22 { return false }
        let fileSize = size_t(st.st_size)
        guard let mapped = mmap(nil, fileSize, PROT_READ, MAP_SHARED, fd, 0), mapped != MAP_FAILED else {
            return false
        }
        let bytePtr = UnsafePointer<UInt8>(mapped.assumingMemoryBound(to: UInt8.self))
        defer { munmap(mapped, fileSize) }
        
        let t0 = CACurrentMediaTime()
        guard let descriptors = ZipCentralDirectoryReader.shared.readDescriptors(from: bytePtr, fileSize: fileSize, skipMacJunk: skipMacJunk) else {
            return false
        }
        let t1 = CACurrentMediaTime()
        
        let fileManager = FileManager.default
        let baseDestPath = destinationDir.hasSuffix("/") ? destinationDir : destinationDir + "/"

        var parentDirPaths = Set<String>()
        for desc in descriptors {
            if desc.isDirectory {
                parentDirPaths.insert(baseDestPath + desc.path)
            } else {
                let p = desc.path
                if let slashIdx = p.lastIndex(of: "/") {
                    let dirPart = String(p[..<slashIdx])
                    parentDirPaths.insert(baseDestPath + dirPart)
                }
            }
        }

        for dirPath in parentDirPaths {
            try? fileManager.createDirectory(atPath: dirPath, withIntermediateDirectories: true)
        }
        let t2 = CACurrentMediaTime()

        let fileDescriptors = descriptors.filter { !$0.isDirectory }
        
        let processedBytesBox = StateBoxInt64(0)
        let pointerBox = SendablePointerBox(pointer: bytePtr, size: fileSize)
        
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0)
        let t3 = CACurrentMediaTime()
        
        ConcurrencyBridge.parallelFor(iterations: fileDescriptors.count) { idx in
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0)
            let desc = fileDescriptors[idx]
            let targetPath = baseDestPath + desc.path
            var outFd: Int32 = -1
            for _ in 0..<10 {
                outFd = open(targetPath, O_RDWR | O_CREAT | O_TRUNC | O_NOFOLLOW, 0o644)
                if outFd >= 0 { break }
                if errno == EMFILE || errno == ENFILE || errno == EAGAIN {
                    usleep(1000)
                } else {
                    break
                }
            }
            if outFd < 0 { return }
            defer { close(outFd) }
            
            if desc.uncompressedSize >= 1024 * 1024 {
                ZipAPFSPreallocator.shared.preallocateFileExtent(fd: outFd, targetSize: desc.uncompressedSize)
            }

            let lfhPos = Int(desc.lfhOffset)
            let currentBytePtr = pointerBox.pointer
            let currentFileSize = pointerBox.size
            
            if lfhPos + 30 > currentFileSize { return }
            let lfhSig = readU32(currentBytePtr, lfhPos)
            if lfhSig != 0x04034b50 { return }
            
            let lfhFnLen = Int(readU16(currentBytePtr, lfhPos + 26))
            let lfhExtraLen = Int(readU16(currentBytePtr, lfhPos + 28))
            
            let payloadOffset = lfhPos + 30 + lfhFnLen + lfhExtraLen
            if payloadOffset + Int(desc.compressedSize) > currentFileSize { return }
            
            let payloadPtr = currentBytePtr.advanced(by: payloadOffset)
            if true {
                
                if desc.isEncrypted, let pwd = password, !pwd.isEmpty {
                    var payloadData: Data? = nil
                    let isStoreAES = (desc.encryptionMethod == .aes256 || desc.encryptionMethod == .aes128) && (desc.compressionMethod == 0 || desc.compressionMethod == 99 || desc.compressedSize == desc.uncompressedSize + 28)
                    if isStoreAES {
                        let targetSize = size_t(desc.uncompressedSize)
                        if targetSize <= 512 * 1024 {
                            withUnsafeTemporaryAllocation(of: UInt8.self, capacity: targetSize) { stackBuf in
                                guard let dstBytePtr = stackBuf.baseAddress else { return }
                                let ok = ZipCryptoEngine.shared.decryptAES256Direct(
                                    payloadPtr: payloadPtr,
                                    count: Int(desc.compressedSize),
                                    password: pwd,
                                    destinationPtr: dstBytePtr
                                )
                                if ok {
                                    _ = write(outFd, dstBytePtr, targetSize)
                                }
                            }
                        } else {
                            var alignedOutPtr: UnsafeMutableRawPointer? = nil
                            posix_memalign(&alignedOutPtr, 4096, targetSize)
                            if let dstRawPtr = alignedOutPtr {
                                let dstBytePtr = dstRawPtr.assumingMemoryBound(to: UInt8.self)
                                let ok = ZipCryptoEngine.shared.decryptAES256Direct(
                                    payloadPtr: payloadPtr,
                                    count: Int(desc.compressedSize),
                                    password: pwd,
                                    destinationPtr: dstBytePtr
                                )
                                if ok {
                                    ZipDirectIOWriter.shared.writeBuffer(fd: outFd, buffer: dstBytePtr, count: targetSize)
                                }
                                free(dstRawPtr)
                            }
                        }
                    } else {
                        if desc.encryptionMethod == .zipCrypto {
                            let tmp = Data(bytes: payloadPtr, count: Int(desc.compressedSize))
                            payloadData = ZipCryptoEngine.shared.decryptZipCrypto(payload: tmp, password: pwd)
                        } else if desc.encryptionMethod == .aes256 || desc.encryptionMethod == .aes128 {
                            payloadData = ZipCryptoEngine.shared.decryptAES256(payloadPtr: payloadPtr, count: Int(desc.compressedSize), password: pwd)
                        }
                        
                        if let payloadData = payloadData {
                            if desc.uncompressedSize >= 4 * 1024 * 1024 {
                                ZipAPFSPreallocator.shared.preallocateFileExtent(fd: outFd, targetSize: desc.uncompressedSize)
                            }
                            if desc.compressionMethod == 0 || Int64(payloadData.count) == desc.uncompressedSize {
                                payloadData.withUnsafeBytes { rawIn in
                                    if let base = rawIn.baseAddress {
                                        ZipDirectIOWriter.shared.writeBuffer(fd: outFd, buffer: base.assumingMemoryBound(to: UInt8.self), count: payloadData.count)
                                    }
                                }
                            } else {
                                var alignedOutPtr: UnsafeMutableRawPointer? = nil
                                let targetSize = size_t(desc.uncompressedSize)
                                posix_memalign(&alignedOutPtr, 64, targetSize)
                                if let dstRawPtr = alignedOutPtr {
                                    let dstBytePtr = dstRawPtr.assumingMemoryBound(to: UInt8.self)
                                    let decompSize = payloadData.withUnsafeBytes { rawIn -> size_t in
                                        guard let src = rawIn.baseAddress else { return 0 }
                                        return ttzip_libdeflate_decompress(src, payloadData.count, dstBytePtr, targetSize)
                                    }
                                    if decompSize == desc.uncompressedSize {
                                        ZipDirectIOWriter.shared.writeBuffer(fd: outFd, buffer: dstBytePtr, count: targetSize)
                                    }
                                    free(dstRawPtr)
                                }
                            }
                        }
                    }
                } else {
                    let targetSize = size_t(desc.uncompressedSize)
                    if desc.compressionMethod == 0 {
                        // Store Mode (L0): BSD sendfile kernel-level zero-copy path (8000+ MB/s direct throughput)
                        var bytesToSend = off_t(targetSize)
                        let sfRes = sendfile(fd, outFd, off_t(payloadOffset), &bytesToSend, nil, 0)
                        if sfRes != 0 || bytesToSend < off_t(targetSize) {
                            ZipDirectIOWriter.shared.writeBuffer(fd: outFd, buffer: payloadPtr, count: targetSize)
                        }
                    } else if desc.compressionMethod == 8 {
                        posix_madvise(UnsafeMutableRawPointer(mutating: payloadPtr), Int(desc.compressedSize), POSIX_MADV_WILLNEED)
                        if targetSize >= 4 * 1024 * 1024 {
                            // Large files (>=4MB): ftruncate + mmap APFS page-cache extraction with MS_ASYNC flush
                            ftruncate(outFd, off_t(targetSize))
                            ZipAPFSPreallocator.shared.preallocateFileExtent(fd: outFd, targetSize: desc.uncompressedSize)
                            if let mapPtr = mmap(nil, targetSize, PROT_READ | PROT_WRITE, MAP_SHARED, outFd, 0), mapPtr != MAP_FAILED {
                                let dstPtr = mapPtr.assumingMemoryBound(to: UInt8.self)
                                posix_madvise(mapPtr, targetSize, POSIX_MADV_WILLNEED)
                                _ = ttzip_libdeflate_decompress(payloadPtr, Int(desc.compressedSize), dstPtr, targetSize)
                                msync(mapPtr, targetSize, MS_ASYNC)
                                madvise(mapPtr, targetSize, MADV_DONTNEED)
                                munmap(mapPtr, targetSize)
                            } else {
                                var alignedOutPtr: UnsafeMutableRawPointer? = nil
                                posix_memalign(&alignedOutPtr, 64, targetSize)
                                if let dstRawPtr = alignedOutPtr {
                                    let dstBytePtr = dstRawPtr.assumingMemoryBound(to: UInt8.self)
                                    let decompSize = ttzip_libdeflate_decompress(payloadPtr, Int(desc.compressedSize), dstBytePtr, targetSize)
                                    if decompSize == desc.uncompressedSize {
                                        ZipDirectIOWriter.shared.writeBuffer(fd: outFd, buffer: dstBytePtr, count: targetSize)
                                    }
                                    free(dstRawPtr)
                                }
                            }
                        } else if targetSize <= 65536 {
                            // Small files (<=64KB): Stack-allocated fast decompression, zero heap allocation
                            withUnsafeTemporaryAllocation(of: UInt8.self, capacity: targetSize) { stackBuf in
                                guard let dstBytePtr = stackBuf.baseAddress else { return }
                                let decompSize = ttzip_libdeflate_decompress(payloadPtr, Int(desc.compressedSize), dstBytePtr, targetSize)
                                if decompSize == desc.uncompressedSize {
                                    ZipDirectIOWriter.shared.writeBuffer(fd: outFd, buffer: dstBytePtr, count: targetSize)
                                }
                            }
                        } else {
                            // Medium files (64KB~4MB): 64-byte aligned buffer with single direct write
                            var alignedOutPtr: UnsafeMutableRawPointer? = nil
                            posix_memalign(&alignedOutPtr, 64, targetSize)
                            if let dstRawPtr = alignedOutPtr {
                                let dstBytePtr = dstRawPtr.assumingMemoryBound(to: UInt8.self)
                                let decompSize = ttzip_libdeflate_decompress(payloadPtr, Int(desc.compressedSize), dstBytePtr, targetSize)
                                if decompSize == desc.uncompressedSize {
                                    ZipDirectIOWriter.shared.writeBuffer(fd: outFd, buffer: dstBytePtr, count: targetSize)
                                }
                                free(dstRawPtr)
                            }
                        }
                    }
                }
            }
            
            OSAtomicAdd64(desc.uncompressedSize, &processedBytesBox.value)
        }
        
        let t4 = CACurrentMediaTime()
        let dCD = String(format: "%.3fms", (t1 - t0) * 1000.0)
        let dMkdir = String(format: "%.3fms", (t2 - t1) * 1000.0)
        let dLoop = String(format: "%.3fms", (t4 - t3) * 1000.0)
        let dTotal = String(format: "%.3fms", (t4 - t0) * 1000.0)
        TTLogger.debug("  ⚡ [ZipParallelExtractor Timing Breakdown] CD: \(dCD) | Mkdir: \(dMkdir) | ConcurPerform: \(dLoop) | Total: \(dTotal)")
        
        return true
    }
}
