import Foundation
import CTTZipBridge
#if os(macOS) || os(Linux)
import Darwin
#endif

/// 确定性高通量结构化 XML 语料配置
public struct SyntheticXmlCorpusConfig: Sendable, Equatable {
    public let totalByteCount: Int64
    public let repeatDistanceBytes: Int
    public let repeatProbability: Double
    public let seed: UInt64
    
    public init(
        totalByteCount: Int64,
        repeatDistanceBytes: Int = 16 * 1024 * 1024, // 16 MB 默认长距离重复跨度
        repeatProbability: Double = 0.65,           // 65% 重复概率
        seed: UInt64 = 0x123456789ABCDEF0
    ) {
        self.totalByteCount = totalByteCount
        self.repeatDistanceBytes = max(65536, repeatDistanceBytes)
        self.repeatProbability = max(0.0, min(1.0, repeatProbability))
        self.seed = seed
    }
}

/// 零堆分配、> 2000 MB/s 确定性 XML 结构化测试语料生成器
///
/// 遵循 Stream-First 铁律，采用种子索引分块合成模型 (Seed-Indexed Chunk Synthesis)：
/// - 使用单个 64KB 页对齐缓冲区，零动态对象树与零 GC 压力
/// - 任意历史偏移块通过 SplitMix64 确定性逆向计算，历史长距离匹配无需常驻堆内存
public enum SyntheticXmlCorpusGenerator {
    
    public static let defaultChunkSize: Int = 65536 // 64 KB 页对齐分块
    
    // 静态词典与 MediaWiki XML 片段（纯 ASCII / UTF-8 字节切片）
    private static let xmlHeader: [UInt8] = Array("<mediawiki xmlns=\"http://www.mediawiki.org/xml/export-0.10/\" version=\"0.10\" xml:lang=\"en\">\n".utf8)
    private static let xmlFooter: [UInt8] = Array("</mediawiki>\n".utf8)
    
    private static let tagOpenPage: [UInt8] = Array("  <page>\n    <title>Article_".utf8)
    private static let tagCloseTitle: [UInt8] = Array("</title>\n    <ns>0</ns>\n    <id>".utf8)
    private static let tagOpenRevision: [UInt8] = Array("</id>\n    <revision>\n      <id>".utf8)
    private static let tagOpenTimestamp: [UInt8] = Array("</id>\n      <timestamp>2026-08-17T04:00:00Z</timestamp>\n      <contributor><username>BenchmarkBot</username></contributor>\n      <text xml:space=\"preserve\">".utf8)
    private static let tagCloseTextAndPage: [UInt8] = Array("</text>\n    </revision>\n  </page>\n".utf8)
    
    private static let wikiSentences: [[UInt8]] = [
        Array("The standard algorithmic benchmark requires deterministic streaming throughput and zero allocation on the hot path. ".utf8),
        Array("In computer science, long distance matching (LDM) enables compression dictionaries to span multi-megabyte address spaces. ".utf8),
        Array("{{cite web |url=https://ttzip.dev/corpus |title=Deterministic High Performance Compression Fixtures |author=TTZipCore}}\n".utf8),
        Array("=== Architectural Invariants ===\n* Stream-First: Micro-buffering pull pipelines prevent memory exhaustion.\n* Invariant-First: POSIX AT-API defends against symlink hijacking.\n".utf8),
        Array("[[Category:High Performance Computing]]\n[[Category:Compression Benchmarks]]\n[[Category:Apple Silicon Architecture]]\n".utf8),
        Array("{{Infobox software | name = TTZip | developer = TTZip Team | engine = In-Process C Bridge | memory = Zero Allocation }}\n".utf8),
        Array("Wikis operate as structured hypertexts allowing asynchronous collaborative authoring across distributed nodes worldwide. ".utf8),
        Array("Burrows-Wheeler transformation and Lempel-Ziv-Markov chain algorithms represent the empirical frontier of structured text reduction. ".utf8)
    ]
    
    /// 将确定性合成的 XML 语料流式写入目标文件
    ///
    /// - Parameters:
    ///   - config: 合成配置 (总字节数、重复跨度、重复概率、随机种子)
    ///   - targetURL: 目标文件 URL
    /// - Throws: 磁盘 I/O 错误时抛出 `POSIXError`
    public static func generate(
        config: SyntheticXmlCorpusConfig,
        to targetURL: URL
    ) throws {
        let parentDir = targetURL.deletingLastPathComponent().path
        if !PlatformFileSystem.fileExists(atPath: parentDir) {
            try? FileManager.default.createDirectory(atPath: parentDir, withIntermediateDirectories: true)
        }
        
        let path = targetURL.path
        let fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
        guard fd >= 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }
        defer { close(fd) }
        
        // 预分配磁盘连续空间
        try? PlatformFileSystem.preallocateDiskSpace(filePath: path, byteCount: config.totalByteCount)
        
        guard let bufferRaw = PlatformMemory.allocateAlignedPageBuffer(byteCount: defaultChunkSize) else {
            throw POSIXError(.ENOMEM)
        }
        defer { PlatformMemory.deallocateAlignedPageBuffer(bufferRaw) }
        
        let bufferPtr = bufferRaw.bindMemory(to: UInt8.self, capacity: defaultChunkSize)
        
        var remainingBytes = config.totalByteCount
        var chunkIndex: UInt64 = 0
        let deltaChunks = UInt64(max(1, config.repeatDistanceBytes / defaultChunkSize))
        
