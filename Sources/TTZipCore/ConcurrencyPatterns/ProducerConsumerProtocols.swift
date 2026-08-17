import Foundation

/// 归档数据块结构体 (用于生产者与消费者之间高效传递与处理 Data Chunk)
public struct ArchiveDataChunk: Sendable, Equatable, Identifiable {
    public var id: Int64 { chunkID }
    public let chunkID: Int64
    public let offset: Int64
    public let data: Data
    public let isEOF: Bool
    public let crc32: UInt32?
    public let metadata: [String: String]

    public init(
        chunkID: Int64,
        offset: Int64,
        data: Data,
        isEOF: Bool = false,
        crc32: UInt32? = nil,
        metadata: [String: String] = [:]
    ) {
        self.chunkID = chunkID
        self.offset = offset
        self.data = data
        self.isEOF = isEOF
        self.crc32 = crc32
        self.metadata = metadata
    }

    /// 产生代表流终结 (End-Of-File) 的 EOF Chunk
    public static func eof(chunkID: Int64 = -1) -> ArchiveDataChunk {
        return ArchiveDataChunk(
            chunkID: chunkID,
            offset: -1,
            data: Data(),
            isEOF: true
        )
    }
}

/// 异步生产者接口 (Async Producer Protocol)
public protocol AsyncProducerProtocol: Sendable {
    /// 生产下一个 ArchiveDataChunk 数据块 (若数据流结束返回 nil 或 isEOF 为 true 的 chunk)
    func produce() async throws -> ArchiveDataChunk?
}

/// 异步消费者接口 (Async Consumer Protocol)
public protocol AsyncConsumerProtocol: Sendable {
    /// 消费处理指定的 ArchiveDataChunk 数据块
    func consume(_ chunk: ArchiveDataChunk) async throws
}