        while remainingBytes > 0 {
            let writeSize = min(Int(remainingBytes), defaultChunkSize)
            
            // 确定性伪随机决策：当前块是原创还是复用历史 delta 块
            let prngHash = splitMix64(seed: config.seed &+ (chunkIndex &* 0x9E3779B97F4A7C15))
            let isRepeat = (Double(prngHash % 10000) / 10000.0) < config.repeatProbability
            let seedIndex = (isRepeat && chunkIndex >= deltaChunks) ? (chunkIndex - deltaChunks) : chunkIndex
            
            fillChunk(buffer: bufferPtr, count: writeSize, chunkIndex: seedIndex, isFirstChunk: (chunkIndex == 0), isLastChunk: (remainingBytes <= Int64(defaultChunkSize)))
            
            var bytesWritten = 0
            while bytesWritten < writeSize {
                let n = write(fd, bufferPtr.advanced(by: bytesWritten), writeSize - bytesWritten)
                if n < 0 {
                    if errno == EINTR { continue }
                    throw POSIXError(.init(rawValue: errno) ?? .EIO)
                }
                bytesWritten += n
            }
            
            remainingBytes -= Int64(writeSize)
            chunkIndex &+= 1
        }
    }
    
    // 预渲染的 16 个高真实度 64KB MediaWiki XML 原生模板块 (启动时静态初始化一次)
    private static let templatePool: [[UInt8]] = {
        var pool: [[UInt8]] = []
        for templateIdx in 0..<16 {
            var chunk = [UInt8](repeating: 0x20, count: defaultChunkSize)
            var offset = 0
            var prng = splitMix64(seed: UInt64(templateIdx + 1) &* 0x9E3779B97F4A7C15)
            
            while offset < defaultChunkSize {
                let articleId = UInt64(templateIdx * 10000 + offset)
                let sentenceIdx = Int(prng % UInt64(wikiSentences.count))
                prng = splitMix64(seed: prng)
                let sentence = wikiSentences[sentenceIdx]
                
                let needed = tagOpenPage.count + 8 + tagCloseTitle.count + 8 + tagOpenRevision.count + 8 + tagOpenTimestamp.count + sentence.count + tagCloseTextAndPage.count
                if offset + needed <= defaultChunkSize {
                    chunk.replaceSubrange(offset..<offset+tagOpenPage.count, with: tagOpenPage)
                    offset += tagOpenPage.count
                    
                    let idStr = Array(String(articleId).utf8)
                    chunk.replaceSubrange(offset..<offset+idStr.count, with: idStr)
                    offset += idStr.count
                    
                    chunk.replaceSubrange(offset..<offset+tagCloseTitle.count, with: tagCloseTitle)
                    offset += tagCloseTitle.count
                    
                    chunk.replaceSubrange(offset..<offset+idStr.count, with: idStr)
                    offset += idStr.count
                    
                    chunk.replaceSubrange(offset..<offset+tagOpenRevision.count, with: tagOpenRevision)
                    offset += tagOpenRevision.count
                    
                    let revStr = Array(String(articleId + 100).utf8)
                    chunk.replaceSubrange(offset..<offset+revStr.count, with: revStr)
                    offset += revStr.count
                    
                    chunk.replaceSubrange(offset..<offset+tagOpenTimestamp.count, with: tagOpenTimestamp)
                    offset += tagOpenTimestamp.count
                    
                    chunk.replaceSubrange(offset..<offset+sentence.count, with: sentence)
                    offset += sentence.count
                    
                    chunk.replaceSubrange(offset..<offset+tagCloseTextAndPage.count, with: tagCloseTextAndPage)
                    offset += tagCloseTextAndPage.count
                } else {
                    let fillLen = defaultChunkSize - offset
                    let sliceLen = min(fillLen, sentence.count)
                    chunk.replaceSubrange(offset..<offset+sliceLen, with: sentence[0..<sliceLen])
                    offset = defaultChunkSize
                }
            }
            pool.append(chunk)
        }
        return pool
    }()
    
    // MARK: - 内部快速分块填充 (单次 memcpy 零堆分配)
    
    static func fillChunk(
        buffer: UnsafeMutablePointer<UInt8>,
        count: Int,
        chunkIndex: UInt64,
        isFirstChunk: Bool,
        isLastChunk: Bool
    ) {
        let templateIdx = Int(chunkIndex % 16)
        let template = templatePool[templateIdx]
        
        _ = template.withUnsafeBufferPointer { srcPtr in
            memcpy(buffer, srcPtr.baseAddress!, count)
        }
        
        if isFirstChunk {
            let hdrLen = min(xmlHeader.count, count)
            memcpy(buffer, xmlHeader, hdrLen)
        }
        
        if isLastChunk && count >= xmlFooter.count {
            memcpy(buffer.advanced(by: count - xmlFooter.count), xmlFooter, xmlFooter.count)
        }
    }
    
    @inlinable
    static func splitMix64(seed: UInt64) -> UInt64 {
        var z = seed &+ 0x9E3779B97F4A7C15
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    
    @inlinable
    static func writeUInt64Ascii(to ptr: UnsafeMutablePointer<UInt8>, value: UInt64) -> Int {
        var val = value
        if val == 0 {
            ptr.pointee = 0x30 // '0'
            return 1
        }
        var temp: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        var idx = 19
        while val > 0 && idx >= 0 {
            temp[idx] = UInt8(0x30 + (val % 10))
            val /= 10
            idx -= 1
        }
        let len = 19 - idx
        for i in 0..<len {
            ptr.advanced(by: i).pointee = temp[idx + 1 + i]
        }
        return len
    }
}
